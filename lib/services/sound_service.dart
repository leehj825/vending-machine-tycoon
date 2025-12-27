import 'package:audioplayers/audioplayers.dart';

/// Service for managing game audio (sound effects and background music)
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _backgroundMusicPlayer = AudioPlayer();
  final AudioPlayer _soundEffectPlayer = AudioPlayer();
  
  bool _isMusicEnabled = true;
  bool _isSoundEnabled = true;
  double _musicVolume = 0.6; // Increased from 0.5 to 0.8 for better audibility
  double _soundVolume = 0.7;
  String? _currentMusicPath; // Track what music is currently playing
  DateTime? _lastMusicStartTime; // Track when music was last started (to prevent immediate stops)

  /// Check if background music is enabled
  bool get isMusicEnabled => _isMusicEnabled;

  /// Check if sound effects are enabled
  bool get isSoundEnabled => _isSoundEnabled;

  /// Get current music volume (0.0 to 1.0)
  double get musicVolume => _musicVolume;

  /// Get current sound volume (0.0 to 1.0)
  double get soundVolume => _soundVolume;

  /// Enable or disable background music
  void setMusicEnabled(bool enabled) {
    _isMusicEnabled = enabled;
    if (!enabled) {
      stopBackgroundMusic();
    }
  }

  /// Enable or disable sound effects
  void setSoundEnabled(bool enabled) {
    _isSoundEnabled = enabled;
  }

  /// Set music volume (0.0 to 1.0)
  void setMusicVolume(double volume) {
    _musicVolume = volume.clamp(0.0, 1.0);
    _backgroundMusicPlayer.setVolume(_musicVolume);
  }

  /// Set sound effects volume (0.0 to 1.0)
  void setSoundVolume(double volume) {
    _soundVolume = volume.clamp(0.0, 1.0);
    _soundEffectPlayer.setVolume(_soundVolume);
  }

  /// Play background music (looping)
  /// assetPath should be relative to assets/ directory (e.g., 'sound/game_menu.mp3')
  Future<void> playBackgroundMusic(String assetPath) async {
    if (!_isMusicEnabled) {
      print('🔇 Music is disabled, skipping: $assetPath');
      return;
    }
    
    // If the same music is already playing, do nothing - just return
    // This prevents unnecessary restarts when switching tabs or rebuilding widgets
    if (_currentMusicPath == assetPath) {
      // Silently skip - music is already playing, no need to check state or restart
      return;
    }
    
    try {
      // Stop any currently playing music first (only if different)
      if (_currentMusicPath != null && _currentMusicPath != assetPath) {
        print('🛑 Stopping current music: $_currentMusicPath');
        await _backgroundMusicPlayer.stop();
        // Small delay to ensure stop completes
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      await _restartMusic(assetPath);
    } catch (e, stackTrace) {
      print('❌ Error playing background music ($assetPath): $e');
      print('Stack trace: $stackTrace');
      _currentMusicPath = null; // Reset on error
    }
  }
  
  /// Internal method to start/restart music
  Future<void> _restartMusic(String assetPath) async {
    // Configure for looping
    await _backgroundMusicPlayer.setReleaseMode(ReleaseMode.loop);
    await _backgroundMusicPlayer.setVolume(_musicVolume);
    
    print('🎵 Playing background music: $assetPath (volume: $_musicVolume)');
    await _backgroundMusicPlayer.play(AssetSource(assetPath));
    _currentMusicPath = assetPath; // Track what's playing
    _lastMusicStartTime = DateTime.now(); // Track when music started
    print('🎵 Music playback started');
  }

  /// Stop background music
  /// Only stops if explicitly called (e.g., when navigating to menu)
  /// Prevents stopping music that was just started (within last 500ms) to avoid race conditions
  /// Use forceStop parameter to bypass this protection when explicitly needed (e.g., exit to menu)
  Future<void> stopBackgroundMusic({bool forceStop = false}) async {
    try {
      if (_currentMusicPath != null) {
        // Prevent stopping music that was just started (within last 500ms)
        // This prevents race conditions when navigating between screens
        // But allow force stop to bypass this protection
        if (!forceStop && _lastMusicStartTime != null) {
          final timeSinceStart = DateTime.now().difference(_lastMusicStartTime!);
          if (timeSinceStart.inMilliseconds < 500) {
            print('⚠️ Ignoring stop request - music was just started ${timeSinceStart.inMilliseconds}ms ago (use forceStop=true to override)');
            return;
          }
        }
        
        print('🛑 Stopping background music: $_currentMusicPath');
        await _backgroundMusicPlayer.stop();
        _currentMusicPath = null; // Clear current track
        _lastMusicStartTime = null; // Clear start time
        print('✅ Background music stopped');
      } else {
        print('ℹ️ No background music to stop');
      }
    } catch (e) {
      print('❌ Error stopping background music: $e');
      _currentMusicPath = null; // Reset on error
      _lastMusicStartTime = null;
    }
  }

  /// Pause background music
  Future<void> pauseBackgroundMusic() async {
    try {
      await _backgroundMusicPlayer.pause();
    } catch (e) {
      print('Error pausing background music: $e');
    }
  }

  /// Resume background music
  Future<void> resumeBackgroundMusic() async {
    if (!_isMusicEnabled) return;
    
    try {
      await _backgroundMusicPlayer.resume();
    } catch (e) {
      print('Error resuming background music: $e');
    }
  }

  /// Play a sound effect (one-shot)
  Future<void> playSoundEffect(String assetPath) async {
    if (!_isSoundEnabled) return;
    
    try {
      await _soundEffectPlayer.setReleaseMode(ReleaseMode.release);
      await _soundEffectPlayer.setVolume(_soundVolume);
      print('🔊 Playing sound effect: $assetPath');
      await _soundEffectPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('❌ Error playing sound effect ($assetPath): $e');
    }
  }

  /// Play button click sound
  Future<void> playButtonSound() async {
    await playSoundEffect('sound/button.m4a');
  }

  /// Play coin collect sound
  Future<void> playCoinCollectSound() async {
    await playSoundEffect('sound/coin_collect.m4a');
  }

  /// Play truck sound (when "Go Stock" is pressed)
  Future<void> playTruckSound() async {
    await playSoundEffect('sound/truck.mp3');
  }

  /// Dispose resources
  void dispose() {
    _backgroundMusicPlayer.dispose();
    _soundEffectPlayer.dispose();
  }
}

