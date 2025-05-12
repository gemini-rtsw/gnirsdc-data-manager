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

# Extract Mermaid diagram
echo "=== Extracting Mermaid diagram ==="
awk '/```mermaid/,/```/' README.md | sed '1d;$d' > temp/diagram.mmd

# Check if diagram extraction worked
if [ ! -s temp/diagram.mmd ]; then
  echo "ERROR: Failed to extract Mermaid diagram from README.md"
  exit 1
fi

echo "=== Generating SVG diagram ==="
# Use mmdc to convert Mermaid to SVG
mmdc -i temp/diagram.mmd -o $OUTPUT_DIR/diagram.svg -b transparent || {
  echo "ERROR: Failed to generate SVG from Mermaid diagram"
  exit 1
}

# Create processed markdown with diagram reference
echo "=== Processing README ==="
sed '/```mermaid/,/```/c\![Mermaid Diagram](diagram.svg)' README.md > temp/README.processed.md

# Generate HTML with TOC
echo "=== Converting to HTML ==="
python3 -c '
import re
import markdown
from markdown.extensions.codehilite import CodeHiliteExtension
from markdown.extensions.fenced_code import FencedCodeExtension

def extract_headings(markdown_content):
    heading_pattern = re.compile(r"^(#{1,6})\\s+(.*?)(?:\\s*#+)?$", re.MULTILINE)
    headings = []
    
    for match in heading_pattern.finditer(markdown_content):
        level = len(match.group(1))
        text = match.group(2).strip()
        heading_id = text.lower().replace(" ", "-").replace(":", "").replace(".", "")
        heading_id = re.sub(r"[^a-z0-9-]", "", heading_id)
        
        headings.append({
            "level": level,
            "text": text,
            "id": heading_id
        })
    
    return headings

def generate_toc_html(headings):
    toc_html = ["<div class=\"toc\"><ul>"]
    current_level = 1
    
    for heading in headings:
        # Skip the first heading (title)
        if heading == headings[0] and heading["level"] == 1:
            continue
            
        while current_level < heading["level"]:
            toc_html.append("<ul>")
            current_level += 1
        
        while current_level > heading["level"]:
            toc_html.append("</ul>")
            current_level -= 1
        
        toc_html.append(f"<li><a href=\"#{heading[\"id\"]}\">{heading[\"text\"]}</a></li>")
    
    # Close any open lists
    while current_level > 1:
        toc_html.append("</ul>")
        current_level -= 1
    
    toc_html.append("</ul></div>")
    return "".join(toc_html)

def add_heading_ids(html_content, headings):
    for heading in headings:
        pattern = f"<h{heading[\"level\"]}>{re.escape(heading[\"text\"])}</h{heading[\"level\"]}>"
        replacement = f"<h{heading[\"level\"]} id=\"{heading[\"id\"]}\">{heading[\"text\"]}</h{heading[\"level\"]}>"
        html_content = re.sub(pattern, replacement, html_content)
    
    return html_content

# Read the processed README
with open("temp/README.processed.md", "r") as f:
    content = f.read()

# Extract headings and generate TOC
headings = extract_headings(content)
toc_html = generate_toc_html(headings)

# Convert markdown to HTML
html_content = markdown.markdown(
    content,
    extensions=[
        CodeHiliteExtension(css_class="highlight"),
        FencedCodeExtension()
    ]
)

# Add IDs to headings
html_content = add_heading_ids(html_content, headings)

# Create HTML file
with open("temp/index.html", "w") as f:
    f.write("""<!DOCTYPE html>
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
      --color-foreground-primary: #333333;
      --color-link: #2980B9;
      --color-border: #e1e4e5;
      --color-code-background: #f8f8f8;
    }
    
    * { box-sizing: border-box; }
    
    body {
      font-family: "Lato", "proxima-nova", "Helvetica Neue", Arial, sans-serif;
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
      text-decoration: underline;
    }
    
    h1, h2, h3, h4, h5, h6 {
      font-weight: 700;
      margin-top: 1.5rem;
      margin-bottom: 1rem;
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
    
    h3 { font-size: 1.4rem; }
    h4 { font-size: 1.2rem; }
    h5, h6 { font-size: 1rem; }
    
    code, pre {
      font-family: "Roboto Mono", monospace;
      font-size: 0.9rem;
    }
    
    code {
      background: var(--color-code-background);
      padding: 0.2rem 0.4rem;
      border-radius: 3px;
    }
    
    pre {
      background: var(--color-code-background);
      padding: 1rem;
      overflow-x: auto;
      border-radius: 3px;
      border: 1px solid var(--color-border);
    }
    
    pre code {
      background: transparent;
      padding: 0;
      border-radius: 0;
    }
    
    img { max-width: 100%; height: auto; }
    
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
    
    @media (max-width: 768px) {
      :root { --sidebar-width: 250px; }
    }
    
    @media (max-width: 576px) {
      .container { flex-direction: column; }
      .sidebar {
        width: 100%;
        height: auto;
        position: relative;
        border-right: none;
        border-bottom: 1px solid var(--color-border);
      }
      .content-wrapper { margin-left: 0; }
    }
    
    /* Code highlighting */
    .highlight .hll { background-color: #ffffcc }
    .highlight .c { color: #999988; font-style: italic }
    .highlight .err { color: #a61717; background-color: #e3d2d2 }
    .highlight .k { color: #000000; font-weight: bold }
    .highlight .o { color: #000000; font-weight: bold }
    .highlight .cm { color: #999988; font-style: italic }
    .highlight .cp { color: #999999; font-weight: bold; font-style: italic }
    .highlight .c1 { color: #999988; font-style: italic }
    .highlight .cs { color: #999999; font-weight: bold; font-style: italic }
    .highlight .gd { color: #000000; background-color: #ffdddd }
    .highlight .ge { color: #000000; font-style: italic }
    .highlight .gr { color: #aa0000 }
    .highlight .gh { color: #999999 }
    .highlight .gi { color: #000000; background-color: #ddffdd }
    .highlight .s { color: #d01040 }
    .highlight .na { color: #008080 }
    .highlight .nb { color: #0086B3 }
    .highlight .nc { color: #445588; font-weight: bold }
    .highlight .no { color: #008080 }
    .highlight .nd { color: #3c5d5d; font-weight: bold }
    .highlight .nf { color: #990000; font-weight: bold }
  </style>
</head>
<body>
  <div class="container">
    <div class="sidebar">
      <h3>Contents</h3>
      """ + toc_html + """
    </div>
    <div class="content-wrapper">
      <div class="content">
        """ + html_content + """
      </div>
    </div>
  </div>
</body>
</html>""")

print("Successfully generated HTML with TOC")
' || {
  echo "ERROR: Failed to generate HTML"
  exit 1
}

# Copy generated files to output directory
cp temp/index.html $OUTPUT_DIR/

echo "=== Build complete ==="
echo "Generated files in $OUTPUT_DIR:"
ls -la $OUTPUT_DIR/

# Clean up
rm -rf temp

exit 0 