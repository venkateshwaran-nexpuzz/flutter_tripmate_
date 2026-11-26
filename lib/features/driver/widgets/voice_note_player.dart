import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/theme/app_theme.dart';

/// Interactive Voice Recorder & Player widget for Driver
/// Features:
/// - Record audio with animated recording indicator and live timer
/// - Instant playback right after recording
/// - Play / Pause / Seek / Position slider
/// - Elapsed time / Total duration readout
/// - Delete / Re-record voice note
class VoiceNotePlayerWidget extends StatefulWidget {
  final String? initialVoicePath;
  final ValueChanged<String?> onVoiceChanged;
  final String title;

  const VoiceNotePlayerWidget({
    super.key,
    this.initialVoicePath,
    required this.onVoiceChanged,
    this.title = 'குரல் குறிப்பு (Voice Note)',
  });

  @override
  State<VoiceNotePlayerWidget> createState() => _VoiceNotePlayerWidgetState();
}

class _VoiceNotePlayerWidgetState extends State<VoiceNotePlayerWidget>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;

  String? _voicePath;
  PlayerState _playerState = PlayerState.stopped;
  Duration _playbackPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _voicePath = widget.initialVoicePath;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _playerStateSubscription = _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _positionSubscription = _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _playbackPosition = pos);
    });

    _durationSubscription = _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _totalDuration = dur);
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.completed;
          _playbackPosition = Duration.zero;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant VoiceNotePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialVoicePath != oldWidget.initialVoicePath) {
      _voicePath = widget.initialVoicePath;
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _recorder.dispose();
    _player.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('மைக்ரோஃபோன் அனுமதி தேவை (Microphone permission required)'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
      return;
    }

    if (_playerState == PlayerState.playing) {
      await _player.stop();
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/tripmate_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: path,
    );

    setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
      _voicePath = null;
    });
    widget.onVoiceChanged(null);

    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isRecording) {
        setState(() => _recordDuration += const Duration(seconds: 1));
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _voicePath = path;
    });
    widget.onVoiceChanged(path);
  }

  Future<void> _togglePlayback() async {
    if (_voicePath == null) return;

    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      if (_playerState == PlayerState.completed || _playbackPosition == Duration.zero) {
        await _player.play(DeviceFileSource(_voicePath!));
      } else {
        await _player.resume();
      }
    }
  }

  Future<void> _deleteRecording() async {
    if (_playerState == PlayerState.playing) {
      await _player.stop();
    }
    if (_voicePath != null) {
      try {
        final f = File(_voicePath!);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    setState(() {
      _voicePath = null;
      _playbackPosition = Duration.zero;
      _totalDuration = Duration.zero;
      _playerState = PlayerState.stopped;
    });
    widget.onVoiceChanged(null);
  }

  String _formatTime(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isRecording
              ? AppTheme.danger.withOpacity(0.5)
              : _voicePath != null
                  ? const Color(0xFF059669).withOpacity(0.3)
                  : const Color(0xFFE2E8F0),
          width: _isRecording || _voicePath != null ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E40AF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mic_rounded, color: Color(0xFF1E40AF), size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (_voicePath != null && !_isRecording)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 12),
                      SizedBox(width: 4),
                      Text(
                        'தயார்',
                        style: TextStyle(
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // STATE 1: RECORDING IN PROGRESS
          if (_isRecording)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.danger.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: AppTheme.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'குரல் பதிவு நடக்கிறது...',
                          style: TextStyle(
                            color: AppTheme.danger,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _formatTime(_recordDuration),
                          style: const TextStyle(
                            color: AppTheme.danger,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _stopRecording,
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: const Text('நிறுத்து'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            )

          // STATE 2: RECORDED - INSTANT PLAYBACK & CONTROLS
          else if (_voicePath != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Play / Pause button
                      GestureDetector(
                        onTap: _togglePlayback,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E40AF).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Slider / Progress bar
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                activeTrackColor: const Color(0xFF1E40AF),
                                inactiveTrackColor: const Color(0xFFCBD5E1),
                                thumbColor: const Color(0xFF1E40AF),
                              ),
                              child: Slider(
                                value: _playbackPosition.inMilliseconds
                                    .clamp(0, (_totalDuration.inMilliseconds > 0 ? _totalDuration.inMilliseconds : 1))
                                    .toDouble(),
                                min: 0,
                                max: (_totalDuration.inMilliseconds > 0
                                        ? _totalDuration.inMilliseconds
                                        : 1)
                                    .toDouble(),
                                onChanged: (val) async {
                                  final seekPos = Duration(milliseconds: val.toInt());
                                  await _player.seek(seekPos);
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatTime(_playbackPosition),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E40AF),
                                    ),
                                  ),
                                  Text(
                                    _totalDuration > Duration.zero
                                        ? _formatTime(_totalDuration)
                                        : _formatTime(_recordDuration),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Re-record button
                      TextButton.icon(
                        onPressed: _startRecording,
                        icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF1E40AF)),
                        label: const Text(
                          'மீண்டும் பதிவு செய்',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                        ),
                      ),
                      // Delete button
                      TextButton.icon(
                        onPressed: _deleteRecording,
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.danger),
                        label: const Text(
                          'நீக்கு',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.danger),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )

          // STATE 3: EMPTY - RECORD BUTTON
          else
            Row(
              children: [
                GestureDetector(
                  onTap: _startRecording,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E40AF).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'குரல் குறிப்பு பதிவு செய்ய அழுத்தவும்',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'வாகன நிலை அல்லது பயண தகவல்களை பேசி பதிவு செய்து இங்கேயே கேட்கலாம்',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
