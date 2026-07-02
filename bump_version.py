#!/usr/bin/env python3
# StyleTone AI - Automated Frontend Version Bumper
import os
import re

def bump_version():
    pubspec_path = "pubspec.yaml"
    if not os.path.exists(pubspec_path):
        print(f"Error: {pubspec_path} not found in the current directory.")
        return

    # Read pubspec.yaml
    with open(pubspec_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Search for line matching 'version: X.Y.Z+W'
    match = re.search(r"^version:\s*([0-9\.]+)\+([0-9]+)", content, re.MULTILINE)
    if not match:
        print("Error: Could not find version line in pubspec.yaml (format: version: X.Y.Z+W)")
        return

    version_name = match.group(1)
    version_code = int(match.group(2))
    
    parts = list(map(int, version_name.split('.')))
    if len(parts) != 3:
        print(f"Error: Version name '{version_name}' is not in X.Y.Z format.")
        return

    print("==============================================")
    print("🎯 StyleTone AI - Version Bumper (Frontend)")
    print(f"Current version: {version_name}+{version_code}")
    print("==============================================")
    print("Select upgrade type:")
    print("1) Build code only (e.g., 1.0.0+1 -> 1.0.0+2)")
    print("2) Patch bump      (e.g., 1.0.0+1 -> 1.0.1+2)")
    print("3) Minor bump      (e.g., 1.0.0+1 -> 1.1.0+2)")
    print("4) Major bump      (e.g., 1.0.0+1 -> 2.0.0+2)")
    print("==============================================")
    
    choice = input("Enter choice [1-4]: ").strip()
    
    major, minor, patch = parts
    new_code = version_code + 1
    
    if choice == "1":
        # Build number increment only
        pass
    elif choice == "2":
        # Increment patch
        patch += 1
    elif choice == "3":
        # Increment minor and reset patch
        minor += 1
        patch = 0
    elif choice == "4":
        # Increment major and reset minor/patch
        major += 1
        minor = 0
        patch = 0
    else:
        print("Invalid choice. Aborting.")
        return

    new_version_name = f"{major}.{minor}.{patch}"
    new_version_line = f"version: {new_version_name}+{new_code}"
    
    # Replace the old version line
    updated_content = re.sub(
        r"^version:\s*[0-9\.]+\+[0-9]+",
        new_version_line,
        content,
        flags=re.MULTILINE
    )

    with open(pubspec_path, "w", encoding="utf-8") as f:
        f.write(updated_content)

    print("")
    print(f"✅ Version successfully updated!")
    print(f"Old version: {version_name}+{version_code}")
    print(f"New version: {new_version_name}+{new_code}")
    print("==============================================")

if __name__ == "__main__":
    bump_version()
