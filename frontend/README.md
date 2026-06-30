# InnerCircle – Android Frontend

Multi-persona AI companion app built with Flutter. Connect with different AI personas (**Mom, Best Friend, Girlfriend, Big Sister**) — each with a unique personality, long-term memory, and real-time streaming responses.

---

## 🚀 Features

- 🔐 **JWT Authentication** – Login / Register with secure token storage
- 👥 **Multiple Personas** – Switch between AI personalities with distinct roles and tones
- 💬 **Real-time Streaming** – SSE-based chat with live responses from the AI
- 🧠 **Long-term Memory** – The app remembers user details, preferences, and past conversations
- 📋 **Memory Management** – View, search, and delete stored memories
- 📱 **Android-first** – Optimized for Android devices (emulator & physical devices)

---

## 🧩 Tech Stack

- **Flutter** – UI framework
- **Provider** – State management
- **SharedPreferences** – Local token storage
- **HTTP Client** – API calls with SSE streaming
- **Android** – Platform target

---

## 📦 Setup

### 1. Clone the Repository

```bash
git clone https://github.com/rajit2004/InnerCircle.git
cd InnerCircle/frontend
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Backend URL

Open `lib/services/api_client.dart` and update the `baseUrl`:

```dart
const String baseUrl = 'http://10.0.2.2:8080';   // Android emulator
// const String baseUrl = 'http://localhost:8080'; // Physical device / Web
// const String baseUrl = 'http://192.168.1.x:8080'; // Your local IP
```

### 4. Run the Application

```bash
flutter run
```

---

## 🔗 Backend

This frontend works with the **InnerCircle Spring Boot Backend**.

Ensure that the backend server is running before using the application.

**Backend Repository:** `InnerCircle Backend`

Default backend URL:

```text
http://localhost:8080
```

---

## 🧪 Test Credentials

Use the following credentials for testing:

```text
Email: ranesh.test@inner.circle
Password: testpass123
```

---

## 📁 Project Structure

```text
frontend/
├── lib/
│   ├── models/          # Data models (User, Persona, Memory, ChatMessage)
│   ├── services/        # API clients and business logic
│   ├── screens/         # UI screens (Login, Home, Chat, Memories, Register)
│   └── main.dart        # Application entry point and routing
├── android/             # Android platform configuration
├── test/                # Widget tests
├── pubspec.yaml         # Project dependencies
└── README.md            # Documentation
```

---

## 🛠️ Development Notes

### Streaming Chat

Uses **Server-Sent Events (SSE)** to display AI responses in real time.

### Memory

Memories are extracted from conversations and stored with vector embeddings powered by **pgvector**.

### Authentication

JWT tokens are stored locally using **SharedPreferences**.

---

# 👨‍💻 Author

**Ranesh Rajit**
B.Tech Computer Science Student • India

[![GitHub](https://img.shields.io/badge/GitHub-rajit2004-black?style=flat&logo=github)](https://github.com/rajit2004)

[![LinkedIn](https://img.shields.io/badge/LinkedIn-ranesh--kun-blue?style=flat&logo=linkedin)](https://linkedin.com/in/ranesh-kun)