<p align="center">
  <span style="font-size: 75px;">🟣</span>
</p>

<h1 align="center">InnerCircle</h1>

<p align="center">
  <strong>Your AI-powered support network — Mom, Best Friend, Girlfriend, Big Sister, all in one app.</strong>
</p>

<p align="center">
  <a href="#-features"><img src="https://img.shields.io/badge/Features-6DB33F?style=flat-square&logo=spring&logoColor=white" alt="Features" /></a>
  <a href="#-how-it-works"><img src="https://img.shields.io/badge/How_It_Works-FF6F61?style=flat-square" alt="How It Works" /></a>
  <a href="#-tech-stack"><img src="https://img.shields.io/badge/Tech_Stack-4FC3F7?style=flat-square" alt="Tech Stack" /></a>
  <a href="#-project-structure"><img src="https://img.shields.io/badge/Structure-FFB74D?style=flat-square" alt="Structure" /></a>
  <a href="#-quick-start"><img src="https://img.shields.io/badge/Quick_Start-81C784?style=flat-square" alt="Quick Start" /></a>
  <a href="#-api-documentation"><img src="https://img.shields.io/badge/API-AB47BC?style=flat-square" alt="API" /></a>
  <a href="#-deployment"><img src="https://img.shields.io/badge/Deploy-4DD0E1?style=flat-square" alt="Deploy" /></a>
  <a href="#-contributing"><img src="https://img.shields.io/badge/Contributing-F06292?style=flat-square" alt="Contributing" /></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License" />
  <img src="https://img.shields.io/badge/made_with-Flutter-blue?logo=flutter&style=flat-square" alt="Flutter" />
  <img src="https://img.shields.io/badge/backend-Java_Spring_Boot-6DB33F?logo=spring&style=flat-square" alt="Spring Boot" />
  <img src="https://img.shields.io/badge/LLM-Groq-000000?logo=groq&style=flat-square" alt="Groq" />
  <img src="https://img.shields.io/badge/database-PostgreSQL-336791?logo=postgresql&style=flat-square" alt="PostgreSQL" />
</p>

---

## 💡 What is InnerCircle?

**InnerCircle** is a multi-persona AI companion platform designed to provide users with an emotional support network. Rather than interacting with a single generic chatbot, users engage with distinct AI personalities—each featuring its own tone, communication style, behavior patterns, and long-term memory.

### Available Personas

| Persona            | Personality                                                |
| ------------------ | ---------------------------------------------------------- |
| 👩 **Mom**         | Nurturing, gentle, and offers thoughtful life advice       |
| 🙌 **Best Friend** | Energetic, encouraging, and non-judgmental                 |
| 💕 **Girlfriend**  | Affectionate, romantic, and proactive with daily check-ins |
| 💪 **Big Sister**  | Protective, honest, and playful                            |

Built using **Flutter** for mobile, **Spring Boot** for backend services, **PostgreSQL + pgvector** for memory storage, and **Groq (Llama 3 70B)** for ultra-fast conversational AI.

---

## ✨ Features

* 🧠 **Persistent Memory**
  Each persona remembers important facts shared by the user.

* 💬 **Real-Time Chat Streaming**
  AI responses stream token-by-token using Server-Sent Events (SSE).

* 🔔 **Proactive Notifications**
  Personas can initiate conversations through scheduled messages and reminders.

* 📱 **Cross-Platform Mobile App**
  Single Flutter codebase supporting both Android and iOS.

* 🔐 **Secure Authentication**
  JWT-based authentication powered by Spring Security.

* 💎 **Freemium Subscription Model**

    * **Free Tier:** 2 personas + 50 messages/day
    * **Premium Tier:** Unlimited messaging + access to all personas

* 🎛️ **Admin Dashboard**
  Manage personas, moderate content, and monitor platform usage.

* 🧩 **Highly Extensible Architecture**
  Add or customize personas without modifying core business logic.

---

## 🧠 How It Works

```text
User signs up
        │
        ▼
Spring Security issues JWT
        │
        ▼
User selects a persona
        │
        ▼
Persona prompt + user memories are loaded
        │
        ▼
User sends message → POST /api/chat
        │
        ▼
Backend retrieves relevant memories using pgvector
        │
        ▼
Groq (Llama 3 70B) generates streamed response via SSE
        │
        ▼
Important facts are extracted and stored as memories
        │
        ▼
Scheduler checks notification queue
        │
        ▼
FCM push notifications are delivered
```

---

## 🛠️ Tech Stack

| Layer                        | Technology                                               |
| ---------------------------- | -------------------------------------------------------- |
| **Mobile**                   | Flutter, Riverpod, Dio                                   |
| **Backend**                  | Java 17, Spring Boot 3, Spring Security, Spring Data JPA |
| **Database**                 | PostgreSQL + pgvector                                    |
| **LLM Provider**             | Groq Cloud (Llama 3 70B)                                 |
| **Authentication**           | JWT                                                      |
| **Admin Dashboard**          | React + Vite                                             |
| **Push Notifications**       | Firebase Cloud Messaging (FCM)                           |
| **Hosting**                  | Render, Fly.io                                           |
| **Managed Database Options** | Supabase, AWS RDS                                        |

---

## 📂 Project Structure

