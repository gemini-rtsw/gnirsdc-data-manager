#!/bin/bash
set -e

echo "=== Building GitLab Pages locally ==="
echo "This script will mimic the GitLab CI pipeline for building pages"

# Create output directory
mkdir -p local-public diagrams

# First, extract the Mermaid diagram locally to avoid file path issues
echo "=== Extracting Mermaid content locally ==="
awk '/```mermaid/,/```/' README.md | sed '1d;$d' > diagrams/diagram.mmd || true
echo "Contents of extracted mermaid file:"
cat diagrams/diagram.mmd || echo "Failed to extract diagram"

# If extraction failed, create a fallback diagram
if [ ! -s diagrams/diagram.mmd ]; then
  echo "Creating fallback diagram..."
  cat > diagrams/diagram.mmd << EOF
  graph TD
    TCS[TCS IOC] -->|EPICS data| A[Python EPICS IOC]
    AG[AG IOC] -->|EPICS data| A
    A --> B[Send header data]
    B --> C[Pybind11 Library]
    C --> D[Write raw data with header and readout]
    D --> A
    A --> E[Rebuild raw files into final FITS file]
EOF
fi

# Install required dependencies
echo "=== Installing dependencies ==="
apt-get update -y || { echo "Failed to update package list, continuing..."; }
apt-get install -y python3 python3-pip nodejs npm chromium inkscape || { echo "Failed to install some dependencies, continuing..."; }
pip3 install markdown markdown-toc pymdown-extensions || { echo "Failed to install Python dependencies, continuing..."; }

echo "=== Installing Mermaid CLI ==="
npm install -g @mermaid-js/mermaid-cli || { echo "Failed to install Mermaid CLI, continuing..."; }

# Create a Mermaid HTML file
echo "=== Creating a simple HTML file with the Mermaid diagram ==="
cat > diagrams/diagram.html << EOF
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Mermaid Diagram</title>
  <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
  <script>
    mermaid.initialize({ startOnLoad: true });
  </script>
</head>
<body>
  <div class="mermaid">
EOF

cat diagrams/diagram.mmd >> diagrams/diagram.html
cat >> diagrams/diagram.html << EOF
  </div>
</body>
</html>
EOF

# Try different approaches to generate the diagram
echo "=== Attempting to generate the SVG diagram ==="

# Method 1: Use Mermaid CLI if available
if command -v mmdc &> /dev/null; then
  echo "Trying Mermaid CLI..."
  mmdc -i diagrams/diagram.mmd -o diagrams/diagram.svg -b transparent || echo "Mermaid CLI failed, trying alternative method..."
fi

# Method 2: Use Chrome/Chromium if available
if [ ! -f diagrams/diagram.svg ] && (command -v chromium &> /dev/null || command -v google-chrome &> /dev/null || command -v chromium-browser &> /dev/null); then
  echo "Trying Chromium/Chrome rendering..."
  CHROME_BIN=$(command -v chromium || command -v google-chrome || command -v chromium-browser)
  
  # Try to generate a PDF first
  $CHROME_BIN --headless --disable-gpu --no-sandbox --disable-dev-shm-usage \
    --print-to-pdf=diagrams/diagram.pdf diagrams/diagram.html || echo "Chrome PDF rendering failed"
  
  # If we have the PDF and Inkscape, convert to SVG
  if [ -f diagrams/diagram.pdf ] && command -v inkscape &> /dev/null; then
    echo "Converting PDF to SVG using Inkscape..."
    inkscape --export-filename=diagrams/diagram.svg diagrams/diagram.pdf || echo "Inkscape conversion failed"
  fi
fi

# Method 3: Create a simple SVG manually if all else fails
if [ ! -f diagrams/diagram.svg ]; then
  echo "=== Creating placeholder SVG ==="
  cat > diagrams/diagram.svg << EOF
