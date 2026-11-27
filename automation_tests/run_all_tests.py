import argparse
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from automation_tests.config import DEFAULT_SLOW_MO_MS, DEFAULT_WEB_URL, REPORTS_DIR
from automation_tests.excel_46_template import save_46_case_excel
from automation_tests.excel_reporter import ExcelTestReporter
from automation_tests.suites.api_e2e_suite import run_api_e2e_suite
from automation_tests.suites.web_visual_suite import run_web_visual_suite


def main():
    parser = argparse.ArgumentParser(description='Stepz Call CRM & Payroll Automation Test Runner')
    parser.add_argument('--mode', choices=['all', 'api', 'web'], default='all', help='Which suites to run')
    parser.add_argument('--web-url', default=DEFAULT_WEB_URL, help='Flutter Web URL for Playwright visual tests')
    parser.add_argument('--email', default='', help='Login email for visual browser tests')
    parser.add_argument('--password', default='', help='Login password for visual browser tests')
    parser.add_argument('--headless', action='store_true', help='Run Chrome in headless mode (default is visible)')
    parser.add_argument('--slow-mo', type=int, default=DEFAULT_SLOW_MO_MS, help='Delay in ms between browser actions')
    parser.add_argument('--output', default='', help='Optional custom Excel filename inside automation_tests/reports/')
    args = parser.parse_args()

    reporter = ExcelTestReporter(REPORTS_DIR)

    if args.mode in ('all', 'api'):
        print('\n=== Running Backend API End-to-End Suite ===')
        for res in run_api_e2e_suite():
            reporter.add_result(res)
            print(f'[{res.status}] {res.case_id} - {res.title} ({res.duration_ms} ms)')

    if args.mode in ('all', 'web'):
        print(f'\n=== Running Live Visual Browser Suite ({args.web_url}) ===')
        for res in run_web_visual_suite(
            web_url=args.web_url,
            headed=not args.headless,
            slow_mo_ms=args.slow_mo,
            email=args.email,
            password=args.password,
        ):
            reporter.add_result(res)
            print(f'[{res.status}] {res.case_id} - {res.title} ({res.duration_ms} ms)')

    report_path = reporter.save(args.output or None)
    report_46_path = save_46_case_excel(
        reporter.results,
        REPORTS_DIR / f'manual_46_cases_status_{reporter.started_at.strftime("%Y%m%d_%H%M%S")}.xlsx',
    )
    passed = sum(1 for r in reporter.results if r.status == 'PASS')
    failed = sum(1 for r in reporter.results if r.status == 'FAIL')
    skipped = sum(1 for r in reporter.results if r.status == 'SKIPPED')

    print('\n========================================')
    print(f'TOTAL: {len(reporter.results)} | PASS: {passed} | FAIL: {failed} | SKIPPED: {skipped}')
    print(f'Excel Report saved to: {report_path}')
    print(f'46-Case QA Sheet saved to: {report_46_path}')
    print('========================================\n')

    if failed > 0:
        sys.exit(1)


if __name__ == '__main__':
    main()
