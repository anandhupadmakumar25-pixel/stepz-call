import os
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
AUTOMATION_DIR = Path(__file__).resolve().parent
REPORTS_DIR = AUTOMATION_DIR / 'reports'
SCREENSHOTS_DIR = AUTOMATION_DIR / 'screenshots'

REPORTS_DIR.mkdir(parents=True, exist_ok=True)
SCREENSHOTS_DIR.mkdir(parents=True, exist_ok=True)

DEFAULT_WEB_URL = os.environ.get('STEPZ_WEB_URL', 'http://localhost:8080')
DEFAULT_API_URL = os.environ.get('STEPZ_API_URL', 'http://127.0.0.1:8000/api/v1')
DEFAULT_SLOW_MO_MS = int(os.environ.get('STEPZ_SLOW_MO', '350'))
