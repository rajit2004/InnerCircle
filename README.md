<p align="center">
  <span style="font-size: 75px;">🟣</span>
</p>

<h1 align="center">InnerCircle</h1>

<p align="center">
  <strong>Your AI-powered support network. Mom, Best Friend, Girlfriend, Big Sister, all in one app.</strong>
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

## What is InnerCircle?

**InnerCircle** is a multi-persona AI companion platform designed to give users a genuine emotional support network. Instead of chatting with a single generic bot, users talk to distinct AI personalities. Each one has its own tone, communication style, behavior patterns, and long-term memory.

The app is built to feel alive. Every screen has thoughtful animations, haptic feedback, and visual polish that reinforces the feeling that someone is actually there with you. It is not a utility. It is a relationship app.

### Available Personas

| Persona            | Personality                                                |
| ------------------ | ---------------------------------------------------------- |
| **Mom**            | Nurturing, gentle, and offers thoughtful life advice       |
| **Best Friend**    | Energetic, encouraging, and non-judgmental                 |
| **Girlfriend**     | Affectionate, romantic, and proactive with daily check-ins |
| **Big Sister**     | Protective, honest, and playful                            |

Users can also create their own custom personas with a specific relationship type, personality description, and avatar emoji.

Built with **Flutter** for mobile, **Spring Boot** for backend services, **PostgreSQL + pgvector** for memory storage, and **Groq (Llama 3 70B)** for fast conversational AI.

---

## Features

### Core Features

* **Persistent Memory**
  Each persona remembers important facts shared by the user. Memories are stored using pgvector embeddings and retrieved contextually during conversations.

* **Real-Time Chat**
  AI responses are generated quickly using Groq's inference engine. Messages appear with smooth slide-in animations and visual feedback.

* **Custom Personas**
  Users can create their own companions by choosing a relationship type, writing a personality description, and picking an avatar. The app uses a stepped flow with live preview to make creation feel tangible.

* **Message Reactions**
  Long-press any message to add an emoji reaction. The reaction picker appears with a staggered spring animation, and the selected reaction lands with a satisfying scale bounce.

* **Proactive Notifications**
  Personas can check in on you at scheduled times. Users can schedule recurring reminders with specific times and days, and toggle them on or off.

* **Freemium Subscription**
  * Free tier: 2 personas and 50 messages per day
  * Premium tier: all personas, unlimited messages, priority response speed, and early access to new features

* **Dark Mode**
  Full dark mode support across every screen. The transition between light and dark uses a smooth crossfade instead of an instant swap.

### Design and Motion

* **Motion Design System**
  A consistent timing and easing system built into the app. Micro interactions use 150ms, card entrances use 320ms, and big moments like the splash or upgrade celebration use 700ms. Every animation respects the OS-level reduced-motion setting.

* **Haptic Feedback**
  A small, consistent vocabulary of haptics: selection clicks for pickers and scrolling, light impacts for sending messages and toggling switches, and medium impacts for completing actions like reactions or upgrades.

* **Shimmer Loading**
  Every loading state uses shaped shimmer placeholders instead of bare spinners. The persona list shows card-shaped shimmers, the chat shows alternating left-right message bubble shimmers, and memories show card shimmers.

* **Staggered Entrances**
  Lists do not just appear all at once. Persona cards, memory cards, and notification cards fade and slide up one by one with a small delay between each, making the content feel like it is arriving rather than just existing.

### Screen by Screen

* **Splash Screen**
  The logo bounces in with an elastic spring animation while the background gradient shifts through the brand colors. The subtitle slides up after the logo lands.

* **Login and Register**
  The logo scales in with a spring, then the title, fields, and button each slide up with increasing delay. On invalid input, the entire form shakes horizontally with a heavy haptic, clearly communicating "no" without being harsh.

* **Home Screen**
  Persona cards stagger in from bottom to top. Pressing a card gives it a subtle scale-down plus a glow pulse in that persona's gradient color. The create-persona FAB morphs from a plus to an X when tapped.

