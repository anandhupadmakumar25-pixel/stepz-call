import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../models/lead_model.dart';
import '../../providers/lead_provider.dart';

class EditLeadDialog extends StatefulWidget {
  final LeadModel lead;

  const EditLeadDialog({super.key, required this.lead});

  @override
  State<EditLeadDialog> createState() => _EditLeadDialogState();
}

class _EditLeadDialogState extends State<EditLeadDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _notesController;

  late String _selectedStatus;
  String? _selectedCategory;
  bool _isSaving = false;

  final List<Map<String, String>> _statusOptions = [
    {'value': 'UNASSIGNED', 'label': 'Unassigned'},
    {'value': 'ASSIGNED', 'label': 'Assigned'},
    {'value': 'CALL_IN_PROGRESS', 'label': 'Call in Progress'},
    {'value': 'CONNECTED', 'label': 'Connected'},
    {'value': 'NOT_CONNECTED', 'label': 'Not Connected'},
    {'value': 'CALLBACK_REQUESTED', 'label': 'Callback Requested'},
    {'value': 'INTERESTED', 'label': '⭐ Interested'},
    {'value': 'NOT_INTERESTED', 'label': 'Not Interested'},
    {'value': 'CONVERTED', 'label': 'Converted / Won'},
    {'value': 'LOST', 'label': 'Lost'},
  ];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.lead.firstName);
    _lastNameController = TextEditingController(text: widget.lead.lastName);
    _phoneController = TextEditingController(text: widget.lead.phoneNumber);
    _emailController = TextEditingController(text: widget.lead.email);
    _cityController = TextEditingController(text: widget.lead.city);
    _stateController = TextEditingController(text: widget.lead.state);
    _notesController = TextEditingController(text: widget.lead.notes);

    _selectedStatus = widget.lead.status;
    _selectedCategory = widget.lead.categoryId;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final provider = context.read<LeadProvider>();

    final payload = <String, dynamic>{
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'raw_phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'city': _cityController.text.trim(),
      'state': _stateController.text.trim(),
      'status': _selectedStatus,
      'notes': _notesController.text.trim(),
    };

    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      payload['category'] = _selectedCategory;
    }

    final updated = await provider.updateLead(widget.lead.id, payload);
    setState(() => _isSaving = false);

    if (mounted) {
      if (updated != null) {
        Navigator.of(context).pop(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lead updated successfully! ${_selectedStatus == 'INTERESTED' ? 'Customer marked Interested.' : ''}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to update lead'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<LeadProvider>().categories;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
        child: GlassCard(
          blur: 24,
          opacity: 0.98,
          borderRadius: BorderRadius.circular(20),
          borderColor: const Color(0xFFCBD5E1),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Edit Lead Details',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 16),

                // Form Scrollable Body
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Status Selector Banner
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _selectedStatus == 'INTERESTED'
                                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedStatus == 'INTERESTED'
                                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lead Disposition / Status',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedStatus,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: _statusOptions.map((opt) {
                                  return DropdownMenuItem<String>(
                                    value: opt['value'],
                                    child: Text(
                                      opt['label']!,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: opt['value'] == 'INTERESTED' ? FontWeight.w800 : FontWeight.w600,
                                        color: opt['value'] == 'INTERESTED' ? const Color(0xFF059669) : const Color(0xFF1E293B),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedStatus = val);
                                },
                              ),
                              if (_selectedStatus == 'INTERESTED') ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.info_outline, size: 14, color: Color(0xFF059669)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Marking as Interested enables fast Quotation generation and WhatsApp sharing.',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF059669)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Name Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                label: 'First Name *',
                                controller: _firstNameController,
                                icon: Icons.person_outline,
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                label: 'Last Name',
                                controller: _lastNameController,
                                icon: Icons.person_outline,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Contact Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                label: 'Phone Number *',
                                controller: _phoneController,
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                label: 'Email Address',
                                controller: _emailController,
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Location Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                label: 'City',
                                controller: _cityController,
                                icon: Icons.location_city_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                label: 'State / Region',
                                controller: _stateController,
                                icon: Icons.map_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Category Dropdown
                        if (categories.isNotEmpty) ...[
                          Text(
                            'Category / Tag',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String?>(
                            initialValue: _selectedCategory,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('-- No Category --')),
                              ...categories.map((c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Row(
                                      children: [
                                        Container(width: 10, height: 10, decoration: BoxDecoration(color: HexColor.fromHex(c.colorCode), shape: BoxShape.circle)),
                                        const SizedBox(width: 8),
                                        Text(c.name),
                                      ],
                                    ),
                                  )),
                            ],
                            onChanged: (val) => setState(() => _selectedCategory = val),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Notes Field
                        _buildTextField(
                          label: 'Notes & Customer Requirements',
                          controller: _notesController,
                          icon: Icons.notes_rounded,
                          maxLines: 4,
                          hint: 'Enter customer requirements, budget, call notes...',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 16),

                // Footer Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 12),
                    GradientPrimaryButton(
                      text: _isSaving ? 'Saving Changes...' : 'Save Lead Changes',
                      icon: Icons.check_circle_outline_rounded,
                      gradient: AppColors.primaryGradient,
                      onPressed: _isSaving ? null : _handleSave,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
            prefixIcon: maxLines == 1 ? Icon(icon, size: 18, color: const Color(0xFF64748B)) : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }
}

