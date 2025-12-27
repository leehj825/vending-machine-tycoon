import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../config.dart';

/// Service for managing game audio (sound effects and background music)
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  
  SoundService._internal() {
    _initAudioContext();
  }

  final AudioPlayer _backgroundMusicPlayer = AudioPlayer();
  final AudioPlayer _soundEffectPlayer = AudioPlayer();
  
  bool _isMusicEnabled = true;
  bool _isSoundEnabled = true;
  double _musicVolume = AppConfig.menuMusicDefaultVolume; // Base music volume (used for menu music)
  double _gameBackgroundVolume = AppConfig.gameBackgroundMusicDefaultVolume; // Lower volume for game background music
  double _soundVolume = AppConfig.soundEffectsMaxVolume; // Start at max, player can adjust down
  String? _currentMusicPath; // Track what music is currently playing
  DateTime? _lastMusicStartTime; // Track when music was last started (to prevent immediate stops)
  Timer? _fadeTimer; // Timer for monitoring position and handling fade
  double? _targetVolume; // Target volume for current track (for fade in/out)
  Duration? _trackDuration; // Duration of current track
  bool _isFading = false; // Track if we're currently fading
  bool _wasPlayingBeforePause = false; // Track if music was playing before app was paused

  /// Initialize audio context to allow mixing with other sounds
  Future<void> _initAudioContext() async {
    try {
      // This config allows background music to mix with sound effects
      // and prevents the OS from stopping music when a new sound plays
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
        ).build(),
      );
    } catch (e) {
      print('⚠️ Error configuring audio context: $e');
      // Continue even if audio context setup fails
    }
  }

  /// Check if background music is enabled
  bool get isMusicEnabled => _isMusicEnabled;

  /// Check if sound effects are enabled
  bool get isSoundEnabled => _isSoundEnabled;

  /// Get current music volume (0.0 to 1.0)
  double get musicVolume => _musicVolume;

  /// Get current sound volume (0.0 to max configured in AppConfig)
  double get soundVolume => _soundVolume;
  
  /// Get maximum sound effects volume from config
  double get soundEffectsMaxVolume => AppConfig.soundEffectsMaxVolume;

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

  /// Set music volume (0.0 to 1.0) - affects menu music
  void setMusicVolume(double volume) {
    _musicVolume = volume.clamp(0.0, 1.0);
    // Update current player volume if menu music is playing
    if (_currentMusicPath != null && !_currentMusicPath!.contains('game_background')) {
      _backgroundMusicPlayer.setVolume(_musicVolume);
    }
  }

  /// Set game background music volume (0.0 to 1.0)
  void setGameBackgroundVolume(double volume) {
    _gameBackgroundVolume = volume.clamp(0.0, 1.0);
    // Update current player volume if game background music is playing
    if (_currentMusicPath != null && _currentMusicPath!.contains('game_background')) {
      _backgroundMusicPlayer.setVolume(_gameBackgroundVolume);
    }
  }

  /// Get game background music volume
  double get gameBackgroundVolume => _gameBackgroundVolume;

  /// Set sound effects volume (0.0 to max configured in AppConfig)
  void setSoundVolume(double volume) {
    _soundVolume = volume.clamp(0.0, AppConfig.soundEffectsMaxVolume);
    _soundEffectPlayer.setVolume(_soundVolume);
  }

  /// Play background music (looping)
  /// assetPath should be relative to assets/ directory (e.g., 'sound/game_menu.m4a')
  Future<void> playBackgroundMusic(String assetPath) async {
    if (!_isMusicEnabled) {
      print('🔇 Music is disabled, skipping: $assetPath');
      return;
    }
    
    // Check if we are already supposed to be playing this track
    if (_currentMusicPath == assetPath) {
      // Check the ACTUAL player state
      try {
        final playerState = await _backgroundMusicPlayer.state;
        if (playerState == PlayerState.playing) {
          // It is actually playing, so do nothing (seamless)
          return;
        } else {
          // It's the correct track but it stopped/paused (e.g., interrupted by sound effect).
          // RESUME instead of restart to keep the position!
          print('▶️ Resuming background music: $assetPath');
          try {
            await _backgroundMusicPlayer.resume();
            return;
          } catch (e) {
            // If resume fails, fall back to restart
            print('⚠️ Resume failed, restarting: $e');
            await _restartMusic(assetPath);
            return;
          }
        }
      } catch (e) {
        // If we can't check state, fall back to restart
        print('⚠️ Could not check player state, restarting: $e');
        await _restartMusic(assetPath);
        return;
      }
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
  
  /// Internal method to start/restart music from beginning
  Future<void> _restartMusic(String assetPath) async {
    // Stop any existing fade timer
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _isFading = false;
    
    // Determine volume based on which track is playing
    final volume = assetPath.contains('game_background') ? _gameBackgroundVolume : _musicVolume;
    _targetVolume = volume;
    
    // Configure for looping
    await _backgroundMusicPlayer.setReleaseMode(ReleaseMode.loop);
    await _backgroundMusicPlayer.setVolume(volume);
    
    print('🎵 Playing background music: $assetPath (volume: $volume)');
    await _backgroundMusicPlayer.play(AssetSource(assetPath));
    _currentMusicPath = assetPath; // Track what's playing
    _lastMusicStartTime = DateTime.now(); // Track when music started
    
    // Get track duration and start fade monitoring
    _startFadeMonitoring(assetPath, volume);
    
    print('🎵 Music playback started');
  }
  
  /// Start monitoring position for fade-out before loop
  void _startFadeMonitoring(String assetPath, double targetVolume) {
    _fadeTimer?.cancel();
    
    // Get duration after a short delay (to allow audio to load)
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        final duration = await _backgroundMusicPlayer.getDuration();
        if (duration != null) {
          _trackDuration = duration;
        }
      } catch (e) {
        print('⚠️ Could not get track duration: $e');
      }
    });
    
    // Monitor position every 100ms
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (_currentMusicPath != assetPath) {
        // Track changed, stop monitoring
        timer.cancel();
        _fadeTimer = null;
        return;
      }
      
      try {
        final position = await _backgroundMusicPlayer.getCurrentPosition();
        if (position == null || _trackDuration == null) return;
        
        final timeRemaining = _trackDuration! - position;
        const fadeDuration = Duration(seconds: 2); // 2 second fade
        
        // If we're within fade duration of the end, start fading out
        if (timeRemaining <= fadeDuration && !_isFading) {
          _isFading = true;
          _fadeOut(fadeDuration, targetVolume);
        }
        // If position resets (looped back to near 0), fade back in
        else if (position.inMilliseconds < 500 && _isFading) {
          _isFading = false;
          _fadeIn(fadeDuration, _targetVolume ?? targetVolume);
        }
      } catch (e) {
        // Ignore errors in monitoring
      }
    });
  }
  
  /// Fade out volume over the specified duration
  Future<void> _fadeOut(Duration duration, double targetVolume) async {
    const steps = 20; // Number of fade steps
    final stepDuration = duration ~/ steps;
    final volumeStep = targetVolume / steps;
    
    for (int i = steps; i >= 0; i--) {
      if (_currentMusicPath == null) break; // Music was stopped
      
      final currentVolume = volumeStep * i;
      await _backgroundMusicPlayer.setVolume(currentVolume);
      await Future.delayed(stepDuration);
    }
  }
  
  /// Fade in volume over the specified duration
  Future<void> _fadeIn(Duration duration, double targetVolume) async {
    const steps = 20; // Number of fade steps
    final stepDuration = duration ~/ steps;
    final volumeStep = targetVolume / steps;
    
    for (int i = 0; i <= steps; i++) {
      if (_currentMusicPath == null) break; // Music was stopped
      
      final currentVolume = volumeStep * i;
      await _backgroundMusicPlayer.setVolume(currentVolume);
      await Future.delayed(stepDuration);
    }
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
        
        // Stop fade timer
        _fadeTimer?.cancel();
        _fadeTimer = null;
        _isFading = false;
        
        print('🛑 Stopping background music: $_currentMusicPath');
        await _backgroundMusicPlayer.stop();
        _currentMusicPath = null; // Clear current track
        _lastMusicStartTime = null; // Clear start time
        _trackDuration = null; // Clear duration
        _targetVolume = null; // Clear target volume
        print('✅ Background music stopped');
      } else {
        print('ℹ️ No background music to stop');
      }
    } catch (e) {
      print('❌ Error stopping background music: $e');
      _currentMusicPath = null; // Reset on error
      _lastMusicStartTime = null;
      _trackDuration = null;
      _targetVolume = null;
    }
  }

  /// Pause background music (e.g., when app goes to background)
  Future<void> pauseBackgroundMusic() async {
    try {
      if (_currentMusicPath != null) {
        // Check if music is actually playing before pausing
        final playerState = await _backgroundMusicPlayer.state;
        _wasPlayingBeforePause = (playerState == PlayerState.playing);
        
        if (_wasPlayingBeforePause) {
          print('⏸️ Pausing background music (app going to background)');
          await _backgroundMusicPlayer.pause();
        }
      }
    } catch (e) {
      print('Error pausing background music: $e');
      _wasPlayingBeforePause = false;
    }
  }

  /// Resume background music (e.g., when app returns to foreground)
  Future<void> resumeBackgroundMusic() async {
    if (!_isMusicEnabled) return;
    
    try {
      // Only resume if we have a track and it was playing before pause
      if (_currentMusicPath != null && _wasPlayingBeforePause) {
        print('▶️ Resuming background music (app returning to foreground)');
        await _backgroundMusicPlayer.resume();
        _wasPlayingBeforePause = false; // Reset flag
      }
    } catch (e) {
      print('Error resuming background music: $e');
      _wasPlayingBeforePause = false;
    }
  }

  /// Play a sound effect (one-shot)
  /// [volumeMultiplier] is an optional multiplier (0.0 to 1.0) to adjust volume for specific sounds
  Future<void> playSoundEffect(String assetPath, {double volumeMultiplier = 1.0}) async {
    if (!_isSoundEnabled) return;
    
    try {
      // Calculate final volume: player's sound volume * multiplier
      final finalVolume = (_soundVolume * volumeMultiplier).clamp(0.0, AppConfig.soundEffectsMaxVolume);
      
      await _soundEffectPlayer.setReleaseMode(ReleaseMode.release);
      await _soundEffectPlayer.setVolume(finalVolume);
      print('🔊 Playing sound effect: $assetPath (volume: $finalVolume = ${_soundVolume} * $volumeMultiplier)');
      await _soundEffectPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('❌ Error playing sound effect ($assetPath): $e');
    }
  }

  /// Play button click sound
  Future<void> playButtonSound() async {
    await playSoundEffect('sound/button.m4a');
  }

  /// Play coin collect sound (uses volume multiplier from config)
  Future<void> playCoinCollectSound() async {
    await playSoundEffect('sound/coin_collect.m4a', volumeMultiplier: AppConfig.coinCollectSoundVolumeMultiplier);
  }

  /// Play truck sound (uses volume multiplier from config)
  Future<void> playTruckSound() async {
    await playSoundEffect('sound/truck.mp3', volumeMultiplier: AppConfig.truckSoundVolumeMultiplier);
  }

  /// Dispose resources
  void dispose() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _backgroundMusicPlayer.dispose();
    _soundEffectPlayer.dispose();
  }
}

