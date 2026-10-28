# SQLite to MySQL Migration Guide & Integrity Validation

This document outlines the end-to-end procedure for migrating the **Telecaller CRM SaaS** platform from local SQLite development to MySQL 8.0+ production.

---

## 1. Architectural Compatibility & Portability

The data models have been architected specifically for database portability:
1. **Portable Types**:
   - `UUIDField` stores clean 32-character hex strings in MySQL and SQLite.
   - `JSONField` utilizes native MySQL 5.7+ / 8.0+ binary JSON.
   - `DateTimeField` with `USE_TZ = True` stores UTC timestamps across both engines.
2. **Database Constraints**:
   - The critical business invariant `PermanentPhoneNumberRegistry` enforces:
     ```python
     models.UniqueConstraint(
         fields=['company', 'normalized_phone'],
         name='unique_company_normalized_phone'
     )
     ```
     This translates cleanly to a compound composite unique index in MySQL with `utf8mb4_unicode_ci`.
3. **Transactions**:
   - Critical workflows (`bulk_assign`, `confirm_import`, `log_call_outcome`) utilize `transaction.atomic()` with `select_for_update()`, which leverages MySQL row-level locking with InnoDB.

---

## 2. Prerequisites on MySQL Server

1. **Create the Database with utf8mb4**:
   ```sql
   CREATE DATABASE telecaller_crm
     CHARACTER SET utf8mb4
     COLLATE utf8mb4_unicode_ci;
   ```
2. **Grant Permissions**:
   ```sql
   CREATE USER 'telecaller_user'@'%' IDENTIFIED BY 'StrongPassword123!';
   GRANT ALL PRIVILEGES ON telecaller_crm.* TO 'telecaller_user'@'%';
   FLUSH PRIVILEGES;
   ```

---

## 3. Migration Procedure

### Step 3.1: Backup the Existing SQLite Database
```bash
# In the backend directory
python manage.py dumpdata \
  --natural-foreign \
  --natural-primary \
  --exclude contenttypes \
  --exclude auth.permission \
  --indent 2 > datadump_sqlite_backup.json
```

### Step 3.2: Configure Environment for MySQL
Set the following environment variables in `.env` or system environment:
```env
DB_ENGINE=mysql
DB_NAME=telecaller_crm
DB_USER=telecaller_user
DB_PASSWORD=StrongPassword123!
DB_HOST=127.0.0.1
DB_PORT=3306
```

Ensure `mysqlclient` or `PyMySQL` is installed:
```bash
pip install mysqlclient
```

### Step 3.3: Apply Schema Migrations to MySQL
```bash
python manage.py migrate
```

### Step 3.4: Restore Data into MySQL
```bash
python manage.py loaddata datadump_sqlite_backup.json
```

---

## 4. Post-Migration Integrity Verification Checklist

Run these SQL and ORM queries to verify 100% data fidelity:

### 1. Count Parity Check
```bash
python manage.py shell -c "
from apps.companies.models import Company
from apps.accounts.models import User
from apps.leads.models import Lead, PermanentPhoneNumberRegistry
from apps.calls.models import CallAttempt
from apps.callbacks.models import Callback

print('Companies:', Company.objects.count())
print('Users:', User.objects.count())
print('Leads:', Lead.objects.count())
print('Permanent Registry:', PermanentPhoneNumberRegistry.objects.count())
print('Call Attempts:', CallAttempt.objects.count())
print('Callbacks:', Callback.objects.count())
"
```

### 2. Verify Permanent Phone Number Registry Uniqueness on MySQL
Attempt to insert an identical phone number under the same company to ensure the MySQL unique constraint fires:
```bash
python manage.py shell -c "
from apps.companies.models import Company
from apps.leads.models import PermanentPhoneNumberRegistry
from django.db import IntegrityError

comp = Company.objects.first()
reg = PermanentPhoneNumberRegistry.objects.filter(company=comp).first()
if reg:
    try:
        PermanentPhoneNumberRegistry.objects.create(
            company=comp,
            normalized_phone=reg.normalized_phone
        )
        print('FAILED: Duplicate permitted on MySQL!')
    except IntegrityError:
        print('PASSED: MySQL compound unique constraint is strictly enforced.')
"
```

### 3. Run Backend Test Suite against MySQL
```bash
python manage.py test tests
```
Ensure all 7 tests pass with `OK`.
