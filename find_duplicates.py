import re
from collections import Counter

content = open(r'c:\Users\chris\Documents\_dev_perso\alcohol_tracker\lib\main.dart', encoding='utf-8').read()
matches = re.findall(r'void\s+(_\w+)\s*\(', content)
counts = Counter(matches)

for method, count in counts.items():
    if count > 1:
        print(f"Duplicate method: {method} ({count} times)")

refs = re.findall(r'(_notificationsPlugin|notificationsPlugin)', content)
if refs:
    print(f"Found references to notificationsPlugin: {len(refs)} times")
else:
    print("No references to notificationsPlugin found in main.dart")
