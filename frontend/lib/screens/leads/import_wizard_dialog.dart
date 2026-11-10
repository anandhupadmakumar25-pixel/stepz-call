import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/animated_status_badge.dart';
import '../../providers/lead_provider.dart';
import '../../models/lead_model.dart';

class ImportWizardDialog extends StatefulWidget {
  const ImportWizardDialog({super.key});

  @override
  State<ImportWizardDialog> createState() => _ImportWizardDialogState();
}

class _ImportWizardDialogState extends State<ImportWizardDialog> {
  int _currentStep = 0;
  PlatformFile? _selectedFile;
  ImportBatchModel? _batchPreview;
  String? _importSuccessMessage;
  String? _selectedBranchId;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<LeadProvider>();
      p.fetchBranches();
      p.fetchCategories();
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
      });
      _uploadAndPreview();
    }
  }

  Future<void> _uploadAndPreview() async {
    if (_selectedFile == null || _selectedFile!.bytes == null) return;

    final provider = context.read<LeadProvider>();
    final batch = await provider.uploadImportFile(
      _selectedFile!.bytes!,
      _selectedFile!.name,
    );

    if (batch != null && mounted) {
      setState(() {
        _batchPreview = batch;
        _currentStep = 1;
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Import preview failed.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmImport() async {
    if (_batchPreview == null) return;
    final provider = context.read<LeadProvider>();
    final success = await provider.confirmImport(
      _batchPreview!.id,
      branchId: _selectedBranchId,
      categoryId: _selectedCategoryId,
    );

    if (success && mounted) {
      setState(() {
        _currentStep = 2;
        _importSuccessMessage = 'Import completed! Leads are securely added and available in your company lead pool.';
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Import confirmation failed.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadProvider = context.watch<LeadProvider>();
    final isMobile = ResponsiveLayout.isMobile(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 24,
        vertical: isMobile ? 14 : 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: GlassCard(
          blur: 24,
          opacity: 0.98,
          borderRadius: BorderRadius.circular(20),
          borderColor: const Color(0xFFE2E8F0),
          padding: EdgeInsets.all(isMobile ? 18 : 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Import Leads Wizard',
                                style: GoogleFonts.inter(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Excel & CSV batch onboarding with permanent phone registry deduplication',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const DialogCloseButton(),
                ],
              ),
              const SizedBox(height: 16),

              // Step Progress Bar
              _buildStepIndicator(isMobile),
              const SizedBox(height: 16),

              // Step Body
              Expanded(
                child: _buildStepContent(leadProvider, isMobile),
              ),
              const SizedBox(height: 16),

              // Dedicated Luxury Contrast Footer Section with Golden Glass Lite Back/Cancel button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (_currentStep == 1)
                      GlassSecondaryButton(
                        text: 'Back to File Pick',
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => setState(() => _currentStep = 0),
                      )
                    else
                      GlassSecondaryButton(
                        text: 'Cancel',
                        icon: Icons.close_rounded,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    if (_currentStep == 0)
                      GradientPrimaryButton(
                        text: leadProvider.isImporting ? 'Processing File...' : 'Select File (.xlsx / .csv)',
                        icon: Icons.folder_open_rounded,
                        isLoading: leadProvider.isImporting,
                        onPressed: _pickFile,
                      )
                    else if (_currentStep == 1)
                      GradientPrimaryButton(
                        text: 'Confirm & Import Leads',
                        icon: Icons.check_circle_rounded,
                        isLoading: leadProvider.isImporting,
                        onPressed: _confirmImport,
                      )
                    else
                      GradientPrimaryButton(
                        text: 'Complete & Close',
                        icon: Icons.done_all_rounded,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(bool isMobile) {
    final steps = ['Select File', 'Review & Tag', 'Completed'];

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          final stepBefore = index ~/ 2;
          final isPassed = _currentStep > stepBefore;
          return Expanded(
            child: Container(
              height: 2,
              color: isPassed ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            ),
          );
        }

        final stepIndex = index ~/ 2;
        final isActive = _currentStep == stepIndex;
        final isPassed = _currentStep > stepIndex;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: (isActive || isPassed) ? AppColors.primaryGradient : null,
                color: (isActive || isPassed) ? null : const Color(0xFFF1F5F9),
                border: Border.all(
                  color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isPassed
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '${stepIndex + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: (isActive || isPassed) ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
              ),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 8),
              Text(
                steps[stepIndex],
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

  Widget _buildStepContent(LeadProvider leadProvider, bool isMobile) {
    if (_currentStep == 0) {
      return _buildFileSelectStep(leadProvider, isMobile);
    } else if (_currentStep == 1) {
      return _buildPreviewStep(leadProvider, isMobile);
    } else {
      return _buildSuccessStep();
    }
  }

  Widget _buildFileSelectStep(LeadProvider leadProvider, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Upload Dropzone
        Expanded(
          child: InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cloud_upload_rounded, size: 42, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedFile != null ? _selectedFile!.name : 'Click to Browse .CSV or .XLSX Spreadsheet',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Supports name, phone, city, branch, and category columns',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        textAlign: TextAlign.center,
                      ),
                      if (_selectedFile != null) ...[
                        const SizedBox(height: 12),
                        AnimatedStatusBadge(
                          label: '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB Ready',
                          statusColor: const Color(0xFF10B981),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Default Branch & Category assignment for batch
        Text(
          'Batch Auto-Tagging (Optional)',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        if (isMobile) ...[
          _buildDropdownTile(
            title: 'Default Branch',
            value: _selectedBranchId,
            items: leadProvider.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
            onChanged: (val) => setState(() => _selectedBranchId = val),
          ),
          const SizedBox(height: 10),
          _buildDropdownTile(
            title: 'Default Category',
            value: _selectedCategoryId,
            items: leadProvider.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (val) => setState(() => _selectedCategoryId = val),
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: _buildDropdownTile(
                  title: 'Default Branch',
                  value: _selectedBranchId,
                  items: leadProvider.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (val) => setState(() => _selectedBranchId = val),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildDropdownTile(
                  title: 'Default Category',
                  value: _selectedCategoryId,
                  items: leadProvider.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (val) => setState(() => _selectedCategoryId = val),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(title, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
          value: value,
          dropdownColor: Colors.white,
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildPreviewStep(LeadProvider leadProvider, bool isMobile) {
    if (_batchPreview == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Metrics Cards
        Row(
          children: [
            Expanded(
              child: _buildMetricMiniCard('Total Rows', '${_batchPreview!.totalRows}', const Color(0xFF2563EB)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricMiniCard('Valid Leads', '${_batchPreview!.validNewCount}', const Color(0xFF10B981)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricMiniCard('Blocked', '${_batchPreview!.permanentlyBlockedCount}', AppColors.danger),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Preview Table
        Text(
          'Sample Records (First ${_batchPreview!.stagingData.length} Leads)',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowHeight: 40,
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 52,
                    headingTextStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                    columns: const [
                      DataColumn(label: Text('NAME')),
                      DataColumn(label: Text('PHONE')),
                      DataColumn(label: Text('CITY')),
                      DataColumn(label: Text('STATUS / CHECK')),
                    ],
                    rows: _batchPreview!.stagingData.map((row) {
                      final name = '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'.trim();
                      final phone = row['phone'] ?? row['raw_phone'] ?? '';
                      final city = row['city'] ?? '—';
                      final isValid = row['is_valid'] != false;

                      return DataRow(
                        cells: [
                          DataCell(Text(name.isNotEmpty ? name : 'Lead', style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.w600))),
                          DataCell(Text(phone, style: GoogleFonts.robotoMono(color: const Color(0xFF2563EB), fontWeight: FontWeight.w600))),
                          DataCell(Text(city, style: GoogleFonts.inter(color: const Color(0xFF64748B)))),
                          DataCell(
                            AnimatedStatusBadge(
                              label: isValid ? 'Eligible' : 'Blocked / Duplicate',
                              statusColor: isValid ? const Color(0xFF10B981) : AppColors.danger,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricMiniCard(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(val, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildSuccessStep() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Icon(Icons.verified_rounded, size: 54, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              'Batch Import Succeeded!',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _importSuccessMessage ?? 'All validated records have been added to your CRM directory.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
