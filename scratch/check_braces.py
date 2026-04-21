def check_braces(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    stack = []
    lines = content.split('\n')
    for i, line in enumerate(lines):
        for char in line:
            if char == '{':
                stack.append(i + 1)
            elif char == '}':
                if not stack:
                    print(f"Unmatched closing brace at line {i + 1}")
                else:
                    stack.pop()
    
    for line_num in stack:
        print(f"Unmatched opening brace at line {line_num}")

if __name__ == "__main__":
    check_braces('style.css')
