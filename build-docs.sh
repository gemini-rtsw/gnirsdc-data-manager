#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

# Set output directory based on environment
if [ -n "$CI" ]; then
  OUTPUT_DIR="public"
else
  OUTPUT_DIR="public"  # Use the same dir for consistency
fi

echo "=== Building documentation ==="
mkdir -p $OUTPUT_DIR
mkdir -p temp

# Check if README.md exists
if [ ! -f README.md ]; then
  echo "ERROR: README.md not found"
  exit 1
fi

# Extract Mermaid diagrams
echo "=== Extracting Mermaid diagrams ==="

# Create a temporary directory for diagrams
mkdir -p temp/diagrams

# Create mermaid configuration file
cat > temp/mermaid-config.json << EOF
{
  "theme": "default",
  "flowchart": {
    "htmlLabels": true,
    "curve": "basis",
    "rankSpacing": 40,
    "nodeSpacing": 30,
    "useMaxWidth": true
  },
  "themeVariables": {
    "fontFamily": "Lato",
    "fontSize": "14px"
  }
}
EOF

# Extract each Mermaid diagram into separate files
echo "Extracting mermaid content from README.md"
awk '
  BEGIN { diagram_count = 0; in_diagram = 0; content = ""; }
  /```mermaid/ { in_diagram = 1; content = ""; next; }
  /```/ && in_diagram { 
    in_diagram = 0; 
    diagram_count++; 
    print content > "temp/diagrams/diagram" diagram_count ".mmd";
    next; 
  }
  in_diagram { content = content $0 "\n"; }
  END { print "Found " diagram_count " diagram(s)"; }
' README.md

