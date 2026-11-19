import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_scaffold.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/glass_text_field.dart';
import '../../core/widgets/glass/animated_status_badge.dart';
import '../../core/widgets/glass/recording_indicator.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/date_range_filter_bar.dart';
import '../../routes/app_routes.dart';
import '../../providers/recording_provider.dart';
import '../../providers/lead_provider.dart';
import '../../providers/auth_provider.dart';

class CallRecordingsScreen extends StatefulWidget {
  final String? initialEmployeeId;
  final String? employeeName;

  const CallRecordingsScreen({super.key, this.initialEmployeeId, this.employeeName});

  @override
  State<CallRecordingsScreen> createState() => _CallRecordingsScreenState();
}

class _CallRecordingsScreenState extends State<CallRecordingsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String? _selectedLeadId;
  String? _selectedEmployeeId;
  String _statusFilter = 'ALL';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _selectedEmployeeId = widget.initialEmployeeId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecordingProvider>().fetchRecordings(employeeId: _selectedEmployeeId);
      context.read<LeadProvider>().fetchLeads();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showSaveDialog(RecordingProvider recordingProv) {
    final leads = context.read<LeadProvider>().leads;
    _selectedLeadId = leads.isNotEmpty ? leads.first.id : null;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: GlassCard(
                  blur: 24,
                  opacity: 0.2,
                  borderRadius: BorderRadius.circular(24),
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.save_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Save Call Recording',
                                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    'Duration: ${recordingProv.timerString}',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.neonCyan),
                                  ),
                                ],
                              ),
                            ),
                            DialogCloseButton(
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Associated Lead Selector
                        Text(
                          'Associate with Lead',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedLeadId,
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                              items: leads.map((lead) {
                                return DropdownMenuItem<String>(
                                  value: lead.id,
                                  child: Text('${lead.fullName} (${lead.phoneNumber})'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setDialogState(() {
                                  _selectedLeadId = val;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Notes
                        GlassTextField(
                          label: 'Call Notes & Context',
                          hintText: 'Customer inquired about enterprise pricing tier...',
                          maxLines: 3,
                          controller: notesController,
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 24),
                          padding: const EdgeInsets.only(top: 18),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: Color(0x33D4AF37), width: 1)),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              GlassSecondaryButton(
                                text: 'Discard',
                                icon: Icons.delete_outline,
                                onPressed: () {
                                  recordingProv.cancelRecording();
                                  Navigator.pop(context);
                                },
                              ),
                              GradientPrimaryButton(
                                text: 'Save Recording',
                                icon: Icons.check_circle_rounded,
                                isLoading: recordingProv.isLoading,
                                onPressed: () async {
                                  final success = await recordingProv.saveRecording(
                                    leadId: _selectedLeadId,
                                    notes: notesController.text.trim(),
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    if (success) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.check_circle, color: Colors.white),
                                              const SizedBox(width: 10),
                                              const Expanded(child: Text('Call recording saved successfully!')),
                                            ],
                                          ),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final recordingProv = context.watch<RecordingProvider>();
    final auth = context.watch<AuthProvider>();
    final isMobile = MediaQuery.of(context).size.width < 700;

    return GlassScaffold(
      backgroundImage: 'assets/images/telecaller_calling_bg.jpg',
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 12 : 24,
          isMobile ? 6 : 16,
          isMobile ? 12 : 24,
          isMobile ? 12 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Section: Compact Title
            _buildHeaderAndBanner(),
            const SizedBox(height: 14),

            // Compact Recording Bar
            _buildRecordingStudio(recordingProv, isMobile),
            const SizedBox(height: 18),

            // Saved Recordings List
            _buildSavedRecordingsSection(recordingProv, auth),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAndBanner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const AppBackButton(fallbackRoute: AppRoutes.dashboard),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppColors.cyanGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: AppColors.neonCyan.withValues(alpha: 0.35), blurRadius: 16),
                ],
              ),
              child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Call Recording Studio',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Capture, monitor, and review live customer telecalling sessions',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.employeeName != null && _selectedEmployeeId != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF93C5FD)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_rounded, size: 14, color: Color(0xFF1D4ED8)),
                          const SizedBox(width: 4),
                          Text(
                            'Filtered by Staff: ${widget.employeeName}',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              setState(() => _selectedEmployeeId = null);
                              context.read<RecordingProvider>().fetchRecordings();
                            },
                            child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF1D4ED8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickAndUploadAudioFile(RecordingProvider recordingProv) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null && file.bytes!.isNotEmpty) {
          recordingProv.attachUploadedFile(
            fileBytes: file.bytes!,
            fileName: file.name,
            durationSeconds: 60,
          );
          if (mounted) {
            _showSaveDialog(recordingProv);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick audio file: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Widget _buildRecordingStudio(RecordingProvider recordingProv, bool isMobile) {
    return GlassCard(
      blur: 20,
      opacity: 0.9,
      borderColor: recordingProv.isRecording
          ? AppColors.neonCoral.withValues(alpha: 0.45)
          : const Color(0xFFE2E8F0),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 12),
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RecordingIndicator(
                    durationSeconds: recordingProv.elapsedSeconds,
                    isRecording: recordingProv.isRecording,
                    isPaused: recordingProv.isPaused,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    recordingProv.isRecording
                        ? (recordingProv.isPaused ? 'PAUSED' : 'RECORDING')
                        : 'READY',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: recordingProv.isRecording
                          ? (recordingProv.isPaused ? AppColors.neonSunset : AppColors.neonCoral)
                          : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    recordingProv.timerString,
                    style: GoogleFonts.robotoMono(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: recordingProv.isRecording ? AppColors.danger : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!recordingProv.isRecording) ...[
                    GradientPrimaryButton(
                      text: 'Start Recording',
                      icon: Icons.fiber_manual_record_rounded,
                      height: 36,
                      gradient: AppColors.coralGradient,
                      onPressed: () => recordingProv.startRecording(),
                    ),
                    GlassSecondaryButton(
                      text: 'Upload Audio',
                      icon: Icons.upload_file_rounded,
                      height: 36,
                      onPressed: () => _pickAndUploadAudioFile(recordingProv),
                    ),
                  ] else ...[
                    if (!recordingProv.isPaused)
                      GlassSecondaryButton(
                        text: 'Pause',
                        icon: Icons.pause_rounded,
                        height: 36,
                        onPressed: () => recordingProv.pauseRecording(),
                      )
                    else
                      GradientPrimaryButton(
                        text: 'Resume',
                        icon: Icons.play_arrow_rounded,
                        height: 36,
                        gradient: AppColors.cyanGradient,
                        onPressed: () => recordingProv.resumeRecording(),
                      ),
                    GradientPrimaryButton(
                      text: 'Stop & Save',
                      icon: Icons.stop_rounded,
                      height: 36,
                      gradient: AppColors.primaryGradient,
                      onPressed: () async {
                        await recordingProv.stopRecording();
                        if (mounted) {
                          _showSaveDialog(recordingProv);
                        }
                      },
                    ),
                    GlassSecondaryButton(
                      text: 'Discard',
                      icon: Icons.delete_outline_rounded,
                      height: 36,
                      onPressed: () => recordingProv.cancelRecording(),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (recordingProv.isRecording) ...[
            const SizedBox(height: 10),
            Container(
              height: 34,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: AudioWaveformVisualizer(
                isRecording: recordingProv.isRecording && !recordingProv.isPaused,
                barCount: 36,
                height: 26,
                activeGradient: AppColors.coralGradient,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSavedRecordingsSection(RecordingProvider recordingProv, AuthProvider auth) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = recordingProv.recordings.where((rec) {
      if (_statusFilter != 'ALL') {
        final oc = (rec.callOutcome ?? '').toUpperCase();
        if (_statusFilter == 'NO_ANSWER') {
          if (!oc.contains('NO_ANSWER') && !oc.contains('NOT_ANSWERED') && !oc.contains('MISSED')) {
            return false;
          }
        } else if (!oc.contains(_statusFilter)) {
          return false;
        }
      }
      if (_dateFrom != null && rec.createdAt.toLocal().isBefore(_dateFrom!)) {
        return false;
      }
      if (_dateTo != null) {
        final endOfDay = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
        if (rec.createdAt.toLocal().isAfter(endOfDay)) return false;
      }
      if (query.isNotEmpty) {
        final lead = (rec.leadName ?? '').toLowerCase();
        final phone = (rec.leadPhone ?? '').toLowerCase();
        final emp = (rec.employeeName ?? '').toLowerCase();
        if (!lead.contains(query) && !phone.contains(query) && !emp.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Saved Call Recordings',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  AnimatedStatusBadge(
                    label: '${filtered.length} Shown',
                    statusColor: AppColors.neonCyan,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
              tooltip: 'Refresh Recordings',
              onPressed: () => recordingProv.fetchRecordings(employeeId: _selectedEmployeeId),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DateRangeFilterBar(
          onChanged: (from, to) {
            setState(() {
              _dateFrom = (from != null && from.isNotEmpty) ? DateTime.tryParse(from) : null;
              _dateTo = (to != null && to.isNotEmpty) ? DateTime.tryParse(to) : null;
            });
          },
        ),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.all(10),
          child: LayoutBuilder(
            builder: (ctx, c) {
              final searchBox = TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search by Lead Name, Phone, or Employee...',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              );
              final statusDrop = Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    isExpanded: true,
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                      DropdownMenuItem(value: 'CONNECTED', child: Text('Connected')),
                      DropdownMenuItem(value: 'NO_ANSWER', child: Text('Not Answered')),
                      DropdownMenuItem(value: 'BUSY', child: Text('Busy')),
                      DropdownMenuItem(value: 'CALLBACK', child: Text('Callback')),
                    ],
                    onChanged: (v) => setState(() => _statusFilter = v ?? 'ALL'),
                  ),
                ),
              );
              if (c.maxWidth >= 680) {
                return Row(
                  children: [
                    Expanded(flex: 2, child: searchBox),
                    const SizedBox(width: 10),
                    Expanded(flex: 1, child: statusDrop),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchBox,
                  const SizedBox(height: 8),
                  statusDrop,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        if (filtered.isEmpty)
          GlassCard(
            blur: 16,
            opacity: 0.12,
            padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.mic_none_rounded, color: Color(0xFF94A3B8), size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'No Call Recordings Found',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Use the recording bar above or adjust your search/status filters.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final rec = filtered[index];
              return GlassAudioPlayerWidget(
                recording: rec,
                onDelete: () => recordingProv.deleteRecording(rec.id),
              );
            },
          ),
      ],
    );
  }
}
