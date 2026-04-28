import codecs
import re

with codecs.open('lib/main.dart', 'r', 'utf-8') as f:
    content = f.read()

# Find the start of _SaisieSheetState class
class_start = content.find('class _SaisieSheetState')
if class_start == -1:
    print("Class not found")
    import sys; sys.exit(1)

# Find the build method inside that class
build_start = content.find('  Widget build(BuildContext context) {', class_start)
if build_start == -1:
    print("Build method not found")
    import sys; sys.exit(1)

# The end is the end of the file since it's the last class.
# We will just replace everything from build_start to the last closing brace.
end_idx = content.rfind('}')

with codecs.open('replace_ui.py', 'r', 'utf-8') as f:
    script_content = f.read()
    
# Extract the new_methods variable value from replace_ui.py
import ast
for node in ast.walk(ast.parse(script_content)):
    if isinstance(node, ast.Assign) and len(node.targets) == 1 and node.targets[0].id == 'new_methods':
        new_methods = node.value.value
        break

# Let's fix .withOpacity to .withValues(alpha: ...) in new_methods
new_methods = re.sub(r'\.withOpacity\((.*?)\)', r'.withValues(alpha: \1)', new_methods)

new_content = content[:build_start] + new_methods + '}\n'

with codecs.open('lib/main.dart', 'w', 'utf-8') as f:
    f.write(new_content)

print('Replacement successful')