<svg xmlns="http://www.w3.org/2000/svg" width="600" height="300">
  <rect width="600" height="300" style="fill:rgb(240,240,240);stroke-width:1;stroke:rgb(0,0,0)" />
  <text x="50" y="50" fill="black" font-family="Arial" font-size="16">Diagram could not be generated</text>
  <text x="50" y="80" fill="black" font-family="Arial" font-size="14">Please refer to the mermaid code in the README.md file.</text>
  <text x="50" y="120" fill="blue" font-family="monospace" font-size="12" style="white-space: pre;">$(cat diagrams/diagram.mmd | sed 's/</\&lt;/g' | sed 's/>/\&gt;/g')</text>
</svg>
EOF
fi

# Create processed markdown with the diagram reference
echo "=== Creating processed markdown ==="
# Use different sed syntax for macOS vs Linux
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS uses BSD sed
  sed -e '/```mermaid/,/```/d' README.md | sed -e '/# Changing TCS Process Variable/i\
![Mermaid Diagram](diagram.svg)' > README.processed.md
else
  # Linux uses GNU sed
  sed '/```mermaid/,/```/c\![Mermaid Diagram](diagram.svg)' README.md > README.processed.md
fi

# Generate TOC and content directly
echo "=== Generating TOC manually ==="
python3 -c "
import re
import markdown
from markdown.extensions.codehilite import CodeHiliteExtension
from markdown.extensions.fenced_code import FencedCodeExtension

def extract_headings(markdown_content):
    # Regular expression to match markdown headings
    heading_pattern = re.compile(r'^(#{1,6})\s+(.*?)(?:\s*#+)?$', re.MULTILINE)
    headings = []
    
    for match in heading_pattern.finditer(markdown_content):
        level = len(match.group(1))
        text = match.group(2).strip()
        # Create an ID from the heading text (simplified version)
        heading_id = text.lower().replace(' ', '-').replace(':', '').replace('.', '').replace('(', '').replace(')', '')
        # Remove any non-alphanumeric characters except dashes
        heading_id = re.sub(r'[^a-z0-9-]', '', heading_id)
        # Remove consecutive dashes
        heading_id = re.sub(r'-+', '-', heading_id)
        
        headings.append({
            'level': level,
            'text': text,
            'id': heading_id
        })
    
    return headings

def generate_toc_html(headings):
    if not headings:
        return '<div class=\"toc\"><ul><li>No headings found in document</li></ul></div>'
    
    toc_html = ['<div class=\"toc\"><ul>']
    current_level = 1
    
    for heading in headings:
        # Skip the first heading (title)
        if heading == headings[0] and heading['level'] == 1:
            continue
            
        while current_level < heading['level']:
            toc_html.append('<ul>')
            current_level += 1
        
        while current_level > heading['level']:
            toc_html.append('</ul>')
            current_level -= 1
        
        toc_html.append(f'<li><a href=\"#{heading[\"id\"]}\">{heading[\"text\"]}</a></li>')
    
    # Close any open lists
    while current_level > 1:
        toc_html.append('</ul>')
        current_level -= 1
    
    toc_html.append('</ul></div>')
    return ''.join(toc_html)

def add_heading_ids(html_content, headings):
    # Add IDs to all headings in the HTML
    for heading in headings:
        pattern = f'<h{heading[\"level\"]}>{re.escape(heading[\"text\"])}</h{heading[\"level\"]}>'
        replacement = f'<h{heading[\"level\"]} id=\"{heading[\"id\"]}\">{heading[\"text\"]}</h{heading[\"level\"]}>'
        html_content = re.sub(pattern, replacement, html_content)
    
    return html_content

# Read the processed README
with open('README.processed.md', 'r') as f:
    content = f.read()

# Extract headings from the markdown content
headings = extract_headings(content)

# Generate the TOC HTML
toc_html = generate_toc_html(headings)

# Convert markdown to HTML with code highlighting
html_content = markdown.markdown(
    content,
    extensions=[
        CodeHiliteExtension(css_class='highlight'),
        FencedCodeExtension()
    ]
)

# Add IDs to headings in the HTML
html_content = add_heading_ids(html_content, headings)

# Save the TOC and content to files for later use
with open('toc.html', 'w') as f:
    f.write(toc_html)

with open('content.html', 'w') as f:
    f.write(html_content)

print(f'Generated TOC with {len(headings)} headings')
" || { 
  echo "TOC generation failed, creating fallback TOC"; 
  cat > toc.html << EOF