```text
innercircle/
├── backend/
│   ├── src/main/java/com/innercircle/
│   │   ├── InnerCircleApplication.java
│   │   ├── config/           # Security, JWT, WebClient
│   │   ├── controller/       # REST APIs
│   │   ├── service/          # Business logic
│   │   ├── repository/       # Data access layer
│   │   ├── model/            # JPA entities
│   │   └── dto/              # Request/Response DTOs
│   │
│   ├── src/main/resources/
│   │   └── application.yml
│   └── pom.xml
│
├── admin/
│   ├── src/
│   └── package.json
│
├── mobile/
│   ├── lib/
│   └── pubspec.yaml
│
├── database/
│   └── schema.sql
│
├── LICENSE
└── README.md
```

---

# 🚀 Quick Start

## Prerequisites

* Java 17+
* Maven 3.8+
* Flutter 3.16+
* PostgreSQL 14+ with `pgvector`
* Groq API Key

Obtain a free API key from:

```text
https://console.groq.com
```

---

## 1. Clone the Repository

```bash
git clone https://github.com/your-username/innercircle.git
cd innercircle
```

---

## 2. Set Up PostgreSQL

Create a database:

```sql
CREATE DATABASE innercircle;
```

Enable the pgvector extension:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

Run the schema:

```bash
psql -d innercircle -f database/schema.sql
```

---

## 3. Configure the Backend

```bash
cd backend

cp src/main/resources/application.yml.example \
   src/main/resources/application.yml
```

Update the following values inside `application.yml`:

* Database URL
* Database username/password
* JWT secret
* Groq API key
* Firebase credentials (optional)

---

## 4. Run the Backend

```bash
./mvnw spring-boot:run
```

Backend server:

```text
http://localhost:8080
```

---

## 5. Run the Admin Dashboard (Optional)

```bash
cd admin

npm install
npm run dev
```

Dashboard URL:

```text
http://localhost:5173
```

Use the admin key configured in `application.yml`.

---

## 6. Run the Flutter App

```bash
cd mobile

flutter pub get

# Update API base URL in:
# lib/config/api.dart

flutter run
```

### Android Emulator Notes

Use:

```text
10.0.2.2
```

instead of `localhost`.

For physical devices, use your machine's local network IP.

---

# 📚 API Documentation

All endpoints are prefixed with:

```text
/api
```

---

## Authentication

### Register

```http
POST /api/auth/register
```

**Request Body**

```json
{
  "email": "user@example.com",
  "password": "secret"
}
```

---

### Login

```http
POST /api/auth/login
```

**Request Body**

```json
{
  "email": "user@example.com",
  "password": "secret"
}
```

**Response**

```json
{
  "token": "jwt_token"
}
```

---

## Personas

### List Personas

```http
GET /api/personas
```

> Authentication required.

---

## Chat

### Send Message

```http
POST /api/chat
```

**Request Body**

```json
{
  "persona_id": "uuid",
  "content": "I'm stressed",
  "conversation_id": "optional"
}
```

**Response Type**

```text
text/event-stream
```

Example stream chunk:

```json
{
  "token": "..."
}
```

---

## Memory

### Retrieve Memories

```http
GET /api/memories?persona_id={uuid}
```

Returns stored memories for a specific persona.

---

## Notifications

### Register Device Token

```http
POST /api/notifications/register
```

```json
{
  "token": "fcm_token",
  "platform": "ios"
}
```

---

### Schedule Proactive Messages

```http
POST /api/notifications/schedule
```

```json
{
  "persona_id": "uuid",
  "scheduled_at": "08:00",
  "days_of_week": "1,2,3,4,5"
}
```

A complete Postman collection is available under:

```text
/docs
```

---

# 📦 Deployment

## Backend

Build production artifact:

```bash
./mvnw package
```

Run the generated JAR:

```bash
java -jar target/*.jar
```

Configure production environment variables through:

* `application.yml`
* Docker secrets
* OS environment variables

---

## Flutter Application

### Android

```bash
flutter build apk
flutter build appbundle
```

### iOS

```bash
flutter build ios
```

Upload builds to TestFlight before App Store release.

---

## Database Hosting Options

* Supabase
* AWS RDS
* Self-hosted PostgreSQL
* Managed cloud PostgreSQL providers

---

# 🤝 Contributing

Contributions are welcome.

1. Fork the repository.
2. Create a feature branch.

```bash
git checkout -b feature/amazing-idea
```

3. Commit changes.

```bash
git commit -m "Add amazing feature"
```

4. Push branch.

```bash
git push origin feature/amazing-idea
```

5. Open a Pull Request.

Please review the project's Code of Conduct and Contributing Guidelines before contributing.

---

# 📄 License

Distributed under the **MIT License**.

---

# 🙌 Acknowledgements

* **Groq** — ultra-fast LLM inference
* **Spring Boot** — robust backend ecosystem
* **Flutter** — cross-platform mobile framework
* **Supabase** — PostgreSQL hosting and pgvector support

---

# 👨‍💻 Author

**Ranesh Rajit**
B.Tech Computer Science Student • India

![GitHub](https://img.shields.io/badge/GitHub-rajit2004-black?style=flat\&logo=github)

![LinkedIn](https://img.shields.io/badge/LinkedIn-ranesh--kun-blue?style=flat\&logo=linkedin)
