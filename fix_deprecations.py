import re
import os
from pathlib import Path

def fix_with_opacity(file_path):
    """Replace .withOpacity(...) with .withValues(alpha: ...)"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Pattern to match .withOpacity(decimal)
    pattern = r'\.withOpacity\(([0-9.]+)\)'
    replacement = r'.withValues(alpha: \1)'
    
    new_content = re.sub(pattern, replacement, content)
    
    if new_content != content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        return True
    return False

def fix_geolocator(file_path):
    """Fix deprecated Geolocator methods"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original = content
    
    # Replace getCurrentPosition with settings
    old_pattern = r'Geolocator\.getCurrentPosition\(\s*desiredAccuracy:\s*LocationAccuracy\.(\w+),\s*timeLimit:\s*const Duration\(seconds:\s*(\d+)\),?\s*\)'
    new_pattern = r'Geolocator.getCurrentPosition(locationSettings: LocationSettings(accuracy: LocationAccuracy.\1, timeLimit: const Duration(seconds: \2)))'
    content = re.sub(old_pattern, new_pattern, content, flags=re.MULTILINE)
    
    if content != original:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    return False

def process_directory(directory):
    """Process all Dart files in directory"""
    dart_files = Path(directory).rglob('*.dart')
    fixed_count = 0
    
    for dart_file in dart_files:
        if fix_with_opacity(str(dart_file)):
            fixed_count += 1
            print(f"Fixed: {dart_file.name}")
    
    # Fix Geolocator specifically in worker_dashboard.dart
    worker_dashboard = Path(directory) / 'lib' / 'screens' / 'worker_dashboard.dart'
    if worker_dashboard.exists():
        if fix_geolocator(str(worker_dashboard)):
            print(f"Fixed Geolocator in: {worker_dashboard.name}")
    
    print(f"\nTotal files updated: {fixed_count}")

if __name__ == '__main__':
    frontend_dir = r'e:\Arun_Finance\frontend'
    print(f"Scanning {frontend_dir} for deprecated code...")
    process_directory(frontend_dir)
    print("✅ Done!")
