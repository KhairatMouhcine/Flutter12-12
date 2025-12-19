<div align="center">
  <h1>🚀 Smater App AI</h1>
  <p>A comprehensive Flutter application packed with cutting-edge Local AI features, Computer Vision, and real-time utilities.</p>

  <!-- Badges -->
  ![License](https://img.shields.io/badge/license-MIT-blue.svg)
  ![Version](https://img.shields.io/badge/version-1.0.0-green.svg)
  ![Language](https://img.shields.io/badge/language-Dart-0175C2.svg)
  ![Framework](https://img.shields.io/badge/framework-Flutter-02569B.svg)
</div>

---

## 📖 Table of Contents
- [About](#-about)
- [Features](#-features)
- [Tech Stack](#️-tech-stack)
- [Installation](#-installation)
- [Usage](#-usage)
- [Project Structure](#-project-structure)
- [Contributing](#-contributing)
- [License](#-license)
- [Author](#-author)

---

## 🎯 About
**Smater App AI** is a multi-purpose mobile application that bridges the gap between everyday utilities and Advanced Artificial Intelligence. It features local LLM interactions via Ollama, image classification using TensorFlow Lite, real-time weather tracking, and Firebase-backed authentication, all wrapped in a beautiful Flutter UI.

---

## ✨ Features
- 🔒 **Secure Authentication** — Full login and registration flows powered by Firebase Auth.
- 🤖 **Local LLM Chatbot** — Chat with an AI completely offline using Ollama integration.
- 🍎 **Fruit Classifier (Computer Vision)** — Real-time fruit classification using a custom MobileNet TFLite model.
- 🌦️ **Real-Time Weather** — Live meteorological data and weather tracking.
- 🎥 **Video Calls & Media** — Embedded media playback and video call features.
- 🧠 **RAG & Finetuning** — Advanced AI fine-tuning interface and Retrieval-Augmented Generation capabilities.
- 📊 **Analytics Dashboard** — Visual statistics and data representation.

---

## 🛠️ Tech Stack
| Technology | Purpose |
|------------|---------|
| **Flutter / Dart** | Cross-platform UI Framework & Language |
| **Firebase**      | Backend Authentication |
| **TensorFlow Lite** | On-device Machine Learning (Computer Vision) |
| **Ollama** | Local Large Language Models |
| **Speech-to-Text** | Voice Recognition |

---

## 📦 Installation
1. **Clone the repository:**
   ```bash
   git clone https://github.com/KhairatMouhcine/Flutter12-12.git
   cd Flutter12-12
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application:**
   Ensure you have an emulator running or a device connected.
   ```bash
   flutter run
   ```

---

## 🚀 Usage
- **Auth:** Start by registering a new account or logging in with Firebase.
- **AI Chat:** Navigate to the Chatbot screen to interact with the local Ollama model.
- **Classifier:** Open the Fruit Classifier, upload or snap a picture, and let the TFLite model predict the fruit.
- **Weather:** Check the `Meteo` tab for local weather updates.

---

## 📁 Project Structure
```text
Flutter12-12/
├── android/             # Android native code
├── ios/                 # iOS native code
├── assets/              # Static assets
│   ├── models/          # TFLite models (fruit_classifier.tflite)
│   ├── images/          # Image assets
│   └── videos/          # Video assets
├── lib/
│   ├── main.dart        # Application entry point
│   └── screens/         # UI Screens
│       ├── login_page.dart
│       ├── register_page.dart
│       ├── home_page.dart
│       ├── fruitClasifier_page.dart
│       ├── ollama_chat_screen.dart
│       ├── MeteoPage.dart
│       ├── CallVideo_page.dart
│       ├── Finetuning_page.dart
│       └── statique_page.dart
├── pubspec.yaml         # Dependencies and project metadata
└── README.md            # Project documentation
```

---

## 🤝 Contributing
Contributions are welcome! Please open an issue or submit a pull request.

---

## 📄 License
This project is licensed under the MIT License.

---

## 👨‍💻 Author

<div align="center">
  <img src="https://avatars.githubusercontent.com/KhairatMouhcine?v=4" width="100px" style="border-radius: 50%;" />
  <h3>KhairatMouhcine</h3>
  <p>
    <a href="https://github.com/KhairatMouhcine">
      <img src="https://img.shields.io/badge/GitHub-KhairatMouhcine-black?style=flat&logo=github" />
    </a>
    <a href="mailto:khairatmouhcine125@gmail.com">
      <img src="https://img.shields.io/badge/Email-khairatmouhcine125@gmail.com-red?style=flat&logo=gmail" />
    </a>
  </p>
</div>