<div class="toc">
  <ul>
    <li><a href="#quick-start-guide">Quick Start Guide</a></li>
    <li><a href="#detector-controller-usage">Detector Controller Usage</a></li>
    <li><a href="#data-retrieval">Data Retrieval</a></li>
    <li><a href="#detector-controller-operation-scripts">Detector Controller Operation Scripts</a></li>
    <li><a href="#system-manager">System Manager</a></li>
    <li><a href="#updating-the-development-container">Updating the Development Container</a></li>
    <li><a href="#changing-tcs-process-variable-pv-in-the-tcs-context">Changing TCS Process Variable</a></li>
    <li><a href="#debug-setup">Debug Setup</a></li>
    <li><a href="#troubleshooting">Troubleshooting</a></li>
  </ul>
</div>
EOF
}

echo "=== Converting README to HTML ==="
# Use the content.html file already generated in the TOC step
# If it doesn't exist, create a basic one
if [ ! -f content.html ]; then
  echo "Content HTML not found, generating basic HTML"
  python3 -c "
import markdown
from markdown.extensions.codehilite import CodeHiliteExtension
from markdown.extensions.fenced_code import FencedCodeExtension

# Read the processed README
with open('README.processed.md', 'r') as f:
    content = f.read()

# Convert markdown to HTML with code highlighting
html_content = markdown.markdown(
    content,
    extensions=[
        CodeHiliteExtension(css_class='highlight'), 
        FencedCodeExtension()
    ]
)

# Save the content to a file for later use
with open('content.html', 'w') as f:
    f.write(html_content)
  " || { echo "HTML conversion failed, creating empty content"; echo 'Content conversion failed. Please check your markdown file.' > content.html; }
fi

# Read the TOC and content HTML
TOC_HTML=$(cat toc.html)
CONTENT_HTML=$(cat content.html)

