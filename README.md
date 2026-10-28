# Telecaller CRM SaaS Platform

An enterprise multi-tenant CRM SaaS designed for businesses that import customer phone numbers, assign leads to telecallers, initiate calls through the normal Android dialer, record call outcomes, schedule callbacks, notify employees, and monitor performance.

---

## 🚀 Key Highlights & Business Invariants

- **Permanent Phone-Number Blocking Invariant**:
  A normalized phone number may be assigned only once within the lifetime of a company's records. Even if an active lead is completed, deleted, or archived, the number remains permanently blocked from future allocation in that company, while other companies remain completely unaffected.
- **Multi-Tenant Server-Enforced Isolation**:
  Strict tenant boundaries across all APIs, models, and operations. Company identity is derived server-side from JWT authentication.
- **Real Excel (.xlsx) & CSV Import Wizard**:
  Uploads spreadsheets, validates country-aware E.164 phone numbers, checks the company's permanent registry, flags in-file duplicates and invalid numbers, renders an interactive preview summary, and commits valid leads into the database pool.
- **Bulk Lead Assignment Engine**:
  Concurrency-safe distribution (`EQUAL`, `PERCENTAGE`, `CUSTOM`) with transactional database locks (`select_for_update()`), permanent registry insertion, assignment history tracking, and telecaller notifications.
- **Normal Android Dialer Calling & Call Outcomes**:
  Launches the native phone dialer (`tel:<phone_number>`), displays the call outcome form with mandatory conversation notes, auto-updates lead lifecycle states, and optionally schedules follow-up callbacks.
- **Callback Reminders Engine**:
  Full lifecycle tracking (`SCHEDULED` ➔ `DUE` ➔ `OVERDUE` ➔ `COMPLETED` / `RESCHEDULED`). Background worker scans due/overdue callbacks and triggers in-app alerts.
- **Ultra-Modern Responsive Flutter UI**:
  One unified Flutter codebase supporting Desktop Web (navy navigation sidebar), Tablet (adaptive navigation), and Android Mobile (telecaller bottom navigation).

---

## 🛠️ Technology Stack

- **Backend**: Python 3.11, Django 5.0, Django REST Framework, SimpleJWT, `phonenumbers`, `openpyxl`, `drf-spectacular` (OpenAPI 3.0 / Swagger).
- **Database**: SQLite (local development) with seamless migration to MySQL 8.0+ (production).
- **Frontend**: Flutter 3.35+ (Dart 3.9+), Provider state management, `fl_chart`, `url_launcher`, `file_picker`, Google Fonts (Inter).

---

## ⚡ Quick Start & Local Development

### 1. Backend Setup

```bash
cd backend

# 1. Activate Python virtual environment
.\venv\Scripts\activate   # On Windows (PowerShell)

# 2. Run database migrations
python manage.py migrate

# 3. Seed demo accounts, companies, leads, and callbacks
python manage.py seed_demo_data

# 4. Start the Django development server
python manage.py runserver 0.0.0.0:8000
```

The REST API and interactive Swagger documentation will be available at:
- **Swagger UI**: `http://127.0.0.1:8000/api/docs/`
- **ReDoc**: `http://127.0.0.1:8000/api/redoc/`
- **OpenAPI Schema**: `http://127.0.0.1:8000/api/schema/`

### 2. Run Background Callback Reminder Worker (Optional)

```bash
cd backend
python manage.py run_reminder_worker --interval 60
```

### 3. Frontend Setup & Run

```bash
cd frontend

# 1. Install Flutter dependencies
flutter pub get

# 2. Run Flutter Web
flutter run -d chrome

# Or run on Android emulator
flutter run -d android
```

---

## 🔑 Pre-Seeded Test Accounts

| Role | Email | Password | Scope / Capabilities |
| :--- | :--- | :--- | :--- |
| **Super Admin** | `superadmin@telecaller.crm` | `SuperAdmin123!` | Manages companies, views platform status |
| **Company Admin** | `admin@apex.com` | `Admin123!` | Apex Global: Lead imports, bulk assign, caller management |
| **Manager** | `manager@apex.com` | `Manager123!` | Apex Global: Team supervision, callbacks overview |
| **Telecaller 1** | `caller1@apex.com` | `Caller123!` | Apex Global: Assigned leads, Android calling, outcome notes |
| **Telecaller 2** | `caller2@apex.com` | `Caller123!` | Apex Global: Assigned leads, Android calling, outcome notes |
| **Zenith Admin** | `admin@zenith.com` | `Admin123!` | Zenith Technologies: Isolated company tenant |

---

## 🧪 Automated Testing

### Backend Test Suite (Django)
Verifies multi-tenancy isolation, permanent phone number registry invariants, bulk distribution, phone normalization, call outcomes, and file imports:

```bash
cd backend
python manage.py test tests
```
*Result: 7 tests passed with 100% OK.*

### Frontend Test Suite (Flutter)
Verifies widget rendering, branding, input fields, and demo credential interactions:

```bash
cd frontend
flutter test
```
*Result: All tests passed with 100% OK.*

### Frontend Production Web Build
```bash
cd frontend
flutter build web
```
*Result: Successfully built `build/web` with zero errors.*

---

## 📁 Repository Structure

```
stepz_call/
├── backend/
│   ├── apps/
│   │   ├── accounts/       # User model, Team, EmployeeProfile, JWT Auth, RBAC
│   │   ├── analytics/      # Admin & Telecaller dashboard metric queries
│   │   ├── callbacks/      # Callback lifecycle and reminder scheduler worker
│   │   ├── calls/          # CallAttempt model, outcome logging
│   │   ├── companies/      # Company tenant model and status management
│   │   ├── core/           # TenantModel, E.164 normalization, permissions, audit
│   │   ├── leads/          # PermanentPhoneNumberRegistry, Lead, Excel/CSV Import, Bulk Assign
│   │   └── notifications/  # In-app notifications and push token registry
│   ├── config/             # Django settings, master URLs, Swagger config
│   ├── tests/              # Automated backend test suite
│   ├── requirements.txt
│   └── manage.py
├── frontend/
│   ├── lib/
│   │   ├── core/           # Design tokens, theme, API client, responsive layout, widgets
│   │   ├── models/         # User, Lead, Call, Callback, Dashboard typed models
│   │   ├── providers/      # Clean architecture Provider state management
│   │   └── screens/        # Auth, Responsive Layout, Dashboard, Leads, Calls, Callbacks, Employees, Companies
│   ├── test/               # Flutter automated widget tests
│   └── pubspec.yaml
├── docs/
│   └── SQLITE_TO_MYSQL_MIGRATION.md # Step-by-step production database migration plan
├── .env.example
├── .gitignore
└── README.md
```
