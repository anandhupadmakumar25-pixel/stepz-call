import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/lead_provider.dart';

class AddLeadDialog extends StatefulWidget {
  const AddLeadDialog({super.key});

  @override
  State<AddLeadDialog> createState() => _AddLeadDialogState();
}

class _AddLeadDialogState extends State<AddLeadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();

  String? _selectedBranchId;
  String? _selectedCategoryId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<LeadProvider>();
      p.fetchBranches().then((_) {
        if (mounted && p.branches.isNotEmpty && _selectedBranchId == null) {
          setState(() => _selectedBranchId = p.branches.first.id);
        }
      });
      p.fetchCategories().then((_) {
        if (mounted && p.categories.isNotEmpty && _selectedCategoryId == null) {
          setState(() => _selectedCategoryId = p.categories.first.id);
        }
      });
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _quickAddBranch() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quick Add Branch', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Branch Name', hintText: 'e.g. Branch X, Branch Y, Downtown'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final nav = Navigator.of(ctx);
              final ok = await context.read<LeadProvider>().createBranch(name: nameCtrl.text.trim());
              if (ok && mounted) {
                final last = context.read<LeadProvider>().branches.last;
                setState(() => _selectedBranchId = last.id);
                nav.pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _quickAddCategory() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quick Add Category', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Category Name', hintText: 'e.g. Academy, Client, Customer'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final nav = Navigator.of(ctx);
              final ok = await context.read<LeadProvider>().createCategory(name: nameCtrl.text.trim());
              if (ok && mounted) {
                final last = context.read<LeadProvider>().categories.last;
                setState(() => _selectedCategoryId = last.id);
                nav.pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final leadProvider = context.read<LeadProvider>();
    final success = await leadProvider.createLead({
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'raw_phone': _phoneController.text.trim(),
      'branch': _selectedBranchId,
      'category': _selectedCategoryId,
      'email': _emailController.text.trim(),
      'city': _cityController.text.trim(),
      'source': 'MANUAL',
    });

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lead created successfully and tagged to selected branch and category!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(leadProvider.errorMessage ?? 'Failed to create lead.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadProvider = context.watch<LeadProvider>();
    final branches = leadProvider.branches;
    final categories = leadProvider.categories;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                              color: AppColors.accentVioletLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.person_add_alt_1, color: AppColors.accentViolet, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Create New Lead', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                              Text('Fast, simplified lead entry with dynamic branch & category', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                  const Divider(height: 24),

                  // Customer Name Fields
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First Name *',
                            hintText: 'John',
                            prefixIcon: Icon(Icons.person_outline, size: 18),
                          ),
                          validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                            hintText: 'Doe',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Phone Number Field
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                      hintText: 'e.g. 9876543210 or +919876543210',
                      prefixIcon: Icon(Icons.phone_outlined, size: 18),
                      helperText: 'Auto-normalizes to E.164 and checks permanent registry',
                    ),
                    validator: (v) => v?.trim().isEmpty == true ? 'Phone number is required' : null,
                  ),
                  const SizedBox(height: 14),

                  // Dynamic Branch & Category Selectors
                  Row(
                    children: [
                      // Branch Dropdown
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Branch *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                InkWell(
                                  onTap: _quickAddBranch,
                                  child: Text('+ New', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accentViolet)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: branches.any((b) => b.id == _selectedBranchId) ? _selectedBranchId : (branches.isNotEmpty ? branches.first.id : null),
                              isExpanded: true,
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                              items: branches.map((b) {
                                return DropdownMenuItem(
                                  value: b.id,
                                  child: Text(b.name, style: GoogleFonts.inter(fontSize: 13), overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedBranchId = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Category Dropdown
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Category *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                InkWell(
                                  onTap: _quickAddCategory,
                                  child: Text('+ New', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accentViolet)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: categories.any((c) => c.id == _selectedCategoryId) ? _selectedCategoryId : (categories.isNotEmpty ? categories.first.id : null),
                              isExpanded: true,
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                              items: categories.map((c) {
                                return DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name, style: GoogleFonts.inter(fontSize: 13), overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedCategoryId = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Optional Email & City in a clean row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            hintText: 'john@example.com',
                            prefixIcon: Icon(Icons.email_outlined, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(
                            labelText: 'City / Location',
                            hintText: 'e.g. Mumbai, New York',
                            prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.accentViolet,
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check, size: 18),
                              const SizedBox(width: 8),
                              Text('Save Lead to Workspace', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
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
  }
}
