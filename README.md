<!-- Hero Banner -->
<p align="center">
  <img src="assets/images/banner.png" alt="StyleTone AI Banner" width="100%">
</p>

<!-- Project Name & Badges -->
<h1 align="center">StyleTone AI</h1>
<p align="center">
  <strong>Your AI-Powered Personal Stylist. Effortless outfits, custom-curated for your natural skin tones, with a virtual closet and real-time color matcher.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-v3.0+-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter Badge">
  <img src="https://img.shields.io/badge/FastAPI-v0.100+-009688?style=for-the-badge&logo=fastapi&logoColor=white" alt="FastAPI Badge">
  <img src="https://img.shields.io/badge/Python-v3.10+-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python Badge">
  <img src="https://img.shields.io/badge/OpenCV-v4.10.84-5C3EE8?style=for-the-badge&logo=opencv&logoColor=white" alt="OpenCV Badge">
  <img src="https://img.shields.io/badge/SQLite-v3.0+-003B57?style=for-the-badge&logo=sqlite&logoColor=white" alt="SQLite Badge">
  <img src="https://img.shields.io/badge/License-MIT-F39C12?style=for-the-badge" alt="License Badge">
  <img src="https://img.shields.io/badge/Google%20ML%20Kit-Face-FF6F00?style=for-the-badge&logo=google&logoColor=white" alt="ML Kit Badge">
</p>

---

## 📥 Download & Install

Download the compiled app package directly to your Android device from the platforms below:

<p align="center">
  <a href="https://github.com/Ganesh1110/StyleTone-AI/releases">
    <img src="https://img.shields.io/badge/Github%20Releases-black?style=for-the-badge&logo=github&logoColor=white" alt="GitHub Releases">
  </a>
</p>

---

## 🌟 Key Features

StyleTone AI is a private, offline-first personal styling companion. It uses computer vision, on-device AI face verification, professional color theory, and local SQLite data persistence to guide your style journey.

### 🎨 1. Personal Stylist Scanner (v1.0.0 / v1.5.0)

- 🧠 **CIELAB Delta E Seasonal Classification**: Computes color distances between skin tones and 4 seasonal color families (Spring, Summer, Autumn, Winter) with precise match confidence metrics.
- 🧼 **HSV/YCrCb Skin Segmentation**: Isolates pure skin pixels on the backend—filtering out hair, eyebrows, lips, eyes, and background for a 100% precise color match.
- 📸 **On-Device Face Cropping**: Google ML Kit detects the face bounding box on-device; the face region is cropped before sending to the backend, ensuring reliable skin analysis regardless of server-side face detection availability.
- 🎨 **Skin-Tone Adaptive Palettes**: Palette colors are adjusted in HSV space based on the detected skin lightness (L*). Darker skin gets more vibrant shades; lighter skin gets softer, muted tones—even within the same seasonal category.
- 🎙️ **Offline Phonemic Text-to-Speech**: An offline speech synthesizer (`flutter_tts`) reads stylist tips aloud using local device voices, protecting your privacy.

### 👔 2. Premium Experience & Social Sharing (v2.0.0)

- ⚡ **One-Scan Multi-Occasion Dashboard**: Scans once and returns customized palettes for three occasions (**Office**, **Party**, and **Casual**) simultaneously.
- 📊 **Interactive Color Swatches Sheets**: Tap any swatch circle to slide up a bottom sheet detailing HEX values, RGB coordinates, and tailored garment pairing rules.
- 📤 **Native Screenshot Card Sharing**: Captures styling reports using a `RepaintBoundary` and launches native share sheets to share your palettes on WhatsApp, Instagram, or email.

### 👚 3. My Virtual Closet & Outfit Combinator (v2.5.0)

- 📁 **Local Virtual Closet**: Take photos of clothes in your wardrobe and save them categorized as **Tops**, **Bottoms**, **Outerwear**, **Shoes**, or **Accessories**.
- 🤖 **AI Clothing Color Extractor**: Uses K-Means color clustering to analyze uploaded garment fabrics and automatically tags them with color names (e.g. _Tomato Red_, _Olive Green_).
- 🧩 **Smart Outfit Combinator**: Measures RGB Euclidean color distance between your closet items and your active seasonal palette to suggest complete outfits from your own clothes with matching scores (e.g., _94% Match_).

### 🔍 4. Live Viewfinder Color Matcher (v3.0.0)

- 🎥 **On-Device Real-Time Analyzer**: Point your camera at any physical garment in a store. The app converts camera stream frames (YUV420 on Android, BGRA on iOS) locally in Dart at 30 FPS.
- 🎯 **Target Reticle Overlay**: Renders a circular targeting reticle in the middle of the camera feed to lock onto fabric colors.
- 🔥 **Instant Match Score**: Compares the live target color against your personal season colors to display a real-time match gauge (e.g., _Avoid Color_ vs. _Perfect Match!_).

### 🗂️ 5. Analysis History Management (v3.5.0)

- 📜 **Full History Log**: Every scan is saved locally with the photo, season result, and occasion.
- 🗑️ **Swipe-to-Delete / Individual Delete**: Remove single history entries with a swipe gesture or the delete icon on each card.
- 🧹 **Clear All**: Bulk-delete all history with a confirmation dialog.

---

## 📐 Scientific Color Analysis Engine

The FastAPI backend uses a **CIELAB Delta E ($\Delta E$) color difference classifier** to identify your seasonal skin category:

1. **BGR to LAB Conversion**:
   BGR coordinates are mapped to the $L^*a^*b^*$ color space. Unlike RGB, CIELAB is designed to represent human perception, where equal distance represents equal perceptual difference.
