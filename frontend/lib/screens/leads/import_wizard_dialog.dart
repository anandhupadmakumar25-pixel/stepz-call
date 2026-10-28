import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
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
        ),
      );
    }
  }

  Future<void> _confirmImport() async {
    if (_batchPreview == null) return;
    final provider = context.read<LeadProvider>();
    final success = await provider.confirmImport(_batchPreview!.id);

    if (success && mounted) {
      setState(() {
        _currentStep = 2;
        _importSuccessMessage = 'Import completed successfully! Valid leads have been added to your company lead pool.';
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Import confirmation failed.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadProvider = context.watch<LeadProvider>();

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(28),
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
                          color: AppColors.accentVioletLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.file_upload_outlined, color: AppColors.accentViolet, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Import Leads Wizard', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                          Text('Support for .xlsx and .csv files with permanent number verification', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 28),

              // Content according to current step
              Expanded(
                child: _buildStepContent(leadProvider),
              ),

              const Divider(height: 28),
              // Bottom Action Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0 && _currentStep < 2)
                    OutlinedButton(
                      onPressed: () => setState(() => _currentStep = 0),
                      child: const Text('Back to File Selection'),
                    )
                  else
                    const SizedBox(),
                  if (_currentStep == 0)
                    ElevatedButton.icon(
                      onPressed: leadProvider.isImporting ? null : _pickFile,
                      icon: leadProvider.isImporting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.folder_open, size: 18),
                      label: Text(leadProvider.isImporting ? 'Processing File...' : 'Select .XLSX / .CSV File'),
                    )
                  else if (_currentStep == 1)
                    ElevatedButton.icon(
                      onPressed: leadProvider.isImporting ? null : _confirmImport,
                      icon: leadProvider.isImporting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check, size: 18),
                      label: Text('Confirm & Import (${_batchPreview?.validNewCount ?? 0} Leads)'),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(LeadProvider leadProvider) {
    if (_currentStep == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.accentViolet),
            ),
            const SizedBox(height: 20),
            Text('Upload Lead Spreadsheet', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              'Supports columns: Name, Phone (with or without +91), Email, City, State.\nStrict deduplication and permanent phone registry validation are applied automatically.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (leadProvider.isImporting)
              const CircularProgressIndicator()
            else
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Browse Computer'),
              ),
          ],
        ),
      );
    } else if (_currentStep == 1 && _batchPreview != null) {
      final b = _batchPreview!;
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Validation & Inspection Summary', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            // Summary Badges / Metrics
            Row(
              children: [
                _buildMetricBox('Total Rows', '${b.totalRows}', AppColors.textPrimary),
                const SizedBox(width: 10),
                _buildMetricBox('Valid New', '${b.validNewCount}', AppColors.success),
                const SizedBox(width: 10),
                _buildMetricBox('Blocked in Registry', '${b.permanentlyBlockedCount}', AppColors.danger),
                const SizedBox(width: 10),
                _buildMetricBox('Duplicate in File', '${b.duplicateInFileCount}', AppColors.warning),
                const SizedBox(width: 10),
                _buildMetricBox('Invalid Format', '${b.invalidRowsCount}', AppColors.danger),
              ],
            ),
            const SizedBox(height: 20),

            if (b.permanentlyBlockedCount > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security, color: AppColors.danger, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'CRITICAL INVARIANT ENFORCED: ${b.permanentlyBlockedCount} phone number(s) were previously assigned in your company and are permanently blocked from re-allocation.',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Text('Sample Staged Records for Import', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(2),
                  4: FlexColumnWidth(2),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: AppColors.surfaceSecondary),
                    children: [
                      _cell('Row', isHeader: true),
                      _cell('Name', isHeader: true),
                      _cell('Normalized Phone', isHeader: true),
                      _cell('City', isHeader: true),
                      _cell('Status', isHeader: true),
                    ],
                  ),
                  ...b.stagingData.take(5).map((row) {
                    return TableRow(
                      children: [
                        _cell('${row['row_number']}'),
                        _cell(row['name'] ?? ''),
                        _cell(row['normalized_phone'] ?? ''),
                        _cell(row['city'] ?? ''),
                        _cell('Valid', color: AppColors.success),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.success, size: 64),
            const SizedBox(height: 16),
            Text('Import Confirmed', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              _importSuccessMessage ?? 'Leads imported successfully.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildMetricBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _cell(String text, {bool isHeader = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
          color: color ?? (isHeader ? AppColors.textPrimary : AppColors.textSecondary),
        ),
      ),
    );
  }
}
