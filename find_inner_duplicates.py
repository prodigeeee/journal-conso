import re

content = open(r'c:\Users\chris\Documents\_dev_perso\alcohol_tracker\lib\main.dart', encoding='utf-8').read()

# On découpe par classe
classes = re.split(r'\bclass\s+', content)
for cls_content in classes[1:]: # Ignorer le préambule
    name_match = re.match(r'(\w+)', cls_content)
    if not name_match: continue
    class_name = name_match.group(1)
    
    # Méthodes dans cette classe
    methods = re.findall(r'void\s+(_\w+)\s*\(', cls_content)
    from collections import Counter
    counts = Counter(methods)
    
    for method, count in counts.items():
        if count > 1:
            print(f"Duplicate method '{method}' in class '{class_name}' ({count} times)")
