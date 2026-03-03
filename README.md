# Jia

A household management app for families with helpers/nannies, built for multicultural households in Singapore.

Flutter mobile app + Python FastAPI backend + PostgreSQL.

## What It Does

Families create a **household**, invite members via invite codes, and manage daily life together:

- **Family Profiles** — Each family member (adults, kids, helpers) with dietary preferences, allergies, meal schedules, and preferred language
- **Chores** — Create, assign, and track household tasks with approval workflows
- **Meals** — Recipe management and meal planning (per-member or whole household)
- **Grocery** — Shopping lists (AI-generated from meal plans, planned)
- **Calendar** — Shared household events
- **Approvals** — Kids/helpers request actions, adults approve
- **AI Assistant** — Chat-based household helper powered by Chimera LLM gateway
- **Notifications** — Real-time via WebSocket + push

## Tech Stack

| Layer | Tech |
|-------|------|
| Mobile | Flutter 3.10+ / Dart |
| State | Riverpod |
| Routing | go_router (5-tab bottom nav) |
| Backend | FastAPI (async) |
| Database | PostgreSQL 16 + SQLAlchemy async |
| Migrations | Alembic |
| Auth | Custom JWT (bcrypt + HS256, 15min access / 30-day refresh with rotation) |
| AI | Chimera LLM Gateway (Qwen 2.5 7B) |
| Deploy | Docker Compose |

## Languages

6 languages, all fully translated (~200 keys each):

| Code | Language |
|------|----------|
| `en` | English |
| `zh` | Simplified Chinese |
| `ms` | Malay |
| `tl` | Tagalog / Filipino |
| `id` | Indonesian |
| `my` | Burmese (Myanmar) |

## Project Structure

```
.
├── app/                          # Flutter mobile app
│   ├── lib/
│   │   ├── core/                 # Network, router, theme, auth
│   │   ├── features/             # Feature-first architecture
│   │   │   ├── ai/               # AI chat + onboarding
│   │   │   ├── approvals/        # Approval workflows
│   │   │   ├── auth/             # Login, register
│   │   │   ├── calendar/         # Shared calendar
│   │   │   ├── chores/           # Chore management
│   │   │   ├── dashboard/        # Home dashboard
│   │   │   ├── grocery/          # Grocery lists
│   │   │   ├── household/        # Household setup, members
│   │   │   ├── meals/            # Recipes, meal plans
│   │   │   ├── notifications/    # Notification center
│   │   │   └── settings/         # App settings
│   │   └── l10n/                 # Localization (6 ARB files)
│   └── pubspec.yaml
│
├── backend/                      # Python FastAPI backend
│   ├── app/
│   │   ├── api/v1/               # Route handlers
│   │   ├── core/                 # Config, DB, auth, WebSocket
│   │   ├── models/               # SQLAlchemy models
│   │   ├── schemas/              # Pydantic request/response
│   │   └── services/             # Business logic
│   ├── alembic/                  # DB migrations
│   ├── Dockerfile
│   └── requirements.txt
│
├── docker-compose.yml
└── docs/
    └── AI_INTEGRATION_GUIDE.md
```

Each feature folder follows:
```
feature/
├── models/           # Data models (fromJson/toJson + copyWith)
├── providers/        # Riverpod state
├── repositories/     # API calls via Dio
├── screens/          # UI screens
└── widgets/          # Reusable widgets
```

## API Endpoints

All routes under `/api/v1`:

| Route | Description |
|-------|-------------|
| `POST /auth/register` | Create account |
| `POST /auth/login` | JWT login |
| `POST /auth/refresh` | Rotate refresh token |
| `GET/PATCH /users/me` | User profile |
| `POST /households/` | Create household |
| `POST /households/join` | Join via invite code |
| `GET /households/{id}/members` | List members |
| `GET/POST/PATCH/DELETE /households/{id}/profiles` | Family profiles (dietary, allergies, meal times) |
| `GET/POST /chores/` | Chore CRUD |
| `GET/POST /meals/recipes` | Recipe CRUD |
| `GET/POST /meals/plans` | Meal plan CRUD |
| `GET/POST /grocery/` | Grocery list CRUD |
| `GET/POST /calendar/` | Calendar events |
| `GET/POST /approvals/` | Approval workflows |
| `POST /ai/{id}/chat` | AI assistant chat |
| `WS /ws/{household_id}` | Real-time notifications |

## Database Schema (Key Tables)

```
users                 — accounts, JWT auth
households            — family unit, invite codes
household_members     — user-to-household (roles: family_adult, family_kid, helper)
family_profiles       — per-member dietary prefs, allergies, meal times, language
recipes               — meal recipes
recipe_ingredients    — structured ingredients per recipe
meal_plans            — scheduled meals (per-member via profile_id, or household-wide)
chores                — household tasks
grocery_lists         — shopping lists
grocery_items         — items on a list
calendar_events       — shared events
approvals             — approval workflows
ai_conversations      — AI chat history
ai_messages           — individual chat messages
ai_memories           — AI-learned household context
notifications         — push/in-app notifications
content_translations  — LLM translation cache
```

## Setup

### Backend

```bash
# Start PostgreSQL + backend
docker compose up -d

# Or run locally
cd backend
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --host 0.0.0.0 --port 8082 --reload
```

Environment variables (`.env` in backend/):
```
DATABASE_URL=postgresql+asyncpg://household:household@localhost:5432/household_mgmt
SECRET_KEY=your-secret-key
CORS_ORIGINS=*
CHIMERA_BASE_URL=https://console.epy.digital/api/chat
```

### Flutter App

```bash
cd app
flutter pub get
flutter gen-l10n
flutter run
```

The app connects to `http://10.0.2.2:8082/api/v1` on Android emulator (localhost from host).

## Implementation Status

### Done

- [x] Auth (register, login, JWT with refresh rotation)
- [x] Households (create, join via invite code, member management)
- [x] Family profiles backend (per-member dietary prefs, allergies, meal schedules)
- [x] Chores (CRUD, assignment, completion)
- [x] Meals (recipes, meal plans)
- [x] Grocery (shopping lists, items)
- [x] Calendar (events)
- [x] Approvals (request/approve workflow)
- [x] AI assistant (chat, onboarding, memory)
- [x] Notifications (WebSocket + in-app)
- [x] Dashboard (summary cards)
- [x] Full l10n (6 languages, ~200 keys each)
- [x] 5-tab bottom nav (Dashboard, Chores, Calendar, Grocery, Settings)
- [x] Recipe ingredients model + migration
- [x] Content translations table for LLM translation cache

- [x] Family setup wizard (Flutter UI for adding family members with dietary/allergy/schedule info)
- [x] Smart meals (per-member meal assignment via family profiles)
- [x] AI grocery generation (AI chat integration from grocery screen)
- [x] Dashboard interactivity (tappable chore/meal/approval cards with navigation)
- [x] AI language sync (AI responds in user's preferred language with full names)

### Planned

- [ ] Push notifications (FCM)
- [ ] Offline mode
- [ ] Myanmar font support
- [ ] Image uploads (avatars, recipe photos)
- [ ] QR code household invites
- [ ] Gamification (chore points, streaks)

## License

Private — Epyphite
