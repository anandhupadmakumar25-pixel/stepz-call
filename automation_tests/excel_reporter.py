from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import List, Dict
import openpyxl
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter


@dataclass
class TestCaseResult:
    case_id: str
    section: str
    title: str
    steps: str
    expected: str
    actual: str
    status: str  # 'PASS', 'FAIL', 'SKIPPED'
    duration_ms: int = 0
    error_detail: str = ''
    screenshot_path: str = ''


class ExcelTestReporter:
    """Generates a styled Excel (.xlsx) QA execution report with Summary and Detailed Results sheets."""

    def __init__(self, output_dir: Path):
        self.output_dir = output_dir
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.results: List[TestCaseResult] = []
        self.started_at = datetime.now()

    def add_result(self, result: TestCaseResult) -> None:
        self.results.append(result)

    def save(self, filename: str | None = None) -> Path:
        if not filename:
            stamp = self.started_at.strftime('%Y%m%d_%H%M%S')
            filename = f'test_report_{stamp}.xlsx'
        out_path = self.output_dir / filename

        wb = openpyxl.Workbook()
        ws_sum = wb.active
        ws_sum.title = 'Summary'
        ws_det = wb.create_sheet('Test Results')

        # Styles
        header_fill = PatternFill(start_color='1E3A8A', end_color='1E3A8A', fill_type='solid')
        header_font = Font(color='FFFFFF', bold=True, size=11)
        title_font = Font(color='0F172A', bold=True, size=15)
        bold_font = Font(bold=True, size=11)
        pass_fill = PatternFill(start_color='D1FAE5', end_color='D1FAE5', fill_type='solid')
        pass_font = Font(color='047857', bold=True)
        fail_fill = PatternFill(start_color='FEE2E2', end_color='FEE2E2', fill_type='solid')
        fail_font = Font(color='B91C1C', bold=True)
        skip_fill = PatternFill(start_color='FEF3C7', end_color='FEF3C7', fill_type='solid')
        skip_font = Font(color='B45309', bold=True)
        thin_side = Side(style='thin', color='CBD5E1')
        border = Border(left=thin_side, right=thin_side, top=thin_side, bottom=thin_side)

        # ---- Summary Sheet ----
        ws_sum['A1'] = 'Stepz Call CRM & Payroll — Automated QA Report'
        ws_sum['A1'].font = title_font
        ws_sum['A2'] = f'Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}'
        ws_sum['A2'].font = Font(color='475569', size=10)

        total = len(self.results)
        passed = sum(1 for r in self.results if r.status == 'PASS')
        failed = sum(1 for r in self.results if r.status == 'FAIL')
        skipped = sum(1 for r in self.results if r.status == 'SKIPPED')
        executed = total - skipped
        pass_rate = (passed / executed * 100.0) if executed > 0 else 0.0

        kpis = [
            ('Total Test Cases', total),
            ('Passed', passed),
            ('Failed', failed),
            ('Skipped', skipped),
            ('Pass Rate (%)', f'{pass_rate:.1f}%'),
        ]
        for idx, (label, val) in enumerate(kpis, start=4):
            c_lbl = ws_sum.cell(row=idx, column=1, value=label)
            c_val = ws_sum.cell(row=idx, column=2, value=val)
            c_lbl.font = bold_font
            c_lbl.border = border
            c_val.border = border
            if label == 'Passed':
                c_val.fill = pass_fill
                c_val.font = pass_font
            elif label == 'Failed' and failed > 0:
                c_val.fill = fail_fill
                c_val.font = fail_font

        # Section breakdown
        sec_start = 11
        sec_headers = ['Section', 'Total', 'Passed', 'Failed', 'Skipped', 'Pass %']
        for col_i, h in enumerate(sec_headers, start=1):
            cell = ws_sum.cell(row=sec_start, column=col_i, value=h)
            cell.fill = header_fill
            cell.font = header_font
            cell.border = border

        sections: Dict[str, List[TestCaseResult]] = {}
        for r in self.results:
            sections.setdefault(r.section, []).append(r)

        for r_off, (sec_name, sec_rows) in enumerate(sections.items(), start=1):
            row_num = sec_start + r_off
            s_tot = len(sec_rows)
            s_pass = sum(1 for x in sec_rows if x.status == 'PASS')
            s_fail = sum(1 for x in sec_rows if x.status == 'FAIL')
            s_skip = sum(1 for x in sec_rows if x.status == 'SKIPPED')
            s_exec = s_tot - s_skip
            s_pct = f'{(s_pass / s_exec * 100.0):.1f}%' if s_exec > 0 else 'N/A'
            vals = [sec_name, s_tot, s_pass, s_fail, s_skip, s_pct]
            for col_i, v in enumerate(vals, start=1):
                cell = ws_sum.cell(row=row_num, column=col_i, value=v)
                cell.border = border

        for col_i, width in enumerate([34, 14, 14, 14, 14, 14], start=1):
            ws_sum.column_dimensions[get_column_letter(col_i)].width = width

        # ---- Detailed Test Results Sheet ----
        det_headers = [
            'Case ID', 'Section', 'Test Case', 'Steps',
            'Expected Result', 'Actual Result', 'Status',
            'Duration (ms)', 'Error / Screenshot',
        ]
        for col_i, h in enumerate(det_headers, start=1):
            cell = ws_det.cell(row=1, column=col_i, value=h)
            cell.fill = header_fill
            cell.font = header_font
            cell.border = border
            cell.alignment = Alignment(vertical='center', wrap_text=True)

        for idx, res in enumerate(self.results, start=2):
            extra = res.error_detail
            if res.screenshot_path:
                extra = f'{extra}\nScreenshot: {res.screenshot_path}'.strip()
            row_vals = [
                res.case_id,
                res.section,
                res.title,
                res.steps,
                res.expected,
                res.actual,
                res.status,
                res.duration_ms,
                extra,
            ]
            for col_i, v in enumerate(row_vals, start=1):
                cell = ws_det.cell(row=idx, column=col_i, value=v)
                cell.border = border
                cell.alignment = Alignment(vertical='top', wrap_text=True)
                if col_i == 7:
                    if res.status == 'PASS':
                        cell.fill = pass_fill
                        cell.font = pass_font
                    elif res.status == 'FAIL':
                        cell.fill = fail_fill
                        cell.font = fail_font
                    else:
                        cell.fill = skip_fill
                        cell.font = skip_font

        det_widths = [12, 26, 30, 42, 36, 36, 12, 14, 40]
        for col_i, width in enumerate(det_widths, start=1):
            ws_det.column_dimensions[get_column_letter(col_i)].width = width
        ws_det.freeze_panes = 'A2'

        wb.save(out_path)
        return out_path
