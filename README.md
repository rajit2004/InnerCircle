<p align="center">
  <span style="font-size: 60px;">🟣</span>
</p>

<h1 align="center">InnerCircle</h1>

<p align="center">
  <strong>Your AI-powered support network — Mom, Best Friend, Girlfriend, Big Sister, all in one app.</strong>
</p>

<p align="center">
  <a href="#-features">Features</a> •
  <a href="#-tech-stack">Tech Stack</a> •
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-api-documentation">API</a> •
  <a href="#-deployment">Deploy</a> •
  <a href="#-contributing">Contributing</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License" />
  <img src="https://img.shields.io/badge/made_with-Flutter-blue?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/backend-Node.js-339933?logo=node.js" alt="Node.js" />
  <img src="https://img.shields.io/badge/LLM-Groq-000000?logo=groq" alt="Groq" />
  <img src="https://img.shields.io/badge/database-Supabase-3ECF8E?logo=supabase" alt="Supabase" />
</p>

---

## 💡 What is InnerCircle?

**InnerCircle** is a multi-persona AI companion app that gives users a personal support system. Instead of one generic chatbot, you get **distinct AI personalities** — each with its own voice, communication style, and long-term memory.

| Persona | Vibe |
|---------|------|
| 👩 **Mom** | Nurturing, gentle, gives life advice |
| 🙌 **Best Friend** | Upbeat, hype, non-judgmental |
| 💕 **Girlfriend** | Romantic, affectionate, sends good morning texts |
| 💪 **Big Sister** | Protective, blunt, fun |

Built with **Flutter** (frontend), **Node.js + Express** (backend), **Supabase** (auth + DB + pgvector), and **Groq** (Llama 3 70B) for fast, free LLM responses.

---

## ✨ Features

- 🧠 **Persistent Memory** — Each persona remembers facts you tell them (e.g. *"I have an exam Friday"*)
- 💬 **Real-time Chat** — Streams AI replies token-by-token via SSE
- 🔔 **Proactive Notifications** — Personas send scheduled messages (good morning, check-ins)
- 📱 **Cross-platform** — iOS & Android with a single Flutter codebase
- 🔐 **Authentication** — Email/password + Google via Supabase Auth
- 💎 **Freemium Model** — Free tier: 2 personas + 50 messages/day. Premium: all personas, unlimited chat
- 🎛️ **Admin Dashboard** — Manage personas, view usage stats (React + Vite)
- 🧩 **Extensible** — Add new personas or customise prompts without touching core logic

---

## 🧠 How It Works

```
User signs up → Supabase Auth issues session
        ↓
User picks a persona → Persona system prompt + memory loaded
        ↓
User sends message → POST /api/chat
        ↓
Backend queries pgvector for relevant memories
        ↓
Groq (Llama 3 70B) streams response token-by-token (SSE)
        ↓
Key facts extracted → Stored as new memory
        ↓
Scheduled job checks notification table → FCM push fires at set time
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|------------|
| Mobile | Flutter + Riverpod + Dio |
| Backend | Node.js + Express + TypeScript |
| Database | Supabase (PostgreSQL + pgvector) |
| LLM | Groq Cloud — Llama 3 70B (free tier) |
| Auth | Supabase Auth (email/Google) |
| Admin Dashboard | React + Vite |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| Hosting | Render / Fly.io (backend) · Supabase (DB) |

---

## 📂 Project Structure

```
innercircle/
├── backend/
│   ├── admin/                          # React + Vite admin dashboard
│   ├── src/                            # Express + TypeScript API
│   ├── .env.example
│   └── package.json
├── mobile/
│   ├── lib/
│   │   └── services/
│   │       └── supabase_service.dart
│   └── pubspec.yaml
├── supabase/
│   └── migrations/
│       └── 001_initial_schema.sql
├── docs/
│   └── postman_collection.json
├── LICENSE
└── README.md
```

---

## 🚀 Quick Start

### Prerequisites
- Node.js ≥ 18
- Flutter ≥ 3.16
- Supabase account (free)
- Groq API key — free at [console.groq.com](https://console.groq.com)

### 1. Clone the repo

```bash
git clone https://github.com/your-username/innercircle.git
cd innercircle
```

### 2. Set up the backend

```bash
cd backend
cp .env.example .env   # fill in your keys
npm install
npm run dev
```

Backend runs at **http://localhost:3000**

### 3. Run the admin dashboard (optional)

```bash
cd backend/admin
npm install
npm run dev
```

Dashboard runs at **http://localhost:5173** — use the admin key from `.env`

### 4. Set up the Flutter app

```bash
cd mobile
flutter pub get
# Update Supabase URL & anon key in lib/services/supabase_service.dart
flutter run
```

> 📱 For Android emulators, use `10.0.2.2` for localhost in `api.dart`. For physical devices, use your machine's local IP.

### 5. Database migration

Copy the SQL from `supabase/migrations/001_initial_schema.sql` into the Supabase SQL Editor and run it.

---

## 📚 API Documentation

All endpoints are prefixed with `/api`.

### `POST /api/auth/register`
Register a new user.
```json
{ "email": "user@example.com", "password": "secret" }
```

### `POST /api/auth/login`
Login.
```json
{ "email": "user@example.com", "password": "secret" }
```

### `GET /api/personas`
List available personas *(auth required)*.

### `POST /api/chat`
Send a message — streams via SSE.
```json
{ "persona_id": "uuid", "content": "I'm stressed", "conversation_id": "optional" }
```
Returns `text/event-stream` with `data: { "token": "..." }` chunks.

### `GET /api/memories`
List user memories. Filter with `?persona_id=`.

### `POST /api/notifications/register`
Register a push token.
```json
{ "token": "fcm_token", "platform": "ios" }
```

### `POST /api/notifications/schedule`
Schedule proactive messages.
```json
{ "persona_id": "uuid", "scheduled_at": "08:00", "days_of_week": "1,2,3,4,5" }
```

> Full Postman collection available in `/docs`.

---

## 📦 Deployment

**Backend (Render / Fly.io)**
- Build: `npm run build` (compiles TypeScript)
- Start: `npm start`
- Set environment variables in your hosting dashboard

**Flutter App**
- Android: `flutter build apk` or `flutter build appbundle`
- iOS: `flutter build ios` → upload to TestFlight

**Supabase**
- Fully managed — just keep migrations up to date

---

## 🤝 Contributing

Contributions are welcome!

1. Fork the repo
2. Create a feature branch — `git checkout -b feature/amazing-idea`
3. Commit your changes — `git commit -m "Add amazing feature"`
4. Push — `git push origin feature/amazing-idea`
5. Open a Pull Request

Read the [Code of Conduct](CODE_OF_CONDUCT.md) and [Contributing Guide](CONTRIBUTING.md) for more details.

---

## 📄 License

This project is open-source under the [MIT License](LICENSE).

---

## 🙌 Acknowledgements

- [Groq](https://groq.com) — for the lightning-fast LLM API
- [Supabase](https://supabase.com) — for the all-in-one backend
- [Flutter](https://flutter.dev) — for beautiful cross-platform UIs

---

## 👨‍💻 Author

**Ranesh Rajit** — B.Tech CS Student, India

[![GitHub](https://img.shields.io/badge/GitHub-rajit2004-black?style=flat&logo=github)](https://github.com/rajit2004)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-ranesh--kun-blue?style=flat&logo=linkedin)](https://linkedin.com/in/ranesh-kun)

---