import re

def count_tags(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    div_open = len(re.findall(r'<div\b', content))
    div_close = len(re.findall(r'</div>', content))
    a_open = len(re.findall(r'<a\b', content))
    a_close = len(re.findall(r'</a>', content))
    section_open = len(re.findall(r'<section\b', content))
    section_close = len(re.findall(r'</section>', content))
    header_open = len(re.findall(r'<header\b', content))
    header_close = len(re.findall(r'</header>', content))

    print(f"DIV: {div_open} open, {div_close} close")
    print(f"A: {a_open} open, {a_close} close")
    print(f"SECTION: {section_open} open, {section_close} close")
    print(f"HEADER: {header_open} open, {header_close} close")

if __name__ == "__main__":
    count_tags('index.html')
