import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/glass_text_field.dart';
import '../../providers/call_provider.dart';
import '../../providers/lead_provider.dart';
import '../../providers/recording_provider.dart';

class CallOutcomeDialog extends StatefulWidget {
  final String leadId;
  final String leadName;
  final String? phoneNumber;
  final String? leadPhone;

  String get effectivePhone => phoneNumber ?? leadPhone ?? '';

  const CallOutcomeDialog({
    super.key,
    required this.leadId,
    required this.leadName,
    this.phoneNumber,
    this.leadPhone,
  });

  @override
  State<CallOutcomeDialog> createState() => _CallOutcomeDialogState();
}

class _CallOutcomeDialogState extends State<CallOutcomeDialog> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  String _outcome = 'ANSWERED';
  final _notesController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  
  bool _scheduleCallback = false;
  DateTime? _callbackDateTime;
  final _callbackNotesController = TextEditingController();
  bool _isSubmitting = false;
  bool _isFinalizingAudio = false;

  final List<String> _outcomes = [
    'ANSWERED',
    'BUSY',
    'NO_ANSWER',
    'CALLBACK_REQUESTED',
    'INTERESTED',
    'NOT_INTERESTED',
    'QUALIFIED',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncRecordingState();
    });
  }

  Future<void> _syncRecordingState() async {
    if (!mounted) return;
    final recProv = context.read<RecordingProvider>();
    if (!recProv.isRecording && !recProv.hasPendingRecording) {
      await recProv.startRecording(
        leadId: widget.leadId,
        leadName: widget.leadName,
        leadPhone: widget.effectivePhone,
      );
    } else if (recProv.elapsedSeconds > 0) {
      _durationController.text = recProv.elapsedSeconds.toString();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Employee returned from the phone dialer after the call ended
      _finalizeCallRecordingIfRunning();
    }
  }

  Future<void> _finalizeCallRecordingIfRunning() async {
    if (!mounted || _isFinalizingAudio) return;
    final recProv = context.read<RecordingProvider>();
    if (recProv.isRecording) {
      setState(() => _isFinalizingAudio = true);
      await recProv.stopRecording();
      if (mounted) {
        setState(() {
          _isFinalizingAudio = false;
          if (recProv.elapsedSeconds > 0) {
            _durationController.text = recProv.elapsedSeconds.toString();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notesController.dispose();
    _durationController.dispose();
    _callbackNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickCallbackDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 11, minute: 0),
      );
      if (time != null) {
        setState(() {
          _callbackDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if ((_outcome == 'CALLBACK_REQUESTED' || _scheduleCallback) && _callbackDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a callback date and time.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final callProvider = context.read<CallProvider>();
    final recProvider = context.read<RecordingProvider>();

    if (recProvider.isRecording) {
      await recProvider.stopRecording();
      if (recProvider.elapsedSeconds > 0) {
        _durationController.text = recProvider.elapsedSeconds.toString();
      }
    }

    final durationSec = int.tryParse(_durationController.text) ?? recProvider.elapsedSeconds;

    final success = await callProvider.logCallOutcome(
      leadId: widget.leadId,
      outcome: _outcome,
      notes: _notesController.text.trim(),
      durationSeconds: durationSec,
      dialerLaunchedAt: DateTime.now(),
      scheduleCallback: _scheduleCallback || _outcome == 'CALLBACK_REQUESTED',
      callbackTime: _callbackDateTime,
      callbackNotes: _callbackNotesController.text.trim(),
    );

    if (success) {
      // Automatically upload and link the call recording so employee cannot bypass it
      await recProvider.saveRecording(
        title: 'Call with ${widget.leadName} ($_outcome)',
        leadId: widget.leadId,
        callAttemptId: callProvider.lastCreatedCallId,
        notes: _notesController.text.trim(),
        durationSeconds: durationSec > 0 ? durationSec : null,
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      context.read<LeadProvider>().fetchLeadDetail(widget.leadId);
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Call outcome, notes, and call audio recording uploaded!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(callProvider.errorMessage ?? 'Failed to record call outcome.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recProvider = context.watch<RecordingProvider>();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: GlassCard(
          blur: 24,
          opacity: 0.18,
          borderRadius: BorderRadius.circular(20),
          borderColor: AppColors.glassBorderHighlight,
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
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
                        child: const Icon(Icons.phone_callback_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Record Call Outcome',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${widget.leadName} (${widget.effectivePhone})',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      DialogCloseButton(
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFE2E8F0), height: 1),
                  const SizedBox(height: 14),

                  // Automatic Call Recording Status Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: recProvider.isRecording
                          ? AppColors.danger.withValues(alpha: 0.08)
                          : AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: recProvider.isRecording
                            ? AppColors.danger.withValues(alpha: 0.3)
                            : AppColors.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              recProvider.isRecording
                                  ? Icons.fiber_manual_record_rounded
                                  : Icons.verified_rounded,
                              size: 16,
                              color: recProvider.isRecording ? AppColors.danger : AppColors.success,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                recProvider.isRecording
                                    ? 'AUTO-RECORDING ACTIVE (${recProvider.timerString})'
                                    : (_isFinalizingAudio
                                        ? 'FINALIZING 2-WAY CALL AUDIO...'
                                        : 'CALL RECORDING CAPTURED (${recProvider.timerString})'),
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: recProvider.isRecording ? AppColors.danger : AppColors.success,
                                ),
                              ),
                            ),
                            if (recProvider.isRecording)
                              TextButton.icon(
                                onPressed: _finalizeCallRecordingIfRunning,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.stop_circle_outlined, size: 14, color: AppColors.danger),
                                label: Text(
                                  'Lock Audio',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.danger),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Source: ${recProvider.captureModeLabel} • Automatically uploads with outcome',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Call Outcome Dropdown
                  Text('Call Outcome *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _outcome,
                        dropdownColor: Colors.white,
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                        items: _outcomes.map((o) {
                          return DropdownMenuItem(
                            value: o,
                            child: Text(o.replaceAll('_', ' ')),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _outcome = val!;
                            if (_outcome == 'CALLBACK_REQUESTED') {
                              _scheduleCallback = true;
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Call Notes (Mandatory)
                  GlassTextField(
                    label: 'Call Notes * (Mandatory policy requirement)',
                    hintText: 'Enter detailed conversation summary, customer response, next steps...',
                    controller: _notesController,
                    maxLines: 3,
                    validator: (v) {
                      if (v == null || v.trim().length < 5) {
                        return 'Notes are mandatory (at least 5 characters required).';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Call Duration Seconds
                  GlassTextField(
                    label: 'Approximate Call Duration (seconds)',
                    hintText: 'e.g. 45',
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // Callback Scheduling Checkbox
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: CheckboxListTile(
                      title: Text(
                        'Schedule a Follow-up Callback',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                      ),
                      value: _scheduleCallback || _outcome == 'CALLBACK_REQUESTED',
                      activeColor: AppColors.neonCyan,
                      checkColor: Colors.black,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      onChanged: _outcome == 'CALLBACK_REQUESTED'
                          ? null
                          : (val) => setState(() => _scheduleCallback = val ?? false),
                    ),
                  ),

                  if (_scheduleCallback || _outcome == 'CALLBACK_REQUESTED') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.neonCyan.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _callbackDateTime == null
                                      ? 'Select date & time'
                                      : DateFormat('EEE, MMM d, yyyy @ h:mm a').format(_callbackDateTime!),
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.neonCyan),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _pickCallbackDateTime,
                                icon: const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.neonCyan),
                                label: Text('Pick Time', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neonCyan)),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppColors.neonCyan.withValues(alpha: 0.5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          GlassTextField(
                            label: 'Reminder Note',
                            hintText: 'Initial callback reminder note...',
                            controller: _callbackNotesController,
                          ),
                        ],
                      ),
                    ),
                  ],
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
                          text: 'Cancel',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        GradientPrimaryButton(
                          text: 'Submit Outcome',
                          icon: Icons.check_rounded,
                          isLoading: _isSubmitting,
                          onPressed: _submit,
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
  }
}
