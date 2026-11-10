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
  String? _selectedLeadId;
  String? _selectedEmployeeId;

  @override
  void initState() {
    super.initState();
    _selectedEmployeeId = widget.initialEmployeeId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecordingProvider>().fetchRecordings(employeeId: _selectedEmployeeId);
      context.read<LeadProvider>().fetchLeads();
    });
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
            // Top Section: Title & Platform Limitation Banner
            _buildHeaderAndBanner(),
            const SizedBox(height: 24),

            // Live Call Recording Workbench
            _buildRecordingStudio(recordingProv, isMobile),
            const SizedBox(height: 32),

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
        const SizedBox(height: 16),

        // Honest Platform Limitation Note
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.neonCyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline_rounded, color: AppColors.neonCyan, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Platform Audio Capture Architecture',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mobile OS privacy sandboxes restrict third-party apps from intercepting cellular PSTN dialer audio directly. In-app recording utilizes verified microphone input, VoIP endpoints, or authorized audio file uploads.',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      blur: 24,
      opacity: 0.18,
      borderColor: recordingProv.isRecording
          ? AppColors.neonCoral.withValues(alpha: 0.4)
          : Colors.white.withValues(alpha: 0.15),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 28, vertical: isMobile ? 20 : 28),
      child: Column(
        children: [
          // Header inside studio
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    RecordingIndicator(
                      durationSeconds: recordingProv.elapsedSeconds,
                      isRecording: recordingProv.isRecording,
                      isPaused: recordingProv.isPaused,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        recordingProv.isRecording
                            ? (recordingProv.isPaused ? 'RECORDING PAUSED' : 'LIVE RECORDING IN PROGRESS')
                            : 'STUDIO STANDBY',
                        style: GoogleFonts.inter(
                          fontSize: isMobile ? 12 : 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: recordingProv.isRecording
                              ? (recordingProv.isPaused ? AppColors.neonSunset : AppColors.neonCoral)
                              : const Color(0xFF475569),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                recordingProv.timerString,
                style: GoogleFonts.robotoMono(
                  fontSize: isMobile ? 20 : 28,
                  fontWeight: FontWeight.w800,
                  color: recordingProv.isRecording ? AppColors.danger : const Color(0xFF64748B),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Waveform Canvas
          Container(
            height: 80,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: recordingProv.isRecording
                    ? AppColors.neonCoral.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: AudioWaveformVisualizer(
              isRecording: recordingProv.isRecording && !recordingProv.isPaused,
              barCount: 42,
              activeGradient: AppColors.coralGradient,
            ),
          ),
          const SizedBox(height: 24),

          // Controls Row
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              if (!recordingProv.isRecording) ...[
                GradientPrimaryButton(
                  text: 'Start Live Recording',
                  icon: Icons.fiber_manual_record_rounded,
                  gradient: AppColors.coralGradient,
                  onPressed: () => recordingProv.startRecording(),
                ),
                GlassSecondaryButton(
                  text: 'Upload Audio File',
                  icon: Icons.upload_file_rounded,
                  onPressed: () => _pickAndUploadAudioFile(recordingProv),
                ),
              ] else ...[
                if (!recordingProv.isPaused)
                  GlassSecondaryButton(
                    text: 'Pause',
                    icon: Icons.pause_rounded,
                    onPressed: () => recordingProv.pauseRecording(),
                  )
                else
                  GradientPrimaryButton(
                    text: 'Resume',
                    icon: Icons.play_arrow_rounded,
                    gradient: AppColors.cyanGradient,
                    onPressed: () => recordingProv.resumeRecording(),
                  ),
                GradientPrimaryButton(
                  text: 'Stop & Save',
                  icon: Icons.stop_rounded,
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
                  onPressed: () => recordingProv.cancelRecording(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavedRecordingsSection(RecordingProvider recordingProv, AuthProvider auth) {
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
                    label: '${recordingProv.recordings.length} Recorded',
                    statusColor: AppColors.neonCyan,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
              tooltip: 'Refresh Recordings',
              onPressed: () => recordingProv.fetchRecordings(),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (recordingProv.recordings.isEmpty)
          GlassCard(
            blur: 16,
            opacity: 0.12,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.mic_none_rounded, color: const Color(0xFF94A3B8), size: 54),
                  const SizedBox(height: 14),
                  Text(
                    'No Call Recordings Yet',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Start a live recording session above or attach audio to completed calls.',
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
            itemCount: recordingProv.recordings.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final rec = recordingProv.recordings[index];
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
