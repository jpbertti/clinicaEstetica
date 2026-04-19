import os
import re

def replace_with_values(root_dir):
    pattern = re.compile(r'\.withValues\(alpha:\s*([0-9.]+)\)')
    
    for root, dirs, files in os.walk(root_dir):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                new_content = pattern.sub(r'.withOpacity(\1)', content)
                
                if content != new_content:
                    print(f"Updating {file_path}")
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(new_content)

if __name__ == "__main__":
    replace_with_values('lib')