# Check if extraction worked
diagram_count=$(ls temp/diagrams/*.mmd 2>/dev/null | wc -l)
if [ "$diagram_count" -eq 0 ]; then
  echo "ERROR: Could not extract any Mermaid diagrams from README.md"
  exit 1
fi

echo "Extracted $diagram_count diagram(s)"

echo "=== Generating SVG diagrams ==="
# Process each diagram file and generate SVG
mkdir -p $OUTPUT_DIR/diagrams
diagram_index=1
for diagram_file in temp/diagrams/*.mmd; do
  output_svg="$OUTPUT_DIR/diagrams/diagram${diagram_index}.svg"
  echo "Generating SVG for diagram $diagram_index"
  
  # Use mmdc command to generate SVG
  mmdc -i "$diagram_file" -o "$output_svg" -b transparent -c temp/mermaid-config.json || {
    echo "WARNING: Failed to generate SVG for diagram $diagram_index, using placeholder"
    # Create a simple SVG as a placeholder
    cat > "$output_svg" << EOF
<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100">
  <rect width="200" height="100" fill="none" stroke="black" />
  <text x="40" y="50" font-family="sans-serif">Diagram $diagram_index Placeholder</text>
</svg>
EOF
  }
  diagram_index=$((diagram_index + 1))
done

# Create processed markdown with diagram references
echo "=== Processing README ==="
# Make a copy of README and replace the Mermaid sections with image links
awk '
BEGIN { 
  in_mermaid = 0; 
  diagram_count = 0;
}
/```mermaid/ { 
  in_mermaid = 1; 
  diagram_count++; 
  print "![Mermaid Diagram " diagram_count "](diagrams/diagram" diagram_count ".svg)"; 
  next; 
}
/```/ && in_mermaid { 
  in_mermaid = 0; 
  next; 
}
!in_mermaid { print; }
' README.md > temp/README.processed.md

# Generate HTML with TOC - Use a simplified Python script
echo "=== Converting to HTML ==="
cat > temp/convert.py << 'EOF'
import re
import markdown
from markdown.extensions.codehilite import CodeHiliteExtension
from markdown.extensions.fenced_code import FencedCodeExtension

def extract_headings(markdown_content):
    heading_pattern = re.compile(r'^(#{1,6})\s+(.*?)(?:\s*#+)?$', re.MULTILINE)
    headings = []
    
    for match in heading_pattern.finditer(markdown_content):
        level = len(match.group(1))
        text = match.group(2).strip()
        heading_id = text.lower().replace(' ', '-').replace(':', '').replace('.', '')
        heading_id = re.sub(r'[^a-z0-9-]', '', heading_id)
        
        headings.append({
            'level': level,
            'text': text,
            'id': heading_id
        })
    
    return headings

def generate_toc_html(headings):
    if not headings:
        return '<div class="toc"><ul><li>No headings found</li></ul></div>'
        
    toc_html = ['<div class="toc"><ul>']
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
        
        toc_html.append('<li><a href="#{0}">{1}</a></li>'.format(heading['id'], heading['text']))
    
    # Close any open lists
    while current_level > 1:
        toc_html.append('</ul>')
        current_level -= 1
    
    toc_html.append('</ul></div>')
    return ''.join(toc_html)

def add_heading_ids(html_content, headings):
    for heading in headings:
        pattern = '<h{0}>{1}</h{0}>'.format(heading['level'], re.escape(heading['text']))
        replacement = '<h{0} id="{1}">{2}</h{0}>'.format(heading['level'], heading['id'], heading['text'])
        html_content = re.sub(pattern, replacement, html_content)
    
    return html_content

# Read the processed README
with open('temp/README.processed.md', 'r') as f:
    content = f.read()

# Extract headings and generate TOC
headings = extract_headings(content)
toc_html = generate_toc_html(headings)

# Convert markdown to HTML
html_content = markdown.markdown(
    content,
    extensions=[
        CodeHiliteExtension(css_class='highlight'),
        FencedCodeExtension()
    ]
)

# Add IDs to headings
html_content = add_heading_ids(html_content, headings)

# HTML Template - Escape CSS curly braces with double braces
html_template = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Detector Controller Software</title>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css?family=Lato:400,700|Roboto+Mono:400,700">
  <style>
    :root {{
      --sidebar-width: 300px;
      --page-padding: 1.5rem;
      --content-max-width: 800px;
      --color-toc-background: #f5f5f5;
      --color-background-primary: #ffffff;
      --color-foreground-primary: #333333;
      --color-link: #2980B9;
      --color-border: #e1e4e5;
      --color-code-background: #f8f8f8;
    }}
    
    * {{ box-sizing: border-box; }}
    
    body {{
      font-family: "Lato", "proxima-nova", "Helvetica Neue", Arial, sans-serif;
      color: var(--color-foreground-primary);
      margin: 0;
      padding: 0;
      background-color: var(--color-background-primary);
      line-height: 1.6;
    }}
    
    a {{
      color: var(--color-link);
      text-decoration: none;
    }}
    
    a:hover {{
      text-decoration: underline;
    }}
    
    h1, h2, h3, h4, h5, h6 {{
      font-weight: 700;
      margin-top: 1.5rem;
      margin-bottom: 1rem;
    }}
    
    h1 {{
      font-size: 2.5rem;
      margin-top: 0;
      padding-bottom: 0.5rem;
      border-bottom: 1px solid var(--color-border);
    }}
    
    h2 {{
      font-size: 1.8rem;
      padding-bottom: 0.3rem;
      border-bottom: 1px solid var(--color-border);
    }}
    
    h3 {{ font-size: 1.4rem; }}
    h4 {{ font-size: 1.2rem; }}
    h5, h6 {{ font-size: 1rem; }}
    
    code, pre {{
      font-family: "Roboto Mono", monospace;
      font-size: 0.9rem;
    }}
    
    code {{
      background: var(--color-code-background);
      padding: 0.2rem 0.4rem;
      border-radius: 3px;
    }}
    
    pre {{
      background: var(--color-code-background);
      padding: 1rem;
      overflow-x: auto;
      border-radius: 3px;
      border: 1px solid var(--color-border);
    }}
    
    pre code {{
      background: transparent;
      padding: 0;
      border-radius: 0;
    }}
    
    img {{ max-width: 100%; height: auto; }}
    
    /* Control diagram sizes */
    img.mermaid-diagram {{ 
      max-width: 800px;
      width: 100%;
      height: auto;
      display: block;
      margin: 2rem auto;
    }}
    
    .container {{
      display: flex;
      min-height: 100vh;
    }}
    
    .sidebar {{
      width: var(--sidebar-width);
      background-color: var(--color-toc-background);
      padding: var(--page-padding);
      border-right: 1px solid var(--color-border);
      overflow-y: auto;
      position: fixed;
      height: 100vh;
    }}
    
    .sidebar h3 {{
      margin-top: 0;
      font-size: 1.2rem;
    }}
    
    .sidebar .toc {{
      font-size: 0.9rem;
    }}
    
    .sidebar .toc ul {{
      padding-left: 1rem;
      margin: 0;
      list-style-type: none;
    }}
    
    .sidebar .toc li {{
      margin-bottom: 0.5rem;
    }}
    
    .content-wrapper {{
      flex: 1;
      margin-left: var(--sidebar-width);
      padding: var(--page-padding);
      max-width: calc(var(--content-max-width) + 2 * var(--page-padding));
    }}
    
    .content {{
      max-width: var(--content-max-width);
      margin: 0 auto;
    }}
    
    @media (max-width: 768px) {{
      :root {{ --sidebar-width: 250px; }}
    }}
    
    @media (max-width: 576px) {{
      .container {{ flex-direction: column; }}
      .sidebar {{
        width: 100%;
        height: auto;
        position: relative;
        border-right: none;
        border-bottom: 1px solid var(--color-border);
      }}
      .content-wrapper {{ margin-left: 0; }}
    }}
    
    /* Code highlighting */
    .highlight .hll {{ background-color: #ffffcc }}
    .highlight .c {{ color: #999988; font-style: italic }}
    .highlight .err {{ color: #a61717; background-color: #e3d2d2 }}
    .highlight .k {{ color: #000000; font-weight: bold }}
    .highlight .o {{ color: #000000; font-weight: bold }}
    .highlight .cm {{ color: #999988; font-style: italic }}
    .highlight .cp {{ color: #999999; font-weight: bold; font-style: italic }}
    .highlight .c1 {{ color: #999988; font-style: italic }}
    .highlight .cs {{ color: #999999; font-weight: bold; font-style: italic }}
    .highlight .gd {{ color: #000000; background-color: #ffdddd }}
    .highlight .ge {{ color: #000000; font-style: italic }}
    .highlight .gr {{ color: #aa0000 }}
    .highlight .gh {{ color: #999999 }}
    .highlight .gi {{ color: #000000; background-color: #ddffdd }}
    .highlight .s {{ color: #d01040 }}
    .highlight .na {{ color: #008080 }}
    .highlight .nb {{ color: #0086B3 }}
    .highlight .nc {{ color: #445588; font-weight: bold }}
    .highlight .no {{ color: #008080 }}
    .highlight .nd {{ color: #3c5d5d; font-weight: bold }}
    .highlight .nf {{ color: #990000; font-weight: bold }}
  </style>
</head>
<body>
  <div class="container">
    <div class="sidebar">
      <h3>Contents</h3>
      {0}
    </div>
    <div class="content-wrapper">
      <div class="content">
        {1}
      </div>
    </div>
  </div>
</body>
</html>"""

# Write the final HTML
with open('temp/index.html', 'w') as f:
    f.write(html_template.format(toc_html, html_content))

print("Successfully generated HTML with TOC")
EOF

# Run the Python script from file
python3 temp/convert.py || {
  echo "ERROR: Failed to generate HTML"
  exit 1
}

# Post-process the HTML to add class to diagram images
echo "=== Post-processing HTML ==="
sed -i 's|<img src="diagrams/diagram[0-9]\+.svg" alt="Mermaid Diagram [0-9]\+"|& class="mermaid-diagram"|g' temp/index.html

# Copy generated files to output directory
cp temp/index.html $OUTPUT_DIR/

echo "=== Build complete ==="
echo "Generated files in $OUTPUT_DIR:"
ls -la $OUTPUT_DIR/

# Clean up
rm -rf temp

exit 0 