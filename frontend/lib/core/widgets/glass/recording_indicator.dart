import 'dart:async';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/recording_model.dart';
import '../../../providers/recording_provider.dart';
import '../../theme/app_theme.dart';
import 'glass_card.dart';

class AudioWaveformVisualizer extends StatefulWidget {
  final bool isRecording;
  final bool isPlaying;
  final int barCount;
  final double height;
  final Color? barColor;
  final Gradient? activeGradient;

  const AudioWaveformVisualizer({
    super.key,
    required this.isRecording,
    this.isPlaying = false,
    this.barCount = 36,
    this.height = 48.0,
    this.barColor,
    this.activeGradient,
  });

  @override
  State<AudioWaveformVisualizer> createState() => _AudioWaveformVisualizerState();
}

class _AudioWaveformVisualizerState extends State<AudioWaveformVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  final Random _random = Random(42);
  late List<double> _baseHeights;

  @override
  void initState() {
    super.initState();
    _baseHeights = List.generate(
      widget.barCount,
      (i) => 0.2 + (_random.nextDouble() * 0.75),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    if (widget.isRecording || widget.isPlaying) {
      _waveController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AudioWaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording || widget.isPlaying) {
      if (!_waveController.isAnimating) {
        _waveController.repeat(reverse: true);
      }
    } else {
      _waveController.stop();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxAvailableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 280.0;
        final effectiveBarCount = (maxAvailableWidth / 6.5).floor().clamp(8, widget.barCount);

        return AnimatedBuilder(
          animation: _waveController,
          builder: (context, child) {
            final phase = _waveController.value;
            return SizedBox(
              height: widget.height,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(effectiveBarCount, (i) {
                  double factor = _baseHeights[i % _baseHeights.length];
                  if (widget.isRecording || widget.isPlaying) {
                    // Apply dynamic sine wave offset
                    final offset = sin((i / effectiveBarCount * 2 * pi) + (phase * 2 * pi));
                    factor = (factor + (offset * 0.35)).clamp(0.12, 1.0);
                  }

                  final activeColor = widget.barColor ??
                      (widget.isRecording
                          ? AppColors.neonCoral
                          : (widget.isPlaying ? AppColors.neonCyan : AppColors.accentViolet));

                  return Container(
                    width: 3.2,
                    height: widget.height * factor,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: activeColor.withValues(
                        alpha: (widget.isRecording || widget.isPlaying) ? 0.85 : 0.40,
                      ),
                      boxShadow: (widget.isRecording || widget.isPlaying)
                          ? [
                              BoxShadow(
                                color: activeColor.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              ),
            );
          },
        );
      },
    );
  }
}

class RecordingIndicator extends StatefulWidget {
  final int durationSeconds;
  final bool isRecording;
  final bool isPaused;

  const RecordingIndicator({
    super.key,
    this.durationSeconds = 0,
    required this.isRecording,
    this.isPaused = false,
  });

  @override
  State<RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<RecordingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatTimer(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x28000000),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.isRecording
              ? (widget.isPaused ? AppColors.warning : AppColors.danger)
              : AppColors.glassBorder,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isRecording)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final color = widget.isPaused ? AppColors.warning : AppColors.danger;
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: widget.isPaused ? 1.0 : _pulseController.value),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                );
              },
            )
          else
            const Icon(Icons.mic_off, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text(
            widget.isRecording
                ? (widget.isPaused ? 'PAUSED' : 'REC')
                : 'IDLE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: widget.isRecording
                  ? (widget.isPaused ? AppColors.warning : AppColors.danger)
                  : AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTimer(widget.durationSeconds),
            style: GoogleFonts.robotoMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class GlassAudioPlayerWidget extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final int? totalDurationSeconds;
  final String? audioUrl;
  final VoidCallback? onDelete;
  final CallRecordingModel? recording;

  const GlassAudioPlayerWidget({
    super.key,
    this.title,
    this.subtitle,
    this.totalDurationSeconds,
    this.audioUrl,
    this.onDelete,
    this.recording,
  });

  @override
  State<GlassAudioPlayerWidget> createState() => _GlassAudioPlayerWidgetState();
}

class _GlassAudioPlayerWidgetState extends State<GlassAudioPlayerWidget> {
  bool _isPlaying = false;
  bool _isExporting = false;
  double _currentPosition = 0; // seconds
  int _resolvedDuration = 0;
  Timer? _statusTimer;

  String _formatTime(double sec) {
    final s = sec.round();
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final rem = (s % 60).toString().padLeft(2, '0');
    return '$m:$rem';
  }

  Color _outcomeColor(String outcome) {
    final upper = outcome.toUpperCase();
    if (upper.contains('NO_ANSWER') || upper.contains('NOT_ANSWERED') || upper.contains('MISSED') || upper.contains('REJECT')) {
      return const Color(0xFFDC2626);
    }
    if (upper.contains('BUSY') || upper.contains('VOICEMAIL') || upper.contains('CALLBACK')) {
      return const Color(0xFFD97706);
    }
    return const Color(0xFF059669);
  }

  Future<void> _exportToDevice(String leadName) async {
    final url = _effectiveAudioUrl;
    if (url == null || url.isEmpty || _isExporting) return;
    setState(() => _isExporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode >= 200 && res.statusCode < 300 && res.bodyBytes.isNotEmpty) {
        final safeLead = leadName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final uriPath = Uri.tryParse(url)?.path ?? '';
        final ext = uriPath.contains('.') ? uriPath.split('.').last : 'm4a';
        final fileName = '${safeLead}_recording.$ext';
        final savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Call Recording to Device',
          fileName: fileName,
          bytes: res.bodyBytes,
        );
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(savedPath != null && savedPath.isNotEmpty
                  ? 'Saved recording to $savedPath'
                  : 'Recording exported ($fileName)'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String? get _effectiveAudioUrl => widget.recording?.audioUrl ?? widget.audioUrl;
  int get _duration => _resolvedDuration > 0
      ? _resolvedDuration
      : (widget.recording?.durationSeconds ?? widget.totalDurationSeconds ?? 0);

  @override
  void dispose() {
    _statusTimer?.cancel();
    if (_isPlaying) {
      RecordingProvider.pauseAudioPlayback();
    }
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      _statusTimer?.cancel();
      await RecordingProvider.pauseAudioPlayback();
      if (mounted) {
        setState(() => _isPlaying = false);
      }
      return;
    }

    final url = _effectiveAudioUrl;
    if (url != null && url.isNotEmpty) {
      final started = await RecordingProvider.playAudioUrl(url);
      if (!mounted) return;
      setState(() {
        _isPlaying = started;
      });
      if (!started) return;
      _statusTimer?.cancel();
      _statusTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
        final status = await RecordingProvider.getAudioPlaybackStatus();
        if (!mounted) {
          timer.cancel();
          return;
        }
        final playing = status['isPlaying'] == true;
        final pos = (status['positionSeconds'] as num?)?.toDouble() ?? 0.0;
        final dur = (status['durationSeconds'] as num?)?.round() ?? 0;
        setState(() {
          _isPlaying = playing;
          _currentPosition = pos;
          if (dur > 0) _resolvedDuration = dur;
        });
        if (!playing) {
          timer.cancel();
        }
      });
    } else {
      // Fallback visual playback when no audio file URL is attached
      setState(() {
        _isPlaying = true;
        if (_currentPosition >= _duration) {
          _currentPosition = 0;
        }
      });
      _statusTimer?.cancel();
      _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _currentPosition += 1;
          if (_currentPosition >= max(1, _duration)) {
            _currentPosition = max(1, _duration).toDouble();
            _isPlaying = false;
            timer.cancel();
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxSec = max(1.0, _duration.toDouble());
    final rec = widget.recording;
    final leadName = (rec?.leadName != null && rec!.leadName!.isNotEmpty) ? rec.leadName! : (widget.title ?? 'Lead Contact');
    final leadPhone = rec?.leadPhone ?? '';
    final leadCity = rec?.leadCity ?? '';
    final staffName = (rec?.employeeName != null && rec!.employeeName!.isNotEmpty) ? rec.employeeName! : 'Staff';
    final callOutcome = rec?.callOutcome ?? '';
    final dateFormatted = rec != null ? DateFormat('dd MMM yyyy • hh:mm a').format(rec.createdAt.toLocal()) : '';
    final fileSizeFormatted = rec != null && rec.fileSizeBytes > 0
        ? (rec.fileSizeBytes > 1024 * 1024
            ? '${(rec.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
            : '${(rec.fileSizeBytes / 1024).toStringAsFixed(0)} KB')
        : '';
    final durationFormatted = _formatTime(_duration.toDouble());
    final notes = (rec?.notes != null && rec!.notes.isNotEmpty) ? rec.notes : (widget.subtitle ?? '');

    String sourceLabel = 'Headset + Mic';
    if (rec != null) {
      if (rec.source == 'SYSTEM_CALL_RECORDER') sourceLabel = '2-Way System Recorder';
      if (rec.source == 'AUTHORIZED_UPLOAD') sourceLabel = 'Authorized Upload';
      if (rec.source == 'AUTO_CALL_CAPTURE') sourceLabel = 'Auto Call Capture';
    }

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonViolet.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                leadName.isNotEmpty ? leadName[0].toUpperCase() : 'L',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  leadName,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (callOutcome.isNotEmpty) ...[
                const SizedBox(width: 8),
                Builder(builder: (_) {
                  final ocColor = _outcomeColor(callOutcome);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: ocColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      callOutcome.replaceAll('_', ' '),
                      style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: ocColor),
                    ),
                  );
                }),
              ],
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (leadPhone.isNotEmpty)
                  Text(
                    '$leadPhone${leadCity.isNotEmpty ? ' • $leadCity' : ''}',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                  ),
                Text(
                  'By: $staffName',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                ),
                if (dateFormatted.isNotEmpty)
                  Text(
                    dateFormatted,
                    style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                  ),
                Text(
                  durationFormatted + (fileSizeFormatted.isNotEmpty ? ' ($fileSizeFormatted)' : ''),
                  style: GoogleFonts.robotoMono(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: _togglePlay,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: AppColors.cyanGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.expand_more_rounded, color: Color(0xFF64748B)),
            ],
          ),
          children: [
            const Divider(height: 12, color: Color(0xFFE2E8F0)),
            if (notes.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notes_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        notes,
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF334155), fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            AudioWaveformVisualizer(
              isRecording: false,
              isPlaying: _isPlaying,
              barCount: 38,
              height: 32,
              barColor: AppColors.neonCyan,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  _formatTime(_currentPosition),
                  style: GoogleFonts.robotoMono(fontSize: 11, color: AppColors.neonCyan, fontWeight: FontWeight.w600),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      trackHeight: 3,
                      activeTrackColor: AppColors.neonCyan,
                      inactiveTrackColor: const Color(0xFFCBD5E1),
                      thumbColor: AppColors.neonCyan,
                    ),
                    child: Slider(
                      value: _currentPosition.clamp(0, maxSec),
                      min: 0,
                      max: maxSec,
                      onChanged: (v) {
                        setState(() => _currentPosition = v);
                        RecordingProvider.seekAudioPlayback(v);
                      },
                    ),
                  ),
                ),
                Text(
                  _formatTime(maxSec),
                  style: GoogleFonts.robotoMono(fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    sourceLabel,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_effectiveAudioUrl != null && _effectiveAudioUrl!.isNotEmpty) ...[
                      TextButton.icon(
                        onPressed: _isExporting ? null : () => _exportToDevice(leadName),
                        icon: _isExporting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.download_rounded, size: 16, color: Color(0xFF059669)),
                        label: Text('Save', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF059669))),
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new_rounded, size: 17, color: Color(0xFF2563EB)),
                        tooltip: 'Open Audio File URL',
                        onPressed: () async {
                          final uri = Uri.parse(_effectiveAudioUrl!);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                      ),
                    ],
                    if (widget.onDelete != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.neonCoral),
                        onPressed: widget.onDelete,
                        tooltip: 'Delete Recording',
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
