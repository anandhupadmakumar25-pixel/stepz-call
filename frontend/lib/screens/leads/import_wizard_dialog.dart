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
          padding: const EdgeInsets.all(22),
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accentVioletLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.file_upload_outlined, color: AppColors.accentViolet, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Import Leads Wizard', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('Support for .xlsx and .csv files with permanent registry check', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Content according to current step
              Expanded(
                child: _buildStepContent(leadProvider),
              ),

              const Divider(height: 20),
              // Bottom Action Controls
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
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
                          : const Icon(Icons.folder_open, size: 16),
                      label: Text(leadProvider.isImporting ? 'Processing File...' : 'Select .XLSX / .CSV File'),
                    )
                  else if (_currentStep == 1)
                    ElevatedButton.icon(
                      onPressed: leadProvider.isImporting ? null : _confirmImport,
                      icon: leadProvider.isImporting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check, size: 16),
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_upload_outlined, size: 44, color: AppColors.accentViolet),
              ),
              const SizedBox(height: 16),
              Text('Upload Lead Spreadsheet', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Supports columns: Name, Phone (with or without country code), Email, City, State.\nStrict deduplication and permanent registry validation are applied automatically.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
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
        ),
      );
    } else if (_currentStep == 1 && _batchPreview != null) {
      final b = _batchPreview!;
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Validation & Inspection Summary', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),

            // Summary Badges in Wrap to prevent overflow
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetricBox('Total Rows', '${b.totalRows}', AppColors.textPrimary),
                _buildMetricBox('Valid New', '${b.validNewCount}', AppColors.success),
                _buildMetricBox('Blocked in Registry', '${b.permanentlyBlockedCount}', AppColors.danger),
                _buildMetricBox('Duplicate in File', '${b.duplicateInFileCount}', AppColors.warning),
                _buildMetricBox('Invalid Format', '${b.invalidRowsCount}', AppColors.danger),
              ],
            ),
            const SizedBox(height: 16),

            if (b.permanentlyBlockedCount > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security, color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PERMANENT INVARIANT: ${b.permanentlyBlockedCount} phone number(s) were previously assigned in your company and are permanently blocked from re-allocation.',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Optional Dynamic Branch & Category Assignment for imported leads
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune_outlined, size: 16, color: AppColors.accentViolet),
                      const SizedBox(width: 6),
                      Text('Default Batch Tagging (Optional)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 250,
                        child: DropdownButtonFormField<String?>(
                          initialValue: _selectedBranchId,
                          decoration: const InputDecoration(
                            labelText: 'Assign Branch',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('No Branch (Global)')),
                            ...leadProvider.branches.map((br) => DropdownMenuItem(value: br.id, child: Text(br.name))),
                          ],
                          onChanged: (val) => setState(() => _selectedBranchId = val),
                        ),
                      ),
                      SizedBox(
                        width: 250,
                        child: DropdownButtonFormField<String?>(
                          initialValue: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Assign Category',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('No Category')),
                            ...leadProvider.categories.map((cat) => DropdownMenuItem(value: cat.id, child: Text(cat.name))),
                          ],
                          onChanged: (val) => setState(() => _selectedCategoryId = val),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Text('Sample Staged Records for Import', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                constraints: const BoxConstraints(minWidth: 500),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DataTable(
                  headingRowHeight: 36,
                  dataRowMinHeight: 38,
                  dataRowMaxHeight: 44,
                  columns: const [
                    DataColumn(label: Text('Row')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Normalized Phone')),
                    DataColumn(label: Text('City')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: b.stagingData.take(5).map((row) {
                    return DataRow(
                      cells: [
                        DataCell(Text('${row['row_number']}')),
                        DataCell(Text(row['name'] ?? '')),
                        DataCell(Text(row['normalized_phone'] ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
                        DataCell(Text(row['city'] ?? '—')),
                        DataCell(Text('Valid', style: GoogleFonts.inter(color: AppColors.success, fontWeight: FontWeight.w600))),
                      ],
                    );
                  }).toList(),
                ),
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
            const Icon(Icons.check_circle_outline, color: AppColors.success, size: 56),
            const SizedBox(height: 14),
            Text('Import Confirmed', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
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
    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
