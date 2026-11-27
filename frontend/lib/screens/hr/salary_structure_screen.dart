import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/glass/app_background.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/hr_payroll_provider.dart';

class SalaryStructureScreen extends StatefulWidget {
  final String? initialUserId;

  const SalaryStructureScreen({super.key, this.initialUserId});

  @override
  State<SalaryStructureScreen> createState() => _SalaryStructureScreenState();
}

class _SalaryStructureScreenState extends State<SalaryStructureScreen> {
  String? _selectedUserId;
  String _currency = 'INR';

  final _basicCtrl = TextEditingController(text: '0');
  final _hraCtrl = TextEditingController(text: '0');
  final _allowCtrl = TextEditingController(text: '0');
  final _pfCtrl = TextEditingController(text: '0');
  final _esiCtrl = TextEditingController(text: '0');
  final _taxCtrl = TextEditingController(text: '0');
  final _salaryDayCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accountNoCtrl = TextEditingController();
  final _ifscIbanCtrl = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_basicCtrl, _hraCtrl, _allowCtrl, _pfCtrl, _esiCtrl, _taxCtrl]) {
      c.addListener(() {
        if (mounted) setState(() {});
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authUser = context.read<AuthProvider>().currentUser;
      final empProv = context.read<EmployeeProvider>();
      final hr = context.read<HrPayrollProvider>();
      if (empProv.employees.isEmpty) {
        await empProv.fetchEmployees();
      }
      await hr.fetchSalaryStructures();
      if (!mounted) return;
      final emps = empProv.employees;
      final defaultCurr = authUser?.companyCurrency ?? 'INR';
      String? initialId = widget.initialUserId;
      if ((initialId == null || initialId.isEmpty) && emps.isNotEmpty) {
        initialId = _empIdOf(emps.first);
      }
      setState(() {
        _currency = defaultCurr;
        _selectedUserId = initialId;
      });
      if (initialId != null) {
        _prefillFor(initialId, defaultCurr);
      }
    });
  }

  @override
  void dispose() {
    _basicCtrl.dispose();
    _hraCtrl.dispose();
    _allowCtrl.dispose();
    _pfCtrl.dispose();
    _esiCtrl.dispose();
    _taxCtrl.dispose();
    _salaryDayCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNoCtrl.dispose();
    _ifscIbanCtrl.dispose();
    super.dispose();
  }

  String _empIdOf(dynamic e) => (e is Map ? e['id'] : e.id)?.toString() ?? '';

  String _empNameOf(dynamic e) {
    if (e is Map) {
      final full = (e['full_name'] ?? '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}').toString().trim();
      final email = (e['email'] ?? '').toString();
      return full.isNotEmpty ? '$full ($email)' : email;
    }
    return e.fullName?.toString() ?? 'Employee';
  }

  void _prefillFor(String userId, String fallbackCurrency) {
    final hr = context.read<HrPayrollProvider>();
    final matches = hr.salaryStructures.where((s) => s['user']?.toString() == userId).toList();
    if (matches.isNotEmpty) {
      final s = matches.first;
      setState(() {
        _currency = (s['currency']?.toString().isNotEmpty == true) ? s['currency'].toString() : fallbackCurrency;
        _basicCtrl.text = (s['basic_salary'] ?? '0').toString();
        _hraCtrl.text = (s['hra'] ?? '0').toString();
        _allowCtrl.text = (s['allowances'] ?? '0').toString();
        _pfCtrl.text = (s['pf_deduction'] ?? '0').toString();
        _esiCtrl.text = (s['esi_deduction'] ?? '0').toString();
        _taxCtrl.text = (s['tax_deduction'] ?? '0').toString();
        _salaryDayCtrl.text = s['salary_day_override']?.toString() ?? '';
        _bankNameCtrl.text = (s['bank_name'] ?? '').toString();
        _accountNoCtrl.text = (s['account_number'] ?? '').toString();
        _ifscIbanCtrl.text = (s['ifsc_iban'] ?? '').toString();
      });
    } else {
      setState(() {
        _currency = fallbackCurrency;
        _basicCtrl.text = '0';
        _hraCtrl.text = '0';
        _allowCtrl.text = '0';
        _pfCtrl.text = '0';
        _esiCtrl.text = '0';
        _taxCtrl.text = '0';
        _salaryDayCtrl.text = '';
        _bankNameCtrl.text = '';
        _accountNoCtrl.text = '';
        _ifscIbanCtrl.text = '';
      });
    }
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0.0;

  void _openQuickSplitDialog() {
    final grossCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auto-Split Monthly Gross'),
        content: TextField(
          controller: grossCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Target Monthly Gross ($_currency)',
            hintText: 'e.g. 30000',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF047857), foregroundColor: Colors.white),
            onPressed: () {
              final total = double.tryParse(grossCtrl.text.trim()) ?? 0;
              if (total > 0) {
                setState(() {
                  _basicCtrl.text = (total * 0.50).toStringAsFixed(2);
                  _hraCtrl.text = (total * 0.30).toStringAsFixed(2);
                  _allowCtrl.text = (total * 0.20).toStringAsFixed(2);
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Apply 50 / 30 / 20 Split'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_selectedUserId == null || _selectedUserId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an employee.'), backgroundColor: Color(0xFFF59E0B)),
      );
      return;
    }
    setState(() => _isSaving = true);
    final hr = context.read<HrPayrollProvider>();
    final ok = await hr.saveSalaryStructure({
      'user': _selectedUserId,
      'currency': _currency,
      'basic_salary': _num(_basicCtrl),
      'hra': _num(_hraCtrl),
      'allowances': _num(_allowCtrl),
      'pf_deduction': _num(_pfCtrl),
      'esi_deduction': _num(_esiCtrl),
      'tax_deduction': _num(_taxCtrl),
      'bank_name': _bankNameCtrl.text.trim(),
      'account_number': _accountNoCtrl.text.trim(),
      'ifsc_iban': _ifscIbanCtrl.text.trim(),
      if (_salaryDayCtrl.text.trim().isNotEmpty)
        'salary_day_override': (int.tryParse(_salaryDayCtrl.text.trim()) ?? 5).clamp(1, 31)
      else
        'salary_day_override': null,
    });
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee salary structure saved!'), backgroundColor: Color(0xFF059669)),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hr.errorMessage ?? 'Failed to save salary structure'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  InputDecoration _fieldDecoration(String label, {String? hint, String? prefixText, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF64748B)) : null,
      labelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, String subtitle, Color accent) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accent, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B))),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final emps = context.watch<EmployeeProvider>().employees;
    final authUser = context.watch<AuthProvider>().currentUser;
    final fallbackCurr = authUser?.companyCurrency ?? 'INR';
    final isMobile = ResponsiveLayout.isMobile(context);

    final gross = _num(_basicCtrl) + _num(_hraCtrl) + _num(_allowCtrl);
    final fixedDed = _num(_pfCtrl) + _num(_esiCtrl) + _num(_taxCtrl);
    final estNet = (gross - fixedDed).clamp(0.0, double.infinity);
    final netRatio = gross > 0 ? (estNet / gross).clamp(0.0, 1.0) : 1.0;

    return AppBackground(
      preset: AppBackgroundPreset.cleanEnterprise,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(isMobile ? 10 : 16, 14, isMobile ? 10 : 16, 24),
            child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Executive Header Bar
                    GlassCard(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 14),
                      borderRadius: BorderRadius.circular(16),
                      child: Row(
                        children: [
                          const AppBackButton(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Employee Salary Structure',
                                  style: GoogleFonts.inter(
                                    fontSize: isMobile ? 17 : 20,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Configure monthly compensation, statutory deductions, payday & bank payout details',
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          if (!isMobile) ...[
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: _isSaving ? null : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 10),
                            GradientPrimaryButton(
                              text: _isSaving ? 'Saving...' : 'Save Salary Structure',
                              icon: Icons.check_circle_outline_rounded,
                              height: 42,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              gradient: AppColors.primaryGradient,
                              onPressed: _isSaving ? null : _save,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Employee, Currency & Payday Row (100% full width)
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      borderRadius: BorderRadius.circular(16),
                      child: LayoutBuilder(
                        builder: (ctx, c) {
                          final empField = DropdownButtonFormField<String>(
                            initialValue: emps.any((e) => _empIdOf(e) == _selectedUserId) ? _selectedUserId : null,
                            isExpanded: true,
                            decoration: _fieldDecoration('Select Employee *', icon: Icons.person_outline_rounded),
                            items: emps
                                .map((e) => DropdownMenuItem<String>(
                                      value: _empIdOf(e),
                                      child: Text(_empNameOf(e), overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _selectedUserId = v);
                                _prefillFor(v, fallbackCurr);
                              }
                            },
                          );

                          final currField = DropdownButtonFormField<String>(
                            initialValue: ['INR', 'USD', 'AED', 'QAR', 'SAR', 'EUR', 'GBP'].contains(_currency)
                                ? _currency
                                : 'INR',
                            decoration: _fieldDecoration('Currency', icon: Icons.payments_outlined),
                            items: const [
                              DropdownMenuItem(value: 'INR', child: Text('INR (₹)')),
                              DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                              DropdownMenuItem(value: 'AED', child: Text('AED')),
                              DropdownMenuItem(value: 'QAR', child: Text('QAR')),
                              DropdownMenuItem(value: 'SAR', child: Text('SAR')),
                              DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                              DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _currency = v);
                            },
                          );

                          final paydayField = TextField(
                            controller: _salaryDayCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _fieldDecoration(
                              'Payday Override (1-31)',
                              hint: 'Default from Company Rules',
                              icon: Icons.event_outlined,
                            ),
                          );

                          if (c.maxWidth >= 780) {
                            return Row(
                              children: [
                                Expanded(flex: 5, child: empField),
                                const SizedBox(width: 14),
                                Expanded(flex: 2, child: currField),
                                const SizedBox(width: 14),
                                Expanded(flex: 3, child: paydayField),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              empField,
                              const SizedBox(height: 12),
                              currField,
                              const SizedBox(height: 12),
                              paydayField,
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Main 2-Column Workspace: Left (Forms) | Right (Executive Summary)
                    LayoutBuilder(
                      builder: (ctx, c) {
                        final leftColumn = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Monthly Earnings
                            GlassCard(
                              padding: const EdgeInsets.all(20),
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _sectionHeader(
                                          Icons.trending_up_rounded,
                                          'Monthly Earnings',
                                          'Base salary and fixed monthly allowances',
                                          const Color(0xFF059669),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: _openQuickSplitDialog,
                                        icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                                        label: const Text('Auto-Split'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _responsiveThreeFields(
                                    _numField(_basicCtrl, 'Basic Salary *'),
                                    _numField(_hraCtrl, 'HRA / Housing'),
                                    _numField(_allowCtrl, 'Other Allowances'),
                                    isMobile,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Fixed Statutory Deductions
                            GlassCard(
                              padding: const EdgeInsets.all(20),
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionHeader(
                                    Icons.account_balance_rounded,
                                    'Fixed Statutory Deductions',
                                    'Recurring monthly PF, insurance, and tax deductions',
                                    const Color(0xFFDC2626),
                                  ),
                                  const SizedBox(height: 16),
                                  _responsiveThreeFields(
                                    _numField(_pfCtrl, 'PF / Social Security'),
                                    _numField(_esiCtrl, 'ESI / Health Insurance'),
                                    _numField(_taxCtrl, 'Income Tax / TDS'),
                                    isMobile,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Payout Bank Details
                            GlassCard(
                              padding: const EdgeInsets.all(20),
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionHeader(
                                    Icons.credit_card_rounded,
                                    'Payout Bank Details',
                                    'Displayed on employee payslips for bank transfers',
                                    const Color(0xFF1E3A8A),
                                  ),
                                  const SizedBox(height: 16),
                                  _responsiveThreeFields(
                                    TextField(
                                      controller: _bankNameCtrl,
                                      decoration: _fieldDecoration('Bank Name', icon: Icons.account_balance_outlined),
                                    ),
                                    TextField(
                                      controller: _accountNoCtrl,
                                      decoration: _fieldDecoration('Account Number', icon: Icons.numbers_rounded),
                                    ),
                                    TextField(
                                      controller: _ifscIbanCtrl,
                                      decoration: _fieldDecoration('IFSC / IBAN / SWIFT', icon: Icons.code_rounded),
                                    ),
                                    isMobile,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );

                        final rightSummary = GlassCard(
                          padding: const EdgeInsets.all(20),
                          borderRadius: BorderRadius.circular(16),
                          borderColor: const Color(0xFFCBD5E1),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Live Compensation Summary',
                                style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Real-time monthly & annual package preview',
                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF047857), Color(0xFF059669)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ESTIMATED BASE NET PAY / MONTH',
                                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85), letterSpacing: 0.5),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '$_currency ${estNet.toStringAsFixed(2)}',
                                      style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: netRatio,
                                        minHeight: 6,
                                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _summaryRow('Monthly Gross Earnings', '$_currency ${gross.toStringAsFixed(2)}', const Color(0xFF047857)),
                              const Divider(height: 20),
                              _summaryRow('Fixed Statutory Deductions', '- $_currency ${fixedDed.toStringAsFixed(2)}', const Color(0xFFB91C1C)),
                              const Divider(height: 20),
                              _summaryRow('Annual Gross CTC (12 mo)', '$_currency ${(gross * 12).toStringAsFixed(2)}', const Color(0xFF1E3A8A), isLarge: true),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.info_outline_rounded, size: 17, color: Color(0xFF475569)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Loss of Pay (LOP), overtime, paid/unpaid leave, holidays, and late salary cuts are automatically calculated during each Monthly Payroll Run.',
                                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF475569), height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );

                        if (c.maxWidth >= 900) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: leftColumn),
                              const SizedBox(width: 18),
                              Expanded(flex: 5, child: rightSummary),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            leftColumn,
                            const SizedBox(height: 16),
                            rightSummary,
                          ],
                        );
                      },
                    ),
                    if (isMobile) ...[
                      const SizedBox(height: 18),
                      GradientPrimaryButton(
                        text: _isSaving ? 'Saving...' : 'Save Salary Structure',
                        icon: Icons.check_circle_outline_rounded,
                        height: 46,
                        gradient: AppColors.primaryGradient,
                        onPressed: _isSaving ? null : _save,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
  }

  Widget _responsiveThreeFields(Widget a, Widget b, Widget c, bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          a,
          const SizedBox(height: 12),
          b,
          const SizedBox(height: 12),
          c,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
        const SizedBox(width: 12),
        Expanded(child: c),
      ],
    );
  }

  Widget _numField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _fieldDecoration(label, prefixText: '$_currency '),
    );
  }

  Widget _summaryRow(String label, String value, Color color, {bool isLarge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: isLarge ? 13 : 12.5, fontWeight: isLarge ? FontWeight.w700 : FontWeight.w500, color: const Color(0xFF334155))),
        Text(value, style: GoogleFonts.inter(fontSize: isLarge ? 15 : 13.5, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}
