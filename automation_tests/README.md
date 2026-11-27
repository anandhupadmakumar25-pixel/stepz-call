# Stepz Call CRM & Payroll — Automated QA Suite

This folder runs end-to-end automated tests and outputs a color-coded Excel (`.xlsx`) report with **Summary** and **Test Results** sheets.

## Run Commands (from project root `f:\stepz\stepz_call`)

### 1. Run Backend API E2E + Generate Excel Report
```powershell
backend\venv\Scripts\python.exe automation_tests\run_all_tests.py --mode api
```

### 2. Watch Live Chrome Visual Tests + API Tests (Full Suite)
Start your Flutter Web app (e.g. `http://localhost:8080`), then run:
```powershell
backend\venv\Scripts\python.exe automation_tests\run_all_tests.py --mode all --web-url http://localhost:8080 --email your@email.com --password YourPassword
```
- Chrome opens visibly (`headed` mode) with a `350ms` step delay (`--slow-mo 350`) so you can watch every action.
- Add `--headless` to run without opening a browser window.

### 3. Output
- Excel reports are saved to `automation_tests/reports/test_report_<timestamp>.xlsx`.
- Failure screenshots (if any visual step fails) are saved to `automation_tests/screenshots/`.