2. **Delta E Calculation**:
   The distance between the detected skin color and predefined seasonal anchor centers (representing Spring, Summer, Autumn, and Winter skin profiles) is calculated using the Euclidean distance:

   $$\Delta E^* = \sqrt{(\Delta L^*)^2 + (\Delta a^*)^2 + (\Delta b^*)^2}$$

3. **Similarity Softmax**:
   Distance scores are normalized using an exponential decay function to compute a precise **Match Confidence Percentage**.
4. **Skin-Tone Adaptive HSV Adjustment**:
   Once the season is determined, each palette color is converted to HSV and adjusted based on the skin's $L^*$ lightness value. Darker skin tones receive more saturated, brighter shades; lighter skin tones receive softer, muted shades—producing unique hex codes for each user even within the same season.
5. **Explainable AI Output**:
   The system details your undertones (e.g., warm golden/peach, cool rosy/pink) and lightness depth (e.g., fair, medium, rich) to justify the seasonal classification.

---

## 🏗️ System Architecture

```mermaid
flowchart TD
    %% Client App
    subgraph Client [Flutter Mobile Client]
        A[Home Dashboard] -->|Viewfinder / Gallery| B[On-Device Face Detection & Quality Check]
        B -- ML Kit Bounding Box --> B2[Face Crop + 30% Padding]
        B2 -- Cropped Face Image --> C[FastAPI /recommend Endpoint]
        C -->|JSON Palettes| D[Result Page TabBar]

        %% Closet Subsystem
        A -->|Add Clothing| E[My Closet Grid]
        E -->|Upload Photo| F[FastAPI /analyze-clothing]
        F -->|Color & Name| G[SQLite Database closet Table]

        %% Matcher Subsystems
        G -->|Garment List| H[Outfit Combinator Matching]
        D -->|Save Scan| I[SQLite Database history Table]
        I -->|Latest Profile Season| H
        I -->|Active Season Target| J[Live Viewfinder Color Matcher]

        %% History Management
        I -->|Clear / Delete| K[History Management UI]

        %% Stream Loop
        L[Live Camera Stream] -->|Local YUV420/BGRA Frame Conversion| J
    end

    %% Backend Server
    subgraph Backend [FastAPI Stateless Backend]
        C --> M[HSV/YCrCb Skin Segmentation Mask]
        M --> N[K-Means Undertone Clustering]
        N --> O[CIELAB Delta E Classifier]
        O --> P[Skin-Tone Adaptive HSV Adjustment]
        P -->|Office, Party, Casual Palettes| C

        F --> Q[Fabric Dominant Color K-Means]
        Q --> R[RGB Euclidean Color Classification]
        R -->|Color Metadata| F
    end
```

---

## 📂 Project Structure

```text
StyleTone-AI/
├── assets/                       # App media assets
│   └── images/                   # App logo and repository banner
├── backend_api/                  # FastAPI Python Backend
│   ├── api/                      # Server routing entry point (index.py)
│   ├── color_matrix.json         # Seasonal palettes configurations
│   ├── haarcascade_frontalface_default.xml  # Local Haar cascade for face detection fallback
│   ├── image_processor.py        # Skin segmentation, Delta E classifier, skin-tone adaptive palettes
│   ├── requirements.txt          # Python dependencies (opencv, scikit-learn, fastapi, etc.)
│   └── start.sh                  # Local backend startup script
├── lib/                          # Flutter Application Source
│   ├── models/                   # Data parsing objects (HistoryItem, ClosetItem, ColorRecommendation)
│   ├── screens/                  # UI screens (Home, Preview, Closet, Outfit Combinator, Live Matcher, Result, History)
│   ├── services/                 # Services (ApiService, DatabaseHelper, TtsService, ProfileService, HistoryService)
│   ├── theme/                    # App theme configuration
│   └── widgets/                  # Reusable widgets (GlassCard, SkeletonLoader)
├── bump_version.py               # Automated version bumper script
├── build_apk.sh                  # Automated release APK builder script
├── RELEASE_GUIDE.md              # Version release checklist and instructions
└── pubspec.yaml                  # Flutter project configuration & assets declaration
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.0.0+)
- [Python](https://www.python.org/downloads/) (v3.10+)

### 1. Set Up the Backend Server

```bash
# Navigate to the backend directory
cd backend_api

# Run the startup script (creates venv, installs requirements.txt, and starts uvicorn)
chmod +x start.sh
./start.sh
```

The server will start running locally at `http://localhost:8000`.

### 2. Set Up the Flutter App

To run on an **Android Emulator** or **iOS Simulator**:

1. Ensure the backend URL in `lib/services/api_service.dart` points to your target server:
   - For Android Emulator: Use `http://10.0.2.2:8000`
   - For iOS Simulator: Use `http://localhost:8000`
   - For Production: Use `https://style-tone-ai.vercel.app`
2. Enable Google ML Kit face detection:
   - **Android**: Set `minSdkVersion` to 21+ in `android/app/build.gradle` (ML Kit requirement)
   - **iOS**: Add `NSCameraUsageDescription` to `ios/Runner/Info.plist`
3. Run the application:

   ```bash
   # Get dependencies
   flutter pub get

   # Run on your active device/emulator
   flutter run
   ```

---

## 🛠️ Developer Scripts

Refer to [RELEASE_GUIDE.md](file:///Users/ganeshjayaprakash/WorkSpace/Mine/StyleTone-AI/RELEASE_GUIDE.md) for full instructions.

- **Bump Version Name/Code**:
  ```bash
  python bump_version.py
  ```
- **Compile Release APK binaries (standard & split architecture)**:
  ```bash
  ./build_apk.sh
  ```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
