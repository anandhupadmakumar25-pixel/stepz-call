import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/call_provider.dart';
import '../../providers/lead_provider.dart';

class CallOutcomeDialog extends StatefulWidget {
  final String leadId;
  final String leadName;
  final String phoneNumber;

  const CallOutcomeDialog({
    super.key,
    required this.leadId,
    required this.leadName,
    required this.phoneNumber,
  });

  @override
  State<CallOutcomeDialog> createState() => _CallOutcomeDialogState();
}

class _CallOutcomeDialogState extends State<CallOutcomeDialog> {
  final _formKey = GlobalKey<FormState>();
  String _outcome = 'ANSWERED';
  final _notesController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  
  bool _scheduleCallback = false;
  DateTime? _callbackDateTime;
  final _callbackNotesController = TextEditingController();
  bool _isSubmitting = false;

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
  void dispose() {
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
        const SnackBar(content: Text('Please select a callback date and time.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final callProvider = context.read<CallProvider>();

    final success = await callProvider.logCallOutcome(
      leadId: widget.leadId,
      outcome: _outcome,
      notes: _notesController.text.trim(),
      durationSeconds: int.tryParse(_durationController.text) ?? 0,
      dialerLaunchedAt: DateTime.now(),
      scheduleCallback: _scheduleCallback || _outcome == 'CALLBACK_REQUESTED',
      callbackTime: _callbackDateTime,
      callbackNotes: _callbackNotesController.text.trim(),
    );

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      context.read<LeadProvider>().fetchLeadDetail(widget.leadId);
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Call outcome and notes recorded successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted) {
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
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Record Call Outcome', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('${widget.leadName} (${widget.phoneNumber})', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                  const Divider(height: 24),

                  // Call Outcome Dropdown
                  Text('Call Outcome *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _outcome,
                    decoration: const InputDecoration(),
                    items: _outcomes.map((o) {
                      return DropdownMenuItem(
                        value: o,
                        child: Text(o.replaceAll('_', ' '), style: GoogleFonts.inter(fontSize: 13)),
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
                  const SizedBox(height: 16),

                  // Call Notes (Mandatory)
                  Text('Call Notes * (Mandatory policy requirement)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Enter detailed conversation summary, customer response, next steps...',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 5) {
                        return 'Notes are mandatory (at least 5 characters required).';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Call Duration Seconds
                  Text('Approximate Call Duration (seconds)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'e.g. 45'),
                  ),
                  const SizedBox(height: 16),

                  // Callback Scheduling Checkbox
                  CheckboxListTile(
                    title: Text('Schedule a Follow-up Callback', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                    value: _scheduleCallback || _outcome == 'CALLBACK_REQUESTED',
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: _outcome == 'CALLBACK_REQUESTED'
                        ? null
                        : (val) => setState(() => _scheduleCallback = val ?? false),
                  ),

                  if (_scheduleCallback || _outcome == 'CALLBACK_REQUESTED') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentVioletLight.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.accentViolet.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _callbackDateTime == null
                                    ? 'Select date & time'
                                    : DateFormat('EEE, MMM d, yyyy @ h:mm a').format(_callbackDateTime!),
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              OutlinedButton.icon(
                                onPressed: _pickCallbackDateTime,
                                icon: const Icon(Icons.calendar_today, size: 14),
                                label: const Text('Pick Time'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _callbackNotesController,
                            decoration: const InputDecoration(
                              hintText: 'Initial callback reminder note...',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Submit Call Outcome & Update Lead'),
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