* **Chat Screen**
  The persona avatar in the appbar has a subtle breathing animation. New messages slide in from the side with a spring overshoot. The typing indicator has three bouncing dots with a soft persona-colored glow behind them. The reaction picker opens with each emoji scaling in one after another. A small FAB appears when you scroll up, letting you jump back to the bottom. The entire chat background has a very low-opacity tint of the current persona's color.

* **Upgrade Screen**
  A full-screen modal with an animated gradient that slowly rotates through all four persona colors. Free and premium comparison cards sit side by side, and the premium checkmarks animate in one at a time. The CTA button has a continuous shimmer sweep. On successful upgrade, a celebratory checkmark draws in with a scale animation.

* **Create Persona**
  A four-step flow (Name, Relationship, Personality, Avatar) with progress dots at the top. Each step slides in horizontally. The emoji picker has a spring scale on selection, and a live preview bubble updates as you type.

* **Memories Screen**
  Cards fade and slide up with staggered timing. Swipe left to delete with a red reveal. The loading state uses a shaped shimmer placeholder.

* **Profile Screen**
  The avatar bounces on tap with a three-stage scale animation. Navigation rows have a chevron that nudges right on press. The upgrade button opens the full-screen Upgrade modal.

* **Notifications Screen**
  Each scheduled card uses a custom animated toggle with a smooth thumb slide and color morph. Cards stagger in on load.

* **Settings Screen**
  The dark mode toggle uses an animated icon switcher that crossfades between sun and moon icons.

---

## How It Works

```text
User signs up
        |
        v
Spring Security issues JWT
        |
        v
User selects a persona
        |
        v
Persona prompt + user memories are loaded
        |
        v
User sends message
        |
        v
Backend retrieves relevant memories using pgvector
        |
        v
Groq (Llama 3 70B) generates a response
        |
        v
Important facts are extracted and stored as memories
        |
        v
Scheduler checks notification queue
        |
        v
FCM push notifications are delivered
```

---

## Tech Stack

| Layer                        | Technology                                               |
| ---------------------------- | -------------------------------------------------------- |
| **Mobile**                   | Flutter, Material Design 3                               |
| **Backend**                  | Java 17, Spring Boot 3, Spring Security, Spring Data JPA |
| **Database**                 | PostgreSQL + pgvector                                    |
| **LLM Provider**             | Groq Cloud (Llama 3 70B)                                 |
| **Authentication**           | JWT                                                      |
| **Admin Dashboard**          | React + Vite                                             |
| **Push Notifications**       | Firebase Cloud Messaging (FCM)                           |
| **Hosting**                  | Render, Fly.io                                           |
| **Managed Database Options** | Supabase, AWS RDS                                        |

---

## Project Structure

```text
innercircle/
├── backend/                          # Spring Boot 4.1 API
│   ├── src/main/java/com/innercircle/
│   │   ├── config/                   # Security, JWT, CORS, WebClient
│   │   ├── controller/               # REST endpoints (Auth, Chat, Memory, Notification, Persona, User)
│   │   ├── dto/                      # Request/response objects
│   │   ├── exception/                # Custom exceptions + global handler
│   │   ├── model/                    # JPA entities (User, Persona, Message, Conversation, Memory, etc.)
│   │   ├── repository/               # Spring Data JPA repos
│   │   ├── service/                  # Business logic (Chat, Auth, Embedding, Notification, etc.)
│   │   └── util/                     # JwtUtil
│   ├── src/main/resources/
│   │   └── application.yml
│   └── pom.xml
│
├── database/                         # SQL schemas and migrations
│   ├── schema.sql
│   └── migration_round*.sql
│
├── frontend/                         # Flutter (Dart) Android app
│   ├── lib/
│   │   ├── models/                   # Data classes (User, Persona, ChatMessage, Memory, etc.)
│   │   ├── screens/                  # UI screens (Home, Chat, Login, Register, Profile, etc.)
│   │   ├── services/                 # API client, auth, chat, push notifications, haptics
│   │   ├── theme/                    # Colors, typography, motion design tokens
│   │   └── widgets/                  # Shared widgets, splash screen, persona avatar
│   ├── android/                      # Android-specific config (Gradle, manifest, Firebase)
│   └── pubspec.yaml
│
├── .github/workflows/ci.yml         # GitHub Actions CI (backend tests, frontend analyze)
└── README.md
```

---

# Quick Start

## Prerequisites

* Java 17+
* Maven 3.8+
* Flutter 3.16+
* PostgreSQL 14+ with pgvector
* Groq API Key

Obtain a free API key from:

```text
https://console.groq.com
```

---

## 1. Clone the Repository

```bash
git clone https://github.com/rajit2004/InnerCircle.git
cd InnerCircle
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
* Database username and password
* JWT secret
* Groq API key
* Firebase credentials (optional, for push notifications)

---

## 4. Run the Backend

```bash
./mvnw spring-boot:run
```

Backend server starts at:

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
cd frontend

flutter pub get
flutter run
```

### Android Emulator

Use `10.0.2.2` instead of `localhost`.

For physical devices, use your machine's local network IP address. You can pass it as a build argument:

```bash
flutter run --dart-define=BASE_URL=http://192.168.1.100:8080
```

---

# API Documentation

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

Returns all personas the current user has access to. Free users see only free-tier personas. Premium users see all of them.

---

### Create Custom Persona

```http
POST /api/personas
```

**Request Body**

```json
{
  "name": "Alex",
  "relationshipType": "FRIEND",
  "personalityDescription": "witty and a little sarcastic",
  "avatarEmoji": "😎"
}
```

---

### Delete Custom Persona

```http
DELETE /api/personas/{id}
```

Only custom personas created by the user can be deleted.

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

**Response**

```json
{
  "reply": "Hey, talk to me. What's going on?",
  "conversationId": "uuid",
  "messageId": "uuid"
}
```

---

### Get Chat History

```http
GET /api/chat/history/{personaId}
```

Returns the most recent conversation and its messages for a given persona.

---

### Set Message Reaction

```http
POST /api/chat/reactions
```

**Request Body**

```json
{
  "messageId": "uuid",
  "reaction": "heart"
}
```

---

### Delete Conversation

```http
DELETE /api/chat/conversation/{personaId}
```

Permanently deletes the conversation history with a specific persona.

---

## Memory

### Get User Memories

```http
GET /api/memories
```

Returns all memories the system has learned about the current user across all personas.

---

### Delete Memory

```http
DELETE /api/memories/{id}
```

Removes a specific memory. The persona will forget that fact.

---

## Notifications

### Register Device Token

```http
POST /api/notifications/register
```

```json
{
  "token": "fcm_token",
  "platform": "android"
}
```

---

### Schedule Check-in

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

---

### List Scheduled Check-ins

```http
GET /api/notifications/scheduled
```

---

### Cancel Scheduled Check-in

```http
DELETE /api/notifications/schedule/{id}
```

---

## Subscription

### Update Subscription Tier

```http
POST /api/users/subscription
```

**Request Body**

```json
{
  "tier": "premium"
}
```

---

### Get User Profile

```http
GET /api/users/me
```

Returns the current user's profile including subscription tier, message usage, and account info.

---

# Deployment

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

# Contributing

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

# License

Distributed under the **MIT License**.

---

# Acknowledgements

* **Groq** for ultra-fast LLM inference
* **Spring Boot** for a robust backend ecosystem
* **Flutter** for a powerful cross-platform mobile framework
* **Supabase** for PostgreSQL hosting and pgvector support

---

# Author

**Ranesh Rajit**
B.Tech Computer Science Student, India

[![GitHub](https://img.shields.io/badge/GitHub-rajit2004-black?style=flat&logo=github)](https://github.com/rajit2004)

[![LinkedIn](https://img.shields.io/badge/LinkedIn-ranesh--kun-blue?style=flat&logo=linkedin)](https://linkedin.com/in/ranesh-kun)
