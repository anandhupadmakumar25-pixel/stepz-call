import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/glass_text_field.dart';
import '../../core/widgets/app_back_button.dart';
import '../../routes/app_routes.dart';
import '../../providers/company_provider.dart';
import '../../models/plan_model.dart';

class PlanManagementScreen extends StatefulWidget {
  const PlanManagementScreen({super.key});

  @override
  State<PlanManagementScreen> createState() => _PlanManagementScreenState();
}

class _PlanManagementScreenState extends State<PlanManagementScreen> {
  final Map<String, String> _availableMenus = {
    'branches': 'Branches & Multi-Office',
    'employees': 'Telecaller Team & Staff',
    'attendance': 'Stepz Attendance & Geofencing',
    'leads': 'Lead Workspace & Import',
    'tasks': 'Calling Tasks & Allocation',
    'recordings': 'Audio Call Recordings',
    'callbacks': 'Priority Callbacks & Reminders',
    'call_history': 'Call Logs & History',
    'analytics': 'Analytics & Performance Reports',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().fetchPlans();
    });
  }

  void _showCreatePlanDialog() {
    final compProv = context.read<CompanyProvider>();
    final nameCtrl = TextEditingController();
    String selectedCurrency = 'INR';
    final priceMonthlyCtrl = TextEditingController(text: '999.00');
    final priceYearlyCtrl = TextEditingController(text: '11988.00');
    final maxUsersCtrl = TextEditingController(text: '10');
    final maxLeadsCtrl = TextEditingController(text: '15000');
    final descCtrl = TextEditingController();
    final Set<String> selectedMenus = {'leads', 'tasks', 'callbacks', 'call_history'};
    bool isSyncingPrices = false;
    final formKey = GlobalKey<FormState>();
    String? localError;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) {
        final isMobile = ResponsiveLayout.isMobile(ctx);
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final currSymbol = PlanModel.getSymbolForCurrency(selectedCurrency);

            return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 16 : 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: GlassCard(
                blur: 24,
                opacity: 0.95,
                borderRadius: BorderRadius.circular(24),
                padding: EdgeInsets.all(isMobile ? 16 : 26),
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Create Subscription Plan',
                                  style: GoogleFonts.inter(fontSize: isMobile ? 15 : 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                ),
                                Text(
                                  'Define pricing tiers, user limits, and allowed menu permissions',
                                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          DialogCloseButton(onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (localError != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  localError!,
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFB91C1C)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      GlassTextField(
                        label: 'Plan Name *',
                        hintText: 'e.g. Growth Pro',
                        controller: nameCtrl,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Plan Name is required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Currency Selector
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Currency *',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedCurrency,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                items: const [
                                  DropdownMenuItem(value: 'INR', child: Text('INR (₹) - Indian Rupee')),
                                  DropdownMenuItem(value: 'USD', child: Text('USD (\$) - US Dollar')),
                                  DropdownMenuItem(value: 'EUR', child: Text('EUR (€) - Euro')),
                                  DropdownMenuItem(value: 'GBP', child: Text('GBP (£) - British Pound')),
                                  DropdownMenuItem(value: 'AED', child: Text('AED (د.إ) - UAE Dirham')),
                                  DropdownMenuItem(value: 'QAR', child: Text('QAR (QR) - Qatari Riyal')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setDlgState(() {
                                      selectedCurrency = val;
                                      if (val == 'INR' && (priceMonthlyCtrl.text == '49.00' || priceMonthlyCtrl.text == '199.00' || priceMonthlyCtrl.text.isEmpty)) {
                                        priceMonthlyCtrl.text = '999.00';
                                        priceYearlyCtrl.text = '11988.00';
                                      } else if (val == 'USD' && (priceMonthlyCtrl.text == '999.00' || priceMonthlyCtrl.text == '199.00' || priceMonthlyCtrl.text.isEmpty)) {
                                        priceMonthlyCtrl.text = '49.00';
                                        priceYearlyCtrl.text = '588.00';
                                      } else if (val == 'QAR' && (priceMonthlyCtrl.text == '999.00' || priceMonthlyCtrl.text == '49.00' || priceMonthlyCtrl.text.isEmpty)) {
                                        priceMonthlyCtrl.text = '199.00';
                                        priceYearlyCtrl.text = '2388.00';
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: GlassTextField(
                              label: 'Monthly ($currSymbol)*',
                              hintText: selectedCurrency == 'INR' ? '999.00' : (selectedCurrency == 'QAR' ? '199.00' : '49.00'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              controller: priceMonthlyCtrl,
                              onChanged: (val) {
                                if (isSyncingPrices) return;
                                isSyncingPrices = true;
                                final trimmed = val.trim();
                                if (trimmed.isEmpty) {
                                  priceYearlyCtrl.text = '';
                                } else {
                                  final m = double.tryParse(trimmed);
                                  if (m != null) {
                                    final y = m * 12;
                                    priceYearlyCtrl.text = y % 1 == 0 ? y.toInt().toString() : y.toStringAsFixed(2);
                                  }
                                }
                                isSyncingPrices = false;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GlassTextField(
                              label: 'Yearly ($currSymbol)*',
                              hintText: selectedCurrency == 'INR' ? '11988.00' : (selectedCurrency == 'QAR' ? '2388.00' : '588.00'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              controller: priceYearlyCtrl,
                              onChanged: (val) {
                                if (isSyncingPrices) return;
                                isSyncingPrices = true;
                                final trimmed = val.trim();
                                if (trimmed.isEmpty) {
                                  priceMonthlyCtrl.text = '';
                                } else {
                                  final y = double.tryParse(trimmed);
                                  if (y != null && y > 0) {
                                    final m = y / 12;
                                    priceMonthlyCtrl.text = m % 1 == 0 ? m.toInt().toString() : m.toStringAsFixed(2);
                                  }
                                }
                                isSyncingPrices = false;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: GlassTextField(
                              label: 'User Limit',
                              hintText: '10',
                              keyboardType: TextInputType.number,
                              controller: maxUsersCtrl,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GlassTextField(
                              label: 'Max Leads',
                              hintText: '15000',
                              keyboardType: TextInputType.number,
                              controller: maxLeadsCtrl,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Allowed Menus Checkboxes
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Allowed Sidebar Modules',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => setDlgState(() => selectedMenus.addAll(_availableMenus.keys)),
                                child: Text('Select All', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                              ),
                              TextButton(
                                onPressed: () => setDlgState(() => selectedMenus.clear()),
                                child: Text('Clear', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626))),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: _availableMenus.entries.map((entry) {
                            final isChecked = selectedMenus.contains(entry.key);
                            return CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(entry.value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                              subtitle: Text('module key: ${entry.key}', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                              value: isChecked,
                              activeColor: const Color(0xFF047857),
                              onChanged: (val) {
                                setDlgState(() {
                                  if (val == true) {
                                    selectedMenus.add(entry.key);
                                  } else {
                                    selectedMenus.remove(entry.key);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      GlassTextField(
                        label: 'Plan Description',
                        hintText: 'Brief summary of features for this tier...',
                        controller: descCtrl,
                        maxLines: 2,
                      ),

                      // Footer
                      Container(
                        margin: const EdgeInsets.only(top: 20),
                        padding: const EdgeInsets.only(top: 14),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Color(0x33D4AF37), width: 1.0)),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            GlassSecondaryButton(text: 'Cancel', onPressed: () => Navigator.pop(ctx)),
                            GradientPrimaryButton(
                              text: 'Create Plan',
                              icon: Icons.check_circle_rounded,
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) {
                                  setDlgState(() => localError = 'Please fix the highlighted errors before submitting.');
                                  return;
                                }

                                final name = nameCtrl.text.trim();
                                final existingCodes = compProv.plans.map((p) => p.code.toLowerCase()).toSet();
                                final baseSlug = name
                                    .toLowerCase()
                                    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                                    .replaceAll(RegExp(r'^_+|_+$'), '');
                                String code = baseSlug.isEmpty
                                    ? 'plan_${DateTime.now().millisecondsSinceEpoch}'
                                    : baseSlug;
                                if (code.length > 44) code = code.substring(0, 44);
                                if (existingCodes.contains(code)) {
                                  int suffix = 2;
                                  while (existingCodes.contains('${code}_$suffix')) {
                                    suffix++;
                                  }
                                  code = '${code}_$suffix';
                                }

                                setDlgState(() => localError = null);
                                final messenger = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(ctx);
                                final success = await context.read<CompanyProvider>().createPlan({
                                  'name': name,
                                  'code': code,
                                  'currency': selectedCurrency,
                                  'price_monthly': double.tryParse(priceMonthlyCtrl.text) ?? 0.0,
                                  'price_yearly': double.tryParse(priceYearlyCtrl.text) ?? 0.0,
                                  'max_users': int.tryParse(maxUsersCtrl.text) ?? 5,
                                  'max_leads': int.tryParse(maxLeadsCtrl.text) ?? 5000,
                                  'allowed_menus': selectedMenus.toList(),
                                  'description': descCtrl.text.trim(),
                                });
                                if (success && mounted) {
                                  nav.pop();
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Plan "$name" created successfully!'), backgroundColor: AppColors.success),
                                  );
                                } else if (mounted) {
                                  setDlgState(() {
                                    localError = context.read<CompanyProvider>().errorMessage ?? 'Failed to create plan. Please try again.';
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final compProv = context.watch<CompanyProvider>();
    final plans = compProv.plans;
    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 12 : 24,
            isMobile ? 6 : 16,
            isMobile ? 12 : 24,
            isMobile ? 10 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Back Button
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppBackButton(fallbackRoute: AppRoutes.dashboard),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Subscription Plans & Tiers',
                                  style: GoogleFonts.inter(
                                    fontSize: isMobile ? 18 : 24,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFD4AF37)),
                                  ),
                                  child: Text(
                                    '${plans.length} Tiers',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage SaaS billing plans, limits, and permitted modules for companies',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  GradientPrimaryButton(
                    text: 'Create Plan',
                    icon: Icons.add_rounded,
                    onPressed: _showCreatePlanDialog,
                    height: isMobile ? 36 : 38,
                    borderRadius: 10,
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Plans ExpansionTile List
              Expanded(
                child: plans.isEmpty
                    ? Center(
                        child: GlassCard(
                          padding: const EdgeInsets.all(32),
                          opacity: 0.90,
                          child: Text(
                            'No subscription plans created yet.',
                            style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: plans.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) => _buildPlanCard(plans[i], isMobile: isMobile),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(dynamic p, {required bool isMobile}) {
    final isEnterprise = p.code.toLowerCase().contains('enterprise');
    final isGrowth = p.code.toLowerCase().contains('growth') || p.code.toLowerCase().contains('pro');

    final accentColor = isEnterprise
        ? const Color(0xFF92400E)
        : (isGrowth ? const Color(0xFF047857) : const Color(0xFF1D4ED8));
    final badgeBg = isEnterprise
        ? const Color(0xFFFEF3C7)
        : (isGrowth ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF));
    final badgeBorder = isEnterprise
        ? const Color(0xFFD4AF37)
        : (isGrowth ? const Color(0xFF10B981) : const Color(0xFF3B82F6));

    final modulesWrap = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: p.allowedMenus.map<Widget>((key) {
        final label = _availableMenus[key] ?? key;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
          ),
        );
      }).toList(),
    );

    return GlassCard(
      opacity: 0.96,
      borderRadius: BorderRadius.circular(14),
      padding: EdgeInsets.zero,
      borderColor: isEnterprise ? const Color(0xFFD4AF37) : const Color(0xFFE2E8F0),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 4),
          childrenPadding: EdgeInsets.fromLTRB(isMobile ? 12 : 16, 0, isMobile ? 12 : 16, 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: badgeBorder.withValues(alpha: 0.5)),
            ),
            child: Icon(Icons.workspace_premium_rounded, size: 19, color: accentColor),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  p.name,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  p.code.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: accentColor),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${p.currencySymbol}${p.priceMonthly.toStringAsFixed(0)}/mo',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: const Color(0xFF047857)),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${p.currencySymbol}${p.priceYearly.toStringAsFixed(0)}/yr · Up to ${p.maxUsers} Users · ${p.maxLeads} Leads · ${p.companyCount} Tenants',
              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          children: [
            const Divider(color: Color(0xFFE2E8F0), height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(Icons.payments_outlined, 'Monthly: ${p.currencySymbol}${p.priceMonthly.toStringAsFixed(0)}', const Color(0xFF047857), const Color(0xFFECFDF5)),
                _buildInfoChip(Icons.calendar_today_outlined, 'Yearly: ${p.currencySymbol}${p.priceYearly.toStringAsFixed(0)}', const Color(0xFF4338CA), const Color(0xFFEEF2FF)),
                _buildInfoChip(Icons.people_outline_rounded, 'Up to ${p.maxUsers} Users', const Color(0xFF0284C7), const Color(0xFFF0F9FF)),
                _buildInfoChip(Icons.storage_rounded, 'Up to ${p.maxLeads} Leads', const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
                _buildInfoChip(Icons.apartment_rounded, '${p.companyCount} Active Tenants', const Color(0xFFD97706), const Color(0xFFFFFBEB)),
              ],
            ),
            if (p.description != null && p.description.toString().trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  p.description.toString(),
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Permitted Modules (${p.allowedMenus.length})',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerLeft, child: modulesWrap),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.5, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
