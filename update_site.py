import os
import re
import json
import requests

try:
    import yaml
except ImportError:
    print("Erreur : Le package 'pyyaml' est requis.")
    print("Executez : pip install pyyaml")
    exit(1)

# Configuration Supabase
SUPABASE_URL = "https://aswxkjibvcadnwujzwcm.supabase.co"
# Utilisation de la clé publique (anon) pour la lecture
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFzd3hramlidmNhZG53dWp6d2NtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyNTE3MjMsImV4cCI6MjA5MTgyNzcyM30.DunVTxcbIm0ausnk_4pdnkyn58tdoZf5ioLKqtk5tro"

def flatten_dict(d, parent_key='', sep='.'):
    items = []
    for k, v in d.items():
        new_key = f"{parent_key}{sep}{k}" if parent_key else k
        if isinstance(v, dict):
            items.extend(flatten_dict(v, new_key, sep=sep).items())
        else:
            items.append((new_key, v))
    return dict(items)

def unflatten_dict(d, sep='.'):
    result = {}
    for key, value in d.items():
        parts = key.split(sep)
        target = result
        for part in parts[:-1]:
            target = target.setdefault(part, {})
        target[parts[-1]] = value
    return result

def get_supabase_content():
    print("Recuperation des textes depuis Supabase...")
    try:
        headers = {
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}"
        }
        response = requests.get(f"{SUPABASE_URL}/rest/v1/site_content?select=*", headers=headers, timeout=10)
        if response.status_code == 200:
            data = response.json()
            print(f"OK : {len(data)} textes recuperes.")
            return {item['key']: item['value'] for item in data}
        else:
            print(f"Erreur Supabase ({response.status_code}) : {response.text}")
    except Exception as e:
        print(f"Erreur lors de la connexion a Supabase : {e}")
    return {}

def update_html():
    template_path = 'index.template.html'
    lang_path = 'assets/lang/site_fr.yaml'
    
    if not os.path.exists(lang_path):
        print(f"Erreur : Fichier de langue introuvable : {lang_path}")
        return

    if not os.path.exists(template_path):
        print(f"Erreur : Fichier template introuvable : {template_path}")
        return

    # 1. Charger le YAML local
    with open(lang_path, 'r', encoding='utf-8') as f:
        translations = yaml.safe_load(f) or {}
    
    flat_translations = flatten_dict(translations)
    
    # 2. Recuperer les mises a jour depuis Supabase
    db_translations = get_supabase_content()
    
    if db_translations:
        # Fusionner : la DB gagne sur le YAML local
        flat_translations.update(db_translations)
        
        # Mettre a jour le YAML local pour rester synchro
        new_translations = unflatten_dict(flat_translations)
        with open(lang_path, 'w', encoding='utf-8') as f:
            yaml.dump(new_translations, f, allow_unicode=True, sort_keys=False)
            print(f"YAML mis a jour avec les donnees de la base.")

    # 3. Appliquer au template HTML
    with open(template_path, 'r', encoding='utf-8') as f:
        html_content = f.read()

    update_count = 0
    # Utilisation d'un regex pour trouver tous les {{ key }} de manière flexible (espaces, retours à la ligne)
    def replace_placeholder(match):
        nonlocal update_count
        key = match.group(1).strip()
        if key in flat_translations:
            update_count += 1
            return str(flat_translations[key])
        return match.group(0) # On ne touche pas si la clé n'existe pas

    # Regex qui match {{ any_whitespace key any_whitespace }} y compris sur plusieurs lignes
    html_content = re.sub(r'\{\{\s*([\w.]+)\s*\}\}', replace_placeholder, html_content, flags=re.MULTILINE)

    with open('index.html', 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    print(f"\nTermine ! {update_count} substitutions effectuees dans index.html")

if __name__ == "__main__":
    update_html()
