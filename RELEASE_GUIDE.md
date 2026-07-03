# StyleTone AI - Version Release Checklist & Guide 🚀

Follow this checklist step-by-step whenever you complete a milestone version (e.g., v1.1.0, v1.5.0, v2.0.0) to compile, package, and publish the application assets.

---

## 📅 Version Release TODO Checklist

- [ ] **Step 1**: Bump version name and code in code configs.
- [ ] **Step 2**: Compile optimized release APK binaries.
- [ ] **Step 3**: Publish release tag and attach assets on GitHub.
- [ ] **Step 4**: Upload the primary installation APK to SourceForge.
- [ ] **Step 5**: Verify direct download URLs in README badges.

---

## 📖 Detailed Instructions

### 🏷️ Step 1: Bump the App Version
Run the automated version bump script from your terminal:
```bash
./bump_version.py
```
1. Select the bump type (e.g., **`2`** for Patch, **`3`** for Minor).
2. The script will automatically increment the version and build code in `pubspec.yaml` (e.g., `0.1.1+2` ➡️ `0.1.2+3`).
3. Commit and push the version update:
   ```bash
   git add pubspec.yaml
   git commit -m "bump: Prepare version vX.Y.Z"
   git push origin main
   ```

---

### 📦 Step 2: Compile Release APKs
Run the automated APK builder:
```bash
./build_apk.sh
```
1. Select Option **`3`** (Compile both standard and split-architecture APKs).
2. Wait for compilation to complete (approx. 1-2 minutes).
3. The built binaries will be placed in:
   📂 `build/app/outputs/flutter-apk/`

---

### 🐙 Step 3: Create GitHub Release
1. Navigate to: **[Create New Release](https://github.com/Ganesh1110/StyleTone-AI/releases/new)**
2. Set the tag version to match the bumped version (e.g., **`v0.1.2`**) and click **Create new tag**.
3. Set the release title (e.g., **`StyleTone AI v0.1.2`**).
4. Paste the Release Description template:
   ```markdown
   # StyleTone AI vX.Y.Z 🌟

   Describe key changes here (e.g., "Unified occasion tabs, interactive swatch detail sheets, and SQLite migration.")

   ### 📦 Release Assets
   * **`app-release.apk`** (~80MB) - Fat binary containing all CPU support.
   * **`app-arm64-v8a-release.apk`** (~30MB) - Optimized lightweight package for modern Android phones.
   * **`app-armeabi-v7a-release.apk`** (~26MB) - Optimized package for older Android devices.
   ```
5. Drag and drop the compiled APK files from `build/app/outputs/flutter-apk/` into the upload box.
6. Click **Publish release**.

---

### 🛜 Step 4: Upload to SourceForge
1. Log in and navigate to your project files browser:
   👉 **[SourceForge Files Manager](https://sourceforge.net/projects/styletone-ai/files/)**
2. Click **Add File** and upload the standard fat APK:
   📂 `build/app/outputs/flutter-apk/app-release.apk`
3. Once the upload hits 100%, click the **info icon (`i`)** next to the file name.
4. Under **Default Download For**, check the boxes for:
   * **Android**
   * **All Platforms**
5. Click **Save**. This updates your green download badge link instantly.

---

### 🔗 Step 5: Check README Download Link
* Ensure that the SourceForge download badge link in [README.md](file:///Users/ganeshjayaprakash/WorkSpace/Mine/StyleTone-AI/README.md) points to the correct download route:
  `https://sourceforge.net/projects/styletone-ai/files/app-release.apk/download`
* (If you uploaded the file with the same name, this URL will automatically fetch the latest uploaded version).
