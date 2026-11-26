import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  static final VoiceService instance = VoiceService._internal();
  VoiceService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  Future<void> init() async {
    if (_initialized) return;
    try {
      // Set audio attributes and volume
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);

      // On Android, set queue mode to 1 (QUEUE_FLUSH) so new speech replaces old smoothly
      if (!kIsWeb && Platform.isAndroid) {
        try {
          await _tts.setQueueMode(1);
        } catch (_) {}
      }

      await _tts.awaitSpeakCompletion(false);

      // Try setting Indian English first, fallback to US or device default
      bool langSet = false;
      try {
        final languages = await _tts.getLanguages;
        if (languages is List && languages.isNotEmpty) {
          final langStrings = languages.map((e) => e.toString().toLowerCase()).toList();
          if (langStrings.any((l) => l.contains('en-in') || l.contains('en_in'))) {
            await _tts.setLanguage('en-IN');
            langSet = true;
          } else if (langStrings.any((l) => l.contains('en-us') || l.contains('en_us'))) {
            await _tts.setLanguage('en-US');
            langSet = true;
          }
        }
      } catch (e) {
        debugPrint('[VoiceService] Language check error: $e');
      }

      if (!langSet) {
        try {
          await _tts.setLanguage('en-IN');
        } catch (_) {
          await _tts.setLanguage('en-US');
        }
      }

      _tts.setStartHandler(() {
        _isSpeaking = true;
      });
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });
      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint('[VoiceService] TTS Error: $msg');
      });

      _initialized = true;
      debugPrint('[VoiceService] TTS initialized successfully');
    } catch (e) {
      debugPrint('[VoiceService] Init failed: $e');
    }
  }

  /// Announces verified boarding with student's name
  Future<void> speakVerified(String name) async {
    await HapticFeedback.mediumImpact();
    final cleanName = _cleanStudentName(name);
    await _speak('Verified, $cleanName');
  }

  /// Announces warning (e.g., already scanned, wrong bus)
  Future<void> speakWarning(String message) async {
    await HapticFeedback.heavyImpact();
    await _speak(message);
  }

  /// Announces error
  Future<void> speakError(String message) async {
    await HapticFeedback.heavyImpact();
    await _speak(message);
  }

  Future<void> _speak(String text) async {
    try {
      if (!_initialized) {
        await init();
      }
      debugPrint('[VoiceService] Speaking: "$text"');
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[VoiceService] Speak error: $e');
    }
  }

  String _cleanStudentName(String name) {
    var s = name.trim();
    // If name contains parentheses or role tags, clean them
    s = s.replaceAll(RegExp(r'\[.*?\]'), '').replaceAll(RegExp(r'\(.*?\)'), '').trim();
    if (s.isEmpty) return 'Passenger';
    return s;
  }
}
