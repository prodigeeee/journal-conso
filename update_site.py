import os
import re

try:
    import yaml
except ImportError:
    print("Erreur : Le package 'pyyaml' est requis.")
    print("Executez : pip install pyyaml")
    exit(1)

def flatten_dict(d, parent_key='', sep='.'):
    items = []
    for k, v in d.items():
        new_key = f"{parent_key}{sep}{k}" if parent_key else k
        if isinstance(v, dict):
            items.extend(flatten_dict(v, new_key, sep=sep).items())
        else:
            items.append((new_key, v))
    return dict(items)

def update_html():
    template_path = 'index.html' # On utilise directement le fichier comme base si on veut rester simple
    lang_path = 'assets/lang/site_fr.yaml'
    
    if not os.path.exists(lang_path):
        print(f"Erreur : Fichier de langue introuvable : {lang_path}")
        return

    with open(lang_path, 'r', encoding='utf-8') as f:
        translations = yaml.safe_load(f)
    
    flat_translations = flatten_dict(translations)
    
    with open(template_path, 'r', encoding='utf-8') as f:
        html_content = f.read()

    update_count = 0
    for key, value in flat_translations.items():
        placeholder = f"{{{{ {key} }}}}"
        if placeholder in html_content:
            html_content = html_content.replace(placeholder, str(value))
            update_count += 1
            print(f"OK : {key}")

    with open('index.html', 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    print(f"\nTermine ! {update_count} textes mis a jour dans index.html")
    print("Note : Pensez a utiliser des placeholders comme {{ hero.title_start }} dans votre HTML d'origine.")

if __name__ == "__main__":
    update_html()
