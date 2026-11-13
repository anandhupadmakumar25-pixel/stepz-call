import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/company_model.dart';
import '../../models/company_renewal_request_model.dart';
import '../../providers/company_provider.dart';

/// Modal dialog for tenants or super admins to submit a renewal request
class SubmitRenewalRequestDialog extends StatefulWidget {
  final CompanyModel? company;

  const SubmitRenewalRequestDialog({
    super.key,
    this.company,
  });

  static Future<bool?> show(BuildContext context, {CompanyModel? company}) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.70),
      builder: (_) => SubmitRenewalRequestDialog(company: company),
    );
  }

  @override
  State<SubmitRenewalRequestDialog> createState() => _SubmitRenewalRequestDialogState();
}

class _SubmitRenewalRequestDialogState extends State<SubmitRenewalRequestDialog> {
  String _selectedCycle = 'MONTHLY';
  int _requestedDays = 30;
  DateTime? _requestedTargetDate;
  String? _selectedPlanId;
  final TextEditingController _daysController = TextEditingController(text: '30');
  final TextEditingController _paymentRefController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedPlanId = widget.company?.planId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<CompanyProvider>();
      if (prov.plans.isEmpty) {
        prov.fetchPlans();
      }
    });
  }

  @override
  void dispose() {
    _daysController.dispose();
    _paymentRefController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _requestedTargetDate = picked;
        _selectedCycle = 'CUSTOM_DATE';
      });
    }
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final compProvider = context.read<CompanyProvider>();
    int days = _requestedDays;
    if (_selectedCycle == 'DAYS') {
      days = int.tryParse(_daysController.text.trim()) ?? 30;
    } else if (_selectedCycle == 'MONTHLY') {
      days = 30;
    } else if (_selectedCycle == 'YEARLY') {
      days = 365;
    }

    final success = await compProvider.createRenewalRequest(
      companyId: widget.company?.id,
      billingCycle: _selectedCycle,
      requestedDays: days,
      requestedDate: _selectedCycle == 'CUSTOM_DATE' && _requestedTargetDate != null
          ? _requestedTargetDate!.toIso8601String()
          : null,
      paymentReference: _paymentRefController.text.trim(),
      notes: _notesController.text.trim(),
      planId: _selectedPlanId,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Renewal request submitted successfully! Your Super Admin has been notified.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _errorMessage = compProvider.errorMessage ?? 'Failed to submit renewal request. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final compProvider = context.watch<CompanyProvider>();
    final plans = compProvider.plans;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.autorenew_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Request Plan Renewal',
                              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.company != null
                                  ? 'For ${widget.company!.name} • Assigned Super Admin will review'
                                  : 'Notify Super Admin to renew your tenant subscription',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFDC2626), fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Cycle selector
                      Text(
                        'Select Billing Cycle / Duration',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildCycleChip('MONTHLY', 'Monthly (30 Days)', Icons.calendar_view_month_rounded),
                          _buildCycleChip('YEARLY', 'Yearly (365 Days)', Icons.verified_rounded),
                          _buildCycleChip('DAYS', 'Custom Days', Icons.timeline_rounded),
                          _buildCycleChip('CUSTOM_DATE', 'Pick Specific Date', Icons.event_rounded),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Custom days input
                      if (_selectedCycle == 'DAYS') ...[
                        Text(
                          'Number of Extension Days',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _daysController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'e.g. 45, 60, 90',
                            suffixText: 'Days',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (val) {
                            final parsed = int.tryParse(val.trim());
                            if (parsed != null && parsed > 0) {
                              setState(() => _requestedDays = parsed);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Custom date target
                      if (_selectedCycle == 'CUSTOM_DATE') ...[
                        Text(
                          'Target Expiry Date',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickTargetDate,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(10),
                              color: const Color(0xFFF8FAFC),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0F766E)),
                                const SizedBox(width: 10),
                                Text(
                                  _requestedTargetDate != null
                                      ? '${_requestedTargetDate!.day.toString().padLeft(2, '0')}/${_requestedTargetDate!.month.toString().padLeft(2, '0')}/${_requestedTargetDate!.year}'
                                      : 'Click to select target expiry date',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _requestedTargetDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Optional Plan Selection
                      if (plans.isNotEmpty) ...[
                        Text(
                          'Requested Subscription Plan (Optional)',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: plans.any((p) => p.id.toString() == _selectedPlanId)
                                  ? _selectedPlanId
                                  : null,
                              hint: Text('Select Plan (or keep current)', style: GoogleFonts.inter(fontSize: 13)),
                              items: plans.map((p) {
                                return DropdownMenuItem<String>(
                                  value: p.id.toString(),
                                  child: Text('${p.name} (${p.currencySymbol}${p.priceMonthly.toInt()}/mo • ${p.currencySymbol}${p.priceYearly.toInt()}/yr)'),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedPlanId = val),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Payment Reference
                      Text(
                        'Payment / Transaction Reference (Optional)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _paymentRefController,
                        decoration: InputDecoration(
                          hintText: 'e.g. UTR / NEFT reference or invoice number',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Notes
                      Text(
                        'Remarks / Message for Super Admin',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Any special requests or instructions for the administrator...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: _isSubmitting
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.send_rounded, size: 16),
                            label: Text(_isSubmitting ? 'Submitting...' : 'Submit Request', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                            onPressed: _isSubmitting ? null : _handleSubmit,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCycleChip(String key, String label, IconData icon) {
    final isSelected = _selectedCycle == key;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCycle = key;
          if (key == 'CUSTOM_DATE' && _requestedTargetDate == null) {
            _pickTargetDate();
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFCCFBF1) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal dialog for Super Admin to review, customize days, calculate from zero, and approve a request
class ApproveRenewalRequestDialog extends StatefulWidget {
  final CompanyRenewalRequestModel request;

  const ApproveRenewalRequestDialog({
    super.key,
    required this.request,
  });

  static Future<bool?> show(BuildContext context, {required CompanyRenewalRequestModel request}) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.70),
      builder: (_) => ApproveRenewalRequestDialog(request: request),
    );
  }

  @override
  State<ApproveRenewalRequestDialog> createState() => _ApproveRenewalRequestDialogState();
}

class _ApproveRenewalRequestDialogState extends State<ApproveRenewalRequestDialog> {
  late String _selectedCycle;
  late int _extensionDays;
  DateTime? _targetExpiryDate;
  final TextEditingController _daysController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(text: '0');
  final TextEditingController _adminNotesController = TextEditingController();
  bool _isApproving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedCycle = widget.request.billingCycle;
    _extensionDays = widget.request.requestedDays > 0 ? widget.request.requestedDays : 30;
    _daysController.text = _extensionDays.toString();
    if (widget.request.requestedDate != null) {
      _targetExpiryDate = DateTime.tryParse(widget.request.requestedDate!);
    }
  }

  @override
  void dispose() {
    _daysController.dispose();
    _amountController.dispose();
    _adminNotesController.dispose();
    super.dispose();
  }

  DateTime _calculatePreviewExpiry() {
    final now = DateTime.now();
    DateTime baseDate;

    // Zero-calculation rule:
    // If company is already expired or has no expiry date, start from ZERO (now).
    // Otherwise extend from current expiry date.
    if (widget.request.isCompanyExpired || widget.request.currentExpiry == null) {
      baseDate = now;
    } else {
      final cur = DateTime.tryParse(widget.request.currentExpiry!);
      baseDate = (cur != null && cur.isAfter(now)) ? cur : now;
    }

    if (_selectedCycle == 'CUSTOM_DATE' && _targetExpiryDate != null) {
      return _targetExpiryDate!;
    } else if (_selectedCycle == 'YEARLY') {
      return baseDate.add(const Duration(days: 365));
    } else if (_selectedCycle == 'MONTHLY') {
      return baseDate.add(const Duration(days: 30));
    } else {
      return baseDate.add(Duration(days: _extensionDays));
    }
  }

  Future<void> _handleApprove() async {
    setState(() {
      _isApproving = true;
      _errorMessage = null;
    });

    final compProvider = context.read<CompanyProvider>();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    final success = await compProvider.approveRenewalRequest(
      widget.request.id,
      billingCycle: _selectedCycle,
      extensionDays: _extensionDays,
      targetExpiryDate: _selectedCycle == 'CUSTOM_DATE' && _targetExpiryDate != null
          ? _targetExpiryDate!.toIso8601String()
          : null,
      amountPaid: amount,
      adminNotes: _adminNotesController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isApproving = false);

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Renewal approved successfully! Company is active with updated plan validity.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _errorMessage = compProvider.errorMessage ?? 'Failed to approve request. Please check permissions.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewExpiry = _calculatePreviewExpiry();
    final isExpired = widget.request.isCompanyExpired;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF047857), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.verified_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Approve Tenant Renewal',
                              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Review details & apply zero-day calculation for ${widget.request.companyName}',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFDC2626), fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Tenant info summary card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  widget.request.companyName,
                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isExpired ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isExpired ? const Color(0xFFFCA5A5) : const Color(0xFFA7F3D0)),
                                  ),
                                  child: Text(
                                    isExpired ? 'Status: Expired' : 'Status: Active (${widget.request.daysUntilExpiry ?? 0}d left)',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isExpired ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Requester: ${widget.request.requestedByName} (${widget.request.requestedByEmail})',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                            if (widget.request.paymentReference.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Payment Ref: ${widget.request.paymentReference}',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F766E)),
                              ),
                            ],
                            if (widget.request.notes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Notes: ${widget.request.notes}',
                                style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: const Color(0xFF475569)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Zero-day Calculation Highlight Box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.calculate_outlined, color: Color(0xFF16A34A), size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isExpired
                                        ? '⚡ Zero-Day Calculation Applied'
                                        : '⏱️ Extension Added to Current Expiry',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF166534)),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    isExpired
                                        ? 'Tenant plan is currently expired. Renewal starts fresh from today (zero), giving a full valid duration.'
                                        : 'Tenant is currently active. Extension days will be added on top of existing expiry date.',
                                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF15803D)),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF86EFAC)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                                        const SizedBox(width: 6),
                                        Text(
                                          'New Expiry Date: ${previewExpiry.day.toString().padLeft(2, '0')} ${_monthName(previewExpiry.month)} ${previewExpiry.year}',
                                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: const Color(0xFF14532D)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Cycle choices
                      Text(
                        'Approval Billing Cycle',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildCycleChip('MONTHLY', 'Monthly (+30d)'),
                          _buildCycleChip('YEARLY', 'Yearly (+365d)'),
                          _buildCycleChip('DAYS', 'Custom Days'),
                          _buildCycleChip('CUSTOM_DATE', 'Target Date'),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (_selectedCycle == 'DAYS') ...[
                        Text(
                          'Extension Days',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _daysController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            suffixText: 'Days',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (val) {
                            final parsed = int.tryParse(val.trim());
                            if (parsed != null && parsed > 0) {
                              setState(() => _extensionDays = parsed);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Admin Notes
                      Text(
                        'Admin Approval Remarks (Logged to History)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _adminNotesController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Approved via bank transfer / Verified by Super Admin',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _isApproving ? null : () => Navigator.of(context).pop(),
                            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: _isApproving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.check_circle_rounded, size: 16),
                            label: Text(_isApproving ? 'Approving...' : 'Confirm Approval', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                            onPressed: _isApproving ? null : _handleApprove,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCycleChip(String key, String label) {
    final isSelected = _selectedCycle == key;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCycle = key;
          if (key == 'MONTHLY') _extensionDays = 30;
          if (key == 'YEARLY') _extensionDays = 365;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF15803D) : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  static String _monthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (m >= 1 && m <= 12) return months[m - 1];
    return '';
  }
}

/// Modal dialog specifically for locked-out / expired tenant companies on the login screen
class TenantLockoutRenewalDialog extends StatefulWidget {
  final String companyName;
  final String? companyId;
  final String userEmail;
  final String superAdminName;
  final String? expiredAt;

  const TenantLockoutRenewalDialog({
    super.key,
    required this.companyName,
    this.companyId,
    required this.userEmail,
    required this.superAdminName,
    this.expiredAt,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String companyName,
    String? companyId,
    required String userEmail,
    required String superAdminName,
    String? expiredAt,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => TenantLockoutRenewalDialog(
        companyName: companyName,
        companyId: companyId,
        userEmail: userEmail,
        superAdminName: superAdminName,
        expiredAt: expiredAt,
      ),
    );
  }

  @override
  State<TenantLockoutRenewalDialog> createState() => _TenantLockoutRenewalDialogState();
}

class _TenantLockoutRenewalDialogState extends State<TenantLockoutRenewalDialog> {
  String _selectedCycle = 'MONTHLY';
  int _requestedDays = 30;
  DateTime? _requestedTargetDate;
  final TextEditingController _daysController = TextEditingController(text: '30');
  final TextEditingController _paymentRefController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void dispose() {
    _daysController.dispose();
    _paymentRefController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _requestedTargetDate = picked;
        _selectedCycle = 'CUSTOM_DATE';
      });
    }
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    int days = _requestedDays;
    if (_selectedCycle == 'DAYS') {
      days = int.tryParse(_daysController.text.trim()) ?? 30;
    } else if (_selectedCycle == 'MONTHLY') {
      days = 30;
    } else if (_selectedCycle == 'YEARLY') {
      days = 365;
    }

    final compProvider = context.read<CompanyProvider>();
    final result = await compProvider.submitPublicRenewalRequest(
      email: widget.userEmail,
      companyId: widget.companyId,
      billingCycle: _selectedCycle,
      requestedDays: days,
      requestedDate: _selectedCycle == 'CUSTOM_DATE' && _requestedTargetDate != null
          ? _requestedTargetDate!.toIso8601String()
          : null,
      paymentReference: _paymentRefController.text.trim(),
      notes: _notesController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      setState(() => _isSuccess = true);
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Failed to submit request. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'Renewal Request Submitted!',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Your Super Admin (${widget.superAdminName}) has been notified. Once approved, your organization subscription will be reactivated automatically starting fresh from zero.',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), height: 1.45),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Done & Return to Login', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.autorenew_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Request Account Reactivation',
                              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Submit a plan renewal request directly to your Super Admin',
                              style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFDC2626), fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Organization info box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.domain_rounded, size: 16, color: Color(0xFF475569)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.companyName,
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Admin Email: ${widget.userEmail}',
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Super Admin: ${widget.superAdminName}',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF4338CA)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Cycle selector
                      Text(
                        'Select Desired Plan Duration',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildCycleChip('MONTHLY', 'Monthly (30 Days)', Icons.calendar_view_month_rounded),
                          _buildCycleChip('YEARLY', 'Yearly (365 Days)', Icons.verified_rounded),
                          _buildCycleChip('DAYS', 'Custom Days', Icons.timeline_rounded),
                          _buildCycleChip('CUSTOM_DATE', 'Specific Date', Icons.event_rounded),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (_selectedCycle == 'DAYS') ...[
                        Text(
                          'Number of Extension Days',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _daysController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            suffixText: 'Days',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (val) {
                            final parsed = int.tryParse(val.trim());
                            if (parsed != null && parsed > 0) {
                              setState(() => _requestedDays = parsed);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      if (_selectedCycle == 'CUSTOM_DATE') ...[
                        Text(
                          'Target Expiry Date',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickTargetDate,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(10),
                              color: const Color(0xFFF8FAFC),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0F766E)),
                                const SizedBox(width: 10),
                                Text(
                                  _requestedTargetDate != null
                                      ? '${_requestedTargetDate!.day.toString().padLeft(2, '0')}/${_requestedTargetDate!.month.toString().padLeft(2, '0')}/${_requestedTargetDate!.year}'
                                      : 'Click to select date',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Payment Reference
                      Text(
                        'Payment / Transfer Reference (UTR / Receipt #)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _paymentRefController,
                        decoration: InputDecoration(
                          hintText: 'e.g. UTR / NEFT / IMPS reference or cheque number',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Notes
                      Text(
                        'Message for Super Admin',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Payment completed via bank transfer. Please restore our workspace access...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: _isSubmitting
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.send_rounded, size: 16),
                            label: Text(_isSubmitting ? 'Submitting...' : 'Submit Request', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                            onPressed: _isSubmitting ? null : _handleSubmit,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCycleChip(String key, String label, IconData icon) {
    final isSelected = _selectedCycle == key;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCycle = key;
          if (key == 'CUSTOM_DATE' && _requestedTargetDate == null) {
            _pickTargetDate();
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFCCFBF1) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
