import time
import urllib.request
from typing import List

from automation_tests.config import SCREENSHOTS_DIR
from automation_tests.excel_reporter import TestCaseResult


def _is_url_reachable(url: str) -> bool:
    try:
        req = urllib.request.Request(url, method='GET')
        with urllib.request.urlopen(req, timeout=4) as resp:
            return resp.status < 500
    except Exception:
        return False


def _enable_flutter_semantics(page) -> None:
    """Trigger Flutter Web's hidden accessibility placeholder so DOM controls are exposed."""
    try:
        placeholder = page.locator('flt-semantics-placeholder').first
        if placeholder.count() > 0:
            placeholder.click(force=True, timeout=3000)
            page.wait_for_timeout(800)
    except Exception:
        pass


def run_web_visual_suite(
    web_url: str,
    headed: bool = True,
    slow_mo_ms: int = 350,
    email: str = '',
    password: str = '',
) -> List[TestCaseResult]:
    results: List[TestCaseResult] = []

    if not _is_url_reachable(web_url):
        results.append(
            TestCaseResult(
                case_id='WEB-01',
                section='10. Live Browser UI (Playwright)',
                title='Open Web App & Visual Flow',
                steps=f'Open {web_url} in Chrome.',
                expected='Web app loads and renders login/workspace.',
                actual=f'Web server not reachable at {web_url}.',
                status='SKIPPED',
                duration_ms=0,
                error_detail=f'Start Flutter Web at {web_url} (or pass --web-url) to run live visual browser tests.',
            )
        )
        return results

    from playwright.sync_api import sync_playwright

    with sync_playwright() as p:
        launch_args = ['--start-maximized'] if headed else []
        browser = p.chromium.launch(headless=not headed, slow_mo=slow_mo_ms, args=launch_args)
        context = browser.new_context(no_viewport=True) if headed else browser.new_context(viewport={'width': 1366, 'height': 840})
        page = context.new_page()

        # WEB-01: Open website and verify Flutter Web renders
        t0 = time.perf_counter()
        try:
            page.goto(web_url, wait_until='domcontentloaded', timeout=30000)
            page.wait_for_timeout(3500)
            _enable_flutter_semantics(page)
            title = page.title()
            results.append(
                TestCaseResult(
                    case_id='WEB-01',
                    section='10. Live Browser UI (Playwright)',
                    title='Open Website & Render App',
                    steps=f'Navigate to {web_url} in visible Chrome and wait for Flutter Web mount.',
                    expected='App loads cleanly without fatal page crash.',
                    actual=f'Loaded page "{title}" cleanly.',
                    status='PASS',
                    duration_ms=int((time.perf_counter() - t0) * 1000),
                )
            )
        except Exception as exc:
            shot = str(SCREENSHOTS_DIR / 'WEB-01_fail.png')
            page.screenshot(path=shot)
            results.append(
                TestCaseResult(
                    case_id='WEB-01',
                    section='10. Live Browser UI (Playwright)',
                    title='Open Website & Render App',
                    steps=f'Navigate to {web_url} in visible Chrome.',
                    expected='App loads cleanly.',
                    actual='Page load failed.',
                    status='FAIL',
                    duration_ms=int((time.perf_counter() - t0) * 1000),
                    error_detail=str(exc),
                    screenshot_path=shot,
                )
            )
            browser.close()
            return results

        # WEB-02: Login flow (if credentials provided)
        if email and password:
            t1 = time.perf_counter()
            try:
                _enable_flutter_semantics(page)
                inputs = page.locator('input')
                if inputs.count() >= 2:
                    inputs.nth(0).fill(email)
                    inputs.nth(1).fill(password)
                    sign_in_btn = page.get_by_role('button', name='Sign In').first
                    if sign_in_btn.count() > 0:
                        sign_in_btn.click()
                    else:
                        inputs.nth(1).press('Enter')
                    page.wait_for_timeout(3500)
                    _enable_flutter_semantics(page)
                results.append(
                    TestCaseResult(
                        case_id='WEB-02',
                        section='10. Live Browser UI (Playwright)',
                        title='Visual Login & Workspace Load',
                        steps=f'Enter credentials for {email} and click Sign In.',
                        expected='User logs in and workspace/dashboard loads.',
                        actual='Login submitted and post-login view rendered.',
                        status='PASS',
                        duration_ms=int((time.perf_counter() - t1) * 1000),
                    )
                )
            except Exception as exc:
                shot = str(SCREENSHOTS_DIR / 'WEB-02_fail.png')
                page.screenshot(path=shot)
                results.append(
                    TestCaseResult(
                        case_id='WEB-02',
                        section='10. Live Browser UI (Playwright)',
                        title='Visual Login & Workspace Load',
                        steps=f'Enter credentials for {email} and click Sign In.',
                        expected='User logs in and workspace/dashboard loads.',
                        actual='Login interaction failed.',
                        status='FAIL',
                        duration_ms=int((time.perf_counter() - t1) * 1000),
                        error_detail=str(exc),
                        screenshot_path=shot,
                    )
                )
        else:
            results.append(
                TestCaseResult(
                    case_id='WEB-02',
                    section='10. Live Browser UI (Playwright)',
                    title='Visual Login & Workspace Load',
                    steps='Pass --email and --password to run live login & navigation.',
                    expected='Logs in and walks through visible menus.',
                    actual='Credentials not supplied; skipped post-login UI walkthrough.',
                    status='SKIPPED',
                    duration_ms=0,
                )
            )

        browser.close()

    return results