# Create the final HTML with ReadTheDocs-like styling
cat > local-public/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Detector Controller Software</title>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css?family=Lato:400,700|Roboto+Mono:400,700">
  <style>
    :root {
      --sidebar-width: 300px;
      --page-padding: 1.5rem;
      --content-max-width: 800px;
      --color-toc-background: #f5f5f5;
      --color-background-primary: #ffffff;
      --color-background-secondary: #f8f9fb;
      --color-foreground-primary: #333333;
      --color-foreground-secondary: #484848;
      --color-foreground-muted: #666666;
      --color-link: #2980B9;
      --color-link-hover: #3091d1;
      --color-code-background: #f8f8f8;
      --color-code-foreground: #333333;
      --color-highlight: #2980B9;
      --color-headerlink: #c9c9c9;
      --color-headerlink-hover: #2980B9;
      --color-border: #e1e4e5;
    }
    
    * {
      box-sizing: border-box;
    }
    
    body {
      font-family: "Lato", "proxima-nova", "Helvetica Neue", Arial, sans-serif;
      font-weight: normal;
      color: var(--color-foreground-primary);
      margin: 0;
      padding: 0;
      background-color: var(--color-background-primary);
      line-height: 1.6;
    }
    
    a {
      color: var(--color-link);
      text-decoration: none;
    }
    
    a:hover {
      color: var(--color-link-hover);
      text-decoration: underline;
    }
    
    h1, h2, h3, h4, h5, h6 {
      font-family: "Lato", "proxima-nova", "Helvetica Neue", Arial, sans-serif;
      font-weight: 700;
      margin-top: 1.5rem;
      margin-bottom: 1rem;
      color: var(--color-foreground-primary);
    }
    
    h1 {
      font-size: 2.5rem;
      margin-top: 0;
      padding-bottom: 0.5rem;
      border-bottom: 1px solid var(--color-border);
    }
    
    h2 {
      font-size: 1.8rem;
      padding-bottom: 0.3rem;
      border-bottom: 1px solid var(--color-border);
    }
    
    h3 {
      font-size: 1.4rem;
    }
    
    h4 {
      font-size: 1.2rem;
    }
    
    h5, h6 {
      font-size: 1rem;
    }
    
    code, pre {
      font-family: "Roboto Mono", "Courier New", Courier, monospace;
      font-size: 0.9rem;
    }
    
    code {
      background: var(--color-code-background);
      padding: 0.2rem 0.4rem;
      border-radius: 3px;
      color: var(--color-code-foreground);
    }
    
    pre {
      background: var(--color-code-background);
      padding: 1rem;
      overflow-x: auto;
      border-radius: 3px;
      border: 1px solid var(--color-border);
      line-height: 1.4;
    }
    
    pre code {
      background: transparent;
      padding: 0;
      border-radius: 0;
    }
    
    img {
      max-width: 100%;
      height: auto;
    }
    
    table {
      border-collapse: collapse;
      width: 100%;
      margin-bottom: 1rem;
    }
    
    table, th, td {
      border: 1px solid var(--color-border);
    }
    
    th, td {
      padding: 0.5rem;
      text-align: left;
    }
    
    th {
      background-color: var(--color-background-secondary);
    }
    
    .container {
      display: flex;
      min-height: 100vh;
    }
    
    .sidebar {
      width: var(--sidebar-width);
      background-color: var(--color-toc-background);
      padding: var(--page-padding);
      border-right: 1px solid var(--color-border);
      overflow-y: auto;
      position: fixed;
      height: 100vh;
    }
    
    .sidebar h3 {
      margin-top: 0;
      font-size: 1.2rem;
    }
    
    .sidebar .toc {
      font-size: 0.9rem;
    }
    
    .sidebar .toc ul {
      padding-left: 1rem;
      margin: 0;
      list-style-type: none;
    }
    
    .sidebar .toc li {
      margin-bottom: 0.5rem;
    }
    
    .sidebar .toc a {
      display: inline-block;
      color: var(--color-foreground-secondary);
      padding: 0.2rem 0;
    }
    
    .sidebar .toc a:hover {
      color: var(--color-link);
    }
    
    .content-wrapper {
      flex: 1;
      margin-left: var(--sidebar-width);
      padding: var(--page-padding);
      max-width: calc(var(--content-max-width) + 2 * var(--page-padding));
    }
    
    .content {
      max-width: var(--content-max-width);
      margin: 0 auto;
    }
    
    /* Responsive adjustments */
    @media (max-width: 768px) {
      :root {
        --sidebar-width: 250px;
      }
    }
    
    @media (max-width: 576px) {
      .container {
        flex-direction: column;
      }
      
      .sidebar {
        width: 100%;
        height: auto;
        position: relative;
        border-right: none;
        border-bottom: 1px solid var(--color-border);
      }
      
      .content-wrapper {
        margin-left: 0;
      }
    }
    
    /* Code highlighting */
    .highlight .hll { background-color: #ffffcc }
    .highlight .c { color: #999988; font-style: italic } /* Comment */
    .highlight .err { color: #a61717; background-color: #e3d2d2 } /* Error */
    .highlight .k { color: #000000; font-weight: bold } /* Keyword */
    .highlight .o { color: #000000; font-weight: bold } /* Operator */
    .highlight .cm { color: #999988; font-style: italic } /* Comment.Multiline */
    .highlight .cp { color: #999999; font-weight: bold; font-style: italic } /* Comment.Preproc */
    .highlight .c1 { color: #999988; font-style: italic } /* Comment.Single */
    .highlight .cs { color: #999999; font-weight: bold; font-style: italic } /* Comment.Special */
    .highlight .gd { color: #000000; background-color: #ffdddd } /* Generic.Deleted */
    .highlight .ge { color: #000000; font-style: italic } /* Generic.Emph */
    .highlight .gr { color: #aa0000 } /* Generic.Error */
    .highlight .gh { color: #999999 } /* Generic.Heading */
    .highlight .gi { color: #000000; background-color: #ddffdd } /* Generic.Inserted */
    .highlight .go { color: #888888 } /* Generic.Output */
    .highlight .gp { color: #555555 } /* Generic.Prompt */
    .highlight .gs { font-weight: bold } /* Generic.Strong */
    .highlight .gu { color: #aaaaaa } /* Generic.Subheading */
    .highlight .gt { color: #aa0000 } /* Generic.Traceback */
    .highlight .kc { color: #000000; font-weight: bold } /* Keyword.Constant */
    .highlight .kd { color: #000000; font-weight: bold } /* Keyword.Declaration */
    .highlight .kn { color: #000000; font-weight: bold } /* Keyword.Namespace */
    .highlight .kp { color: #000000; font-weight: bold } /* Keyword.Pseudo */
    .highlight .kr { color: #000000; font-weight: bold } /* Keyword.Reserved */
    .highlight .kt { color: #445588; font-weight: bold } /* Keyword.Type */
    .highlight .m { color: #009999 } /* Literal.Number */
    .highlight .s { color: #d01040 } /* Literal.String */
    .highlight .na { color: #008080 } /* Name.Attribute */
    .highlight .nb { color: #0086B3 } /* Name.Builtin */
    .highlight .nc { color: #445588; font-weight: bold } /* Name.Class */
    .highlight .no { color: #008080 } /* Name.Constant */
    .highlight .nd { color: #3c5d5d; font-weight: bold } /* Name.Decorator */
    .highlight .ni { color: #800080 } /* Name.Entity */
    .highlight .ne { color: #990000; font-weight: bold } /* Name.Exception */
    .highlight .nf { color: #990000; font-weight: bold } /* Name.Function */
    .highlight .nl { color: #990000; font-weight: bold } /* Name.Label */
    .highlight .nn { color: #555555 } /* Name.Namespace */
    .highlight .nt { color: #000080 } /* Name.Tag */
    .highlight .nv { color: #008080 } /* Name.Variable */
    .highlight .ow { color: #000000; font-weight: bold } /* Operator.Word */
    .highlight .w { color: #bbbbbb } /* Text.Whitespace */
    .highlight .mf { color: #009999 } /* Literal.Number.Float */
    .highlight .mh { color: #009999 } /* Literal.Number.Hex */
    .highlight .mi { color: #009999 } /* Literal.Number.Integer */
    .highlight .mo { color: #009999 } /* Literal.Number.Oct */
    .highlight .sb { color: #d01040 } /* Literal.String.Backtick */
    .highlight .sc { color: #d01040 } /* Literal.String.Char */
    .highlight .sd { color: #d01040 } /* Literal.String.Doc */
    .highlight .s2 { color: #d01040 } /* Literal.String.Double */
    .highlight .se { color: #d01040 } /* Literal.String.Escape */
    .highlight .sh { color: #d01040 } /* Literal.String.Heredoc */
    .highlight .si { color: #d01040 } /* Literal.String.Interpol */
    .highlight .sx { color: #d01040 } /* Literal.String.Other */
    .highlight .sr { color: #009926 } /* Literal.String.Regex */
    .highlight .s1 { color: #d01040 } /* Literal.String.Single */
    .highlight .ss { color: #990073 } /* Literal.String.Symbol */
    .highlight .bp { color: #999999 } /* Name.Builtin.Pseudo */
    .highlight .vc { color: #008080 } /* Name.Variable.Class */
    .highlight .vg { color: #008080 } /* Name.Variable.Global */
    .highlight .vi { color: #008080 } /* Name.Variable.Instance */
    .highlight .il { color: #009999 } /* Literal.Number.Integer.Long */
  </style>
</head>
<body>
  <div class="container">
    <div class="sidebar">
      <h3>Contents</h3>
      ${TOC_HTML}
    </div>
    <div class="content-wrapper">
      <div class="content">
        <h1>Detector Controller Software</h1>
        ${CONTENT_HTML}
      </div>
    </div>
  </div>
</body>
</html>
EOF

# Copy the SVG to the output directory
echo "=== Copying assets ==="
cp diagrams/diagram.svg local-public/

echo "=== Verifying outputs ==="
echo "Contents of local-public directory:"
ls -la local-public/

echo "=== Build complete ==="
echo "You can view the generated site by opening local-public/index.html in your browser"
echo "The mermaid diagram is available at local-public/diagram.svg" 

# Clean up temporary files
echo "=== Cleaning up temporary files ==="
rm -f README.processed.md
rm -f toc.html
rm -f content.html
rm -rf diagrams/

echo "=== Cleanup complete ===" 