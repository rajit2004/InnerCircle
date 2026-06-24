InnerCircle – Project Structure (Packages)

Base Package: com.innercircle

com.innercircle
├── InnerCircleApplication.java                 # Main Spring Boot entry point
│
├── config                                      # Configuration classes
│   ├── SecurityConfig.java                     # Spring Security + JWT config
│   ├── JwtAuthFilter.java                      # JWT validation filter
│   ├── WebClientConfig.java                    # Groq WebClient bean
│   ├── CorsConfig.java                         # CORS configuration
│   └── AppConfig.java                          # Other app-wide beans
│
├── controller                                  # REST endpoints
│   ├── AuthController.java                     # /api/auth/register, /login
│   ├── ChatController.java                     # /api/chat (SSE streaming)
│   ├── PersonaController.java                  # /api/personas
│   ├── MemoryController.java                   # /api/memories
│   └── NotificationController.java             # /api/notifications/register, /schedule
│
├── service                                     # Business logic
│   ├── AuthService.java                        # Register/login with password hashing
│   ├── ChatService.java                        # Groq streaming + memory injection
│   ├── MemoryService.java                      # Memory extraction + pgvector search
│   ├── PersonaService.java                     # Persona tier checks
│   └── NotificationService.java                # FCM push + scheduled jobs
│
├── repository                                  # JPA data access
│   ├── UserRepository.java
│   ├── PersonaRepository.java
│   ├── ConversationRepository.java
│   ├── MessageRepository.java
│   └── MemoryRepository.java
│
├── entity                                      # JPA entities (models)
│   ├── User.java
│   ├── Persona.java
│   ├── Conversation.java
│   ├── Message.java
│   └── Memory.java
│
├── dto                                         # Data Transfer Objects
│   ├── AuthRequest.java
│   ├── AuthResponse.java
│   ├── ChatRequest.java
│   ├── ChatResponse.java
│   └── NotificationRequest.java
│
├── exception                                   # Global error handling
│   ├── GlobalExceptionHandler.java             # @ControllerAdvice
│   ├── ResourceNotFoundException.java
│   ├── DuplicateEmailException.java
│   └── UnauthorizedException.java
│
└── util                                        # Utility classes
├── JwtUtil.java                            # JWT generation + validation
└── EmbeddingUtil.java                      # Placeholder for vector embeddings (optional)

📦 Other Project Artifacts (outside Java packages)

project-root/
├── src/main/resources/
│   ├── application.yml                         # Main config (DB, Groq, JWT)
│   └── application-dev.yml                     # Dev overrides (optional)
│
├── src/test/
│   └── java/com/innercircle/
│       └── InnerCircleApplicationTests.java    # Unit tests (basic)
│
├── database/
│   └── schema.sql                              # PostgreSQL schema + pgvector
│
├── mobile/                                     # Flutter app (to be added)
├── admin/                                      # React admin dashboard (to be added)
│
├── .gitignore
├── pom.xml                                     # Maven dependencies
├── mvnw / mvnw.cmd                             # Maven wrapper scripts
└── README.md                                   # Project overview

🧩 Package Relationships (Visual)

┌─────────────────────────────────────────────────────────────┐
│                     com.innercircle                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │   config    │    │  controller │    │    dto      │      │
│  └─────────────┘    └─────────────┘    └─────────────┘      │
│         │                  │                  │             │
│         ▼                  ▼                  ▼             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │   service   │◄───│ repository  │───►│   entity    │      │
│  └─────────────┘    └─────────────┘    └─────────────┘      │
│         │                                        │          │
│         ▼                                        ▼          │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │  exception  │    │    util     │    │  (external) │      │
│  └─────────────┘    └─────────────┘    └─────────────┘      │
│                                                             │
└─────────────────────────────────────────────────────────────┘