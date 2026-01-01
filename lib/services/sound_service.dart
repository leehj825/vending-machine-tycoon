import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

/// Service for managing game audio (sound effects and background music)
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  
  /// Public static getter for singleton instance
  static SoundService get instance => _instance;
  
  SoundService._internal() {
    _settingsLoadCompleter = Completer<void>();
    _initAudioContext();
    _loadVolumeSettings();
  }
  
  /// Load volume settings from SharedPreferences
  Future<void> _loadVolumeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load sound volume multiplier (default to config value if not set)
      final savedSoundVolume = prefs.getDouble('sound_volume_multiplier');
      if (savedSoundVolume != null) {
        _soundVolumeMultiplier = savedSoundVolume.clamp(0.0, 1.0);
      }
      
      // Load music volume multiplier (default to config value if not set)
      final savedMusicVolume = prefs.getDouble('music_volume_multiplier');
      if (savedMusicVolume != null) {
        _musicVolumeMultiplier = savedMusicVolume.clamp(0.0, 1.0);
      }
      
      print('🔊 Loaded volume settings: Sound=${_soundVolumeMultiplier.toStringAsFixed(2)}, Music=${_musicVolumeMultiplier.toStringAsFixed(2)}');
      
      // If music is already playing, update its volume with the loaded settings
      if (_currentMusicPath != null) {
        final baseVolume = _currentMusicPath!.contains('game_background') ? _gameBackgroundVolume : _musicVolume;
        final curvedMultiplier = _applyVolumeCurve(_musicVolumeMultiplier);
        final finalVolume = (baseVolume * curvedMultiplier).clamp(0.0, 1.0);
        _backgroundMusicPlayer.setVolume(finalVolume);
        _targetVolume = finalVolume; // Update target volume for fade
        print('🔊 Updated playing music volume to: ${finalVolume.toStringAsFixed(2)}');
      }
      
      // Complete the completer to signal that settings are loaded
      if (!_settingsLoadCompleter!.isCompleted) {
        _settingsLoadCompleter!.complete();
      }
    } catch (e) {
      print('⚠️ Error loading volume settings: $e');
      // Continue with default values if loading fails
      // Complete the completer even on error so music can still play
      if (_settingsLoadCompleter != null && !_settingsLoadCompleter!.isCompleted) {
        _settingsLoadCompleter!.complete();
      }
    }
  }
  
  /// Wait for volume settings to be loaded (used before playing music)
  Future<void> _ensureSettingsLoaded() async {
    if (_settingsLoadCompleter != null && !_settingsLoadCompleter!.isCompleted) {
      await _settingsLoadCompleter!.future;
    }
  }
  
  /// Save volume settings to SharedPreferences
  Future<void> _saveVolumeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('sound_volume_multiplier', _soundVolumeMultiplier);
      await prefs.setDouble('music_volume_multiplier', _musicVolumeMultiplier);
      print('💾 Saved volume settings: Sound=${_soundVolumeMultiplier.toStringAsFixed(2)}, Music=${_musicVolumeMultiplier.toStringAsFixed(2)}');
    } catch (e) {
      print('⚠️ Error saving volume settings: $e');
    }
  }

  final AudioPlayer _backgroundMusicPlayer = AudioPlayer();
  final AudioPlayer _soundEffectPlayer = AudioPlayer();
  final AudioPlayer _truckSoundPlayer = AudioPlayer(); // Separate player for truck sound to enable fade out
  
  bool _isMusicEnabled = true;
  bool _isSoundEnabled = true;
  bool _isMusicOperationInProgress = false; // Prevent concurrent music operations
  double _musicVolume = AppConfig.menuMusicVolume; // Base music volume (used for menu music)
  double _gameBackgroundVolume = AppConfig.gameBackgroundMusicVolume; // Lower volume for game background music
  double _soundVolume = 1.0; // Player sound volume (0.0 to 1.0)
  double _soundVolumeMultiplier = AppConfig.soundVolumeMultiplier; // Overall sound effects multiplier (player adjustable)
  double _musicVolumeMultiplier = AppConfig.musicVolumeMultiplier; // Overall music multiplier (player adjustable)
  String? _currentMusicPath; // Track what music is currently playing
  DateTime? _lastMusicStartTime; // Track when music was last started (to prevent immediate stops)
  Timer? _fadeTimer; // Timer for monitoring position and handling fade
  double? _targetVolume; // Target volume for current track (for fade in/out)
  Duration? _trackDuration; // Duration of current track
  bool _isFading = false; // Track if we're currently fading
  bool _wasPlayingBeforePause = false; // Track if music was playing before app was paused
  Completer<void>? _settingsLoadCompleter; // Completer to track when settings are loaded

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
  
  
  /// Get current sound volume multiplier (0.0 to 1.0)
  double get soundVolumeMultiplier => _soundVolumeMultiplier;
  
  /// Get current music volume multiplier (0.0 to 1.0)
  double get musicVolumeMultiplier => _musicVolumeMultiplier;

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
  /// Note: This should only be called from config initialization
  /// Menu music volume is controlled via config.dart only
  void setMusicVolume(double volume) {
    _musicVolume = volume.clamp(0.0, 1.0);
    // Update current player volume if menu music is playing (apply music multiplier)
    if (_currentMusicPath != null && !_currentMusicPath!.contains('game_background')) {
      final curvedMultiplier = _applyVolumeCurve(_musicVolumeMultiplier);
      final finalVolume = (_musicVolume * curvedMultiplier).clamp(0.0, 1.0);
      _backgroundMusicPlayer.setVolume(finalVolume);
      _targetVolume = finalVolume; // Update target volume for fade
    }
  }

  /// Set game background music volume (0.0 to 1.0)
  /// Note: This should only be called from config initialization
  /// Game background music volume is controlled via config.dart only
  void setGameBackgroundVolume(double volume) {
    _gameBackgroundVolume = volume.clamp(0.0, 1.0);
    // Update current player volume if game background music is playing (apply music multiplier)
    if (_currentMusicPath != null && _currentMusicPath!.contains('game_background')) {
      final curvedMultiplier = _applyVolumeCurve(_musicVolumeMultiplier);
      final finalVolume = (_gameBackgroundVolume * curvedMultiplier).clamp(0.0, 1.0);
      _backgroundMusicPlayer.setVolume(finalVolume);
      _targetVolume = finalVolume; // Update target volume for fade
    }
  }

  /// Get game background music volume
  double get gameBackgroundVolume => _gameBackgroundVolume;

  /// Set sound effects volume (0.0 to 1.0)
  void setSoundVolume(double volume) {
    _soundVolume = volume.clamp(0.0, 1.0);
    _soundEffectPlayer.setVolume(_soundVolume);
  }
  
  /// Set sound volume multiplier (0.0 to 1.0)
  /// This multiplier applies to all sound effects
  void setSoundVolumeMultiplier(double multiplier) {
    _soundVolumeMultiplier = multiplier.clamp(0.0, 1.0);
    _saveVolumeSettings(); // Save to SharedPreferences
  }
  
  /// Set music volume multiplier (0.0 to 1.0)
  /// This multiplier applies to all background music
  void setMusicVolumeMultiplier(double multiplier) {
    _musicVolumeMultiplier = multiplier.clamp(0.0, 1.0);
    _saveVolumeSettings(); // Save to SharedPreferences
    // Update current music volume if music is playing
    if (_currentMusicPath != null) {
      final baseVolume = _currentMusicPath!.contains('game_background') ? _gameBackgroundVolume : _musicVolume;
      // Apply non-linear volume curve for more responsive adjustment
      final curvedMultiplier = _applyVolumeCurve(_musicVolumeMultiplier);
      final finalVolume = (baseVolume * curvedMultiplier).clamp(0.0, 1.0);
      _backgroundMusicPlayer.setVolume(finalVolume);
      _targetVolume = finalVolume; // Update target volume for fade
    }
  }

  /// Play background music (looping)
  /// assetPath should be relative to assets/ directory (e.g., 'sound/game_menu.m4a')
  Future<void> playBackgroundMusic(String assetPath) async {
    if (!_isMusicEnabled) {
      print('🔇 Music is disabled, skipping: $assetPath');
      return;
    }
    
    // Wait for volume settings to be loaded before playing music
    await _ensureSettingsLoaded();
    
    // Prevent concurrent play operations (but allow play even if stop is in progress)
    if (_isMusicOperationInProgress) {
      print('⚠️ Music operation already in progress, waiting...');
      // Wait a bit and retry (up to 3 times)
      for (int i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!_isMusicOperationInProgress) break;
      }
      if (_isMusicOperationInProgress) {
        print('⚠️ Music operation still in progress after wait, proceeding anyway to start new music');
        // Proceed anyway to allow starting new music even if previous operation is finishing
      }
    }
    
    _isMusicOperationInProgress = true;
    
    try {
      // Check if we are already supposed to be playing this track
      if (_currentMusicPath == assetPath) {
        // Check if it is actually playing
        bool isPlaying = false;
        try {
          final state = await _backgroundMusicPlayer.state;
          isPlaying = state == PlayerState.playing;
        } catch (_) {}

        if (isPlaying) {
          print('🎵 Music already playing: $assetPath');
          _isMusicOperationInProgress = false;
          return; // EXIT EARLY - DO NOT RESTART
        }

        print('🔄 Music path matches current but stopped, restarting: $assetPath');
        await _restartMusic(assetPath);
        _isMusicOperationInProgress = false;
        return;
      }
      
      // Stop any currently playing music first (only if different)
      if (_currentMusicPath != null && _currentMusicPath != assetPath) {
        print('🛑 Stopping current music: $_currentMusicPath');
        try {
          await _backgroundMusicPlayer.stop();
        } catch (e) {
          // Ignore errors if player is already stopped
          print('⚠️ Error stopping previous music (may already be stopped): $e');
        }
        // Small delay to ensure stop completes
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      await _restartMusic(assetPath);
      _isMusicOperationInProgress = false;
    } catch (e, stackTrace) {
      print('❌ Error playing background music ($assetPath): $e');
      print('Stack trace: $stackTrace');
      _currentMusicPath = null; // Reset on error
      _isMusicOperationInProgress = false;
    }
  }
  
  /// Internal method to start/restart music from beginning
  Future<void> _restartMusic(String assetPath) async {
    // Stop any existing fade timer
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _isFading = false;
    
    // Determine base volume based on which track is playing
    final baseVolume = assetPath.contains('game_background') ? _gameBackgroundVolume : _musicVolume;
    // Apply non-linear volume curve for more responsive adjustment
    final curvedMultiplier = _applyVolumeCurve(_musicVolumeMultiplier);
    // Apply overall music volume multiplier (player adjustable)
    final volume = (baseVolume * curvedMultiplier).clamp(0.0, 1.0);
    _targetVolume = volume;
    
    // Set the path and start time BEFORE any player operations to ensure protection is active immediately
    _currentMusicPath = assetPath; // Track what's playing
    _lastMusicStartTime = DateTime.now(); // Track when music started (set before play to ensure protection)
    
    try {
      // Always stop player first to ensure clean state and avoid duplicate response errors
      try {
        await _backgroundMusicPlayer.stop();
        // Small delay to ensure stop completes before starting new playback
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        // Ignore errors - player might already be stopped or disposed
        print('⚠️ Error stopping before restart (may already be stopped): $e');
      }
      
      // Configure for looping
      await _backgroundMusicPlayer.setReleaseMode(ReleaseMode.loop);
      // Start at 0 volume for fade in
      await _backgroundMusicPlayer.setVolume(0.0);
      
      print('🎵 Playing background music: $assetPath (target volume: $volume)');
      
      await _backgroundMusicPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('⚠️ Error starting playback: $e');
      // Reset on error
      _currentMusicPath = null;
      _lastMusicStartTime = null;
      rethrow;
    }
    
    // Fade in over 0.5 seconds
    const fadeInDuration = Duration(milliseconds: 500);
    _fadeIn(fadeInDuration, volume);
    _wasPlayingBeforePause = true; // Mark that music is now playing
    
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
        // 4 second fade out for both menu and game background music
        const fadeOutDuration = Duration(seconds: 4);
        
        // If we're within fade duration of the end, start fading out
        if (timeRemaining <= fadeOutDuration && !_isFading) {
          _isFading = true;
          _fadeOut(fadeOutDuration, targetVolume);
        }
        // If position resets (looped back to near 0), fade back in
        else if (position.inMilliseconds < 500 && _isFading) {
          _isFading = false;
          const fadeInDuration = Duration(milliseconds: 500); // 0.5 second fade in
          _fadeIn(fadeInDuration, _targetVolume ?? targetVolume);
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
  /// targetVolume should already have musicVolumeMultiplier applied
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
    // Prevent concurrent operations
    if (_isMusicOperationInProgress && !forceStop) {
      print('⚠️ Music operation in progress, skipping stop request (use forceStop=true to override)');
      return;
    }
    
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
        
        _isMusicOperationInProgress = true;
        
        // Stop fade timer
        _fadeTimer?.cancel();
        _fadeTimer = null;
        _isFading = false;
        
        print('🛑 Stopping background music: $_currentMusicPath');
        try {
          await _backgroundMusicPlayer.stop();
        } catch (e) {
          // Ignore errors if player is already stopped or disposed
          print('⚠️ Error stopping player (may already be stopped): $e');
        }
        _currentMusicPath = null; // Clear current track
        _lastMusicStartTime = null; // Clear start time
        _trackDuration = null; // Clear duration
        _targetVolume = null; // Clear target volume
        _wasPlayingBeforePause = false; // Clear playing state
        _isMusicOperationInProgress = false;
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
      _isMusicOperationInProgress = false;
    }
  }

  /// Stop background music (e.g., when app goes to background)
  Future<void> pauseBackgroundMusic() async {
    try {
      if (_currentMusicPath != null) {
        // Prevent pausing music that was just started (within last 3000ms)
        // This prevents race conditions when navigating between screens triggers lifecycle events
        // Use longer window for menu music since navigation can take time
        if (_lastMusicStartTime != null) {
          final timeSinceStart = DateTime.now().difference(_lastMusicStartTime!);
          if (timeSinceStart.inMilliseconds < 3000) {
            print('⚠️ Ignoring pause request - music was just started ${timeSinceStart.inMilliseconds}ms ago (protection window: 3000ms)');
            return;
          }
        }
        
        // Check if music is actually playing before stopping
        try {
          final playerState = await _backgroundMusicPlayer.state;
          _wasPlayingBeforePause = (playerState == PlayerState.playing);
        } catch (e) {
          // If we can't check state, assume it's not playing to avoid errors
          print('⚠️ Could not check player state: $e');
          _wasPlayingBeforePause = false;
          return;
        }
        
        if (_wasPlayingBeforePause) {
          print('⏸️ Stopping background music (app going to background): $_currentMusicPath');
          // Stop fade timer
          _fadeTimer?.cancel();
          _fadeTimer = null;
          _isFading = false;
          // Stop the music (don't clear _currentMusicPath so we know what to restart)
          try {
            await _backgroundMusicPlayer.stop();
          } catch (e) {
            // Ignore errors if player is already stopped or disposed
            print('⚠️ Error pausing player (may already be stopped): $e');
          }
        } else {
          print('ℹ️ Music not playing, nothing to stop');
          _wasPlayingBeforePause = false;
        }
      } else {
        _wasPlayingBeforePause = false;
      }
    } catch (e) {
      print('Error stopping background music: $e');
      _wasPlayingBeforePause = false;
    }
  }

  /// Restart background music from beginning (e.g., when app returns to foreground)
  Future<void> resumeBackgroundMusic() async {
    if (!_isMusicEnabled) {
      print('🔇 Music is disabled, not restarting');
      _wasPlayingBeforePause = false;
      return;
    }
    
    try {
      // Only restart if we have a track and it was playing before pause
      if (_currentMusicPath != null && _wasPlayingBeforePause) {
        print('🔄 Restarting background music from beginning (app returning to foreground): $_currentMusicPath');
        // Restart from beginning instead of resuming
        await playBackgroundMusic(_currentMusicPath!);
        _wasPlayingBeforePause = false; // Reset flag after restart
      } else {
        if (_currentMusicPath == null) {
          print('ℹ️ No music track to restart');
        } else if (!_wasPlayingBeforePause) {
          print('ℹ️ Music was not playing before pause, not restarting');
        }
      }
    } catch (e) {
      print('Error restarting background music: $e');
      _wasPlayingBeforePause = false;
    }
  }

  /// Apply non-linear volume curve for more responsive adjustment at higher percentages
  /// Uses power curve: volume^2.5 for more aggressive reduction at higher percentages
  /// This makes volume changes more noticeable at higher slider values
  double _applyVolumeCurve(double linearVolume) {
    if (linearVolume <= 0.0) return 0.0;
    if (linearVolume >= 1.0) return 1.0;
    
    // Use power curve: volume^2.5
    // This means:
    // - 100% slider = 100% volume
    // - 50% slider ≈ 18% volume (more responsive)
    // - 25% slider ≈ 3% volume
    // - 10% slider ≈ 0.3% volume
    // - 5% slider ≈ 0.06% volume (less responsive at low end)
    return linearVolume * linearVolume * math.sqrt(linearVolume);
  }

  /// Play a sound effect (one-shot)
  /// [volumeMultiplier] is an optional multiplier (0.0 to 1.0) to adjust volume for specific sounds
  Future<void> playSoundEffect(String assetPath, {double volumeMultiplier = 1.0}) async {
    if (!_isSoundEnabled) return;
    
    try {
      // Apply non-linear volume curve to the multiplier for more responsive adjustment
      final curvedMultiplier = _applyVolumeCurve(_soundVolumeMultiplier);
      
      // Calculate final volume: curved sound multiplier * individual sound volume
      final finalVolume = (curvedMultiplier * volumeMultiplier).clamp(0.0, 1.0);
      
      await _soundEffectPlayer.setReleaseMode(ReleaseMode.release);
      await _soundEffectPlayer.setVolume(finalVolume);
      print('🔊 Playing sound effect: $assetPath (volume: $finalVolume = curved($_soundVolumeMultiplier) * $volumeMultiplier)');
      await _soundEffectPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('❌ Error playing sound effect ($assetPath): $e');
    }
  }

  /// Play button click sound
  Future<void> playButtonSound() async {
    await playSoundEffect('sound/button.m4a');
  }

  /// Play coin collect sound (uses volume from config)
  Future<void> playCoinCollectSound() async {
    await playSoundEffect('sound/coin_collect.m4a', volumeMultiplier: AppConfig.moneySoundVolume);
  }

  /// Play truck sound (uses volume from config) with fade out
  Future<void> playTruckSound() async {
    if (!_isSoundEnabled) return;
    
    try {
      // Apply non-linear volume curve to the multiplier for more responsive adjustment
      final curvedMultiplier = _applyVolumeCurve(_soundVolumeMultiplier);
      
      // Calculate final volume: curved sound multiplier * individual sound volume
      final finalVolume = (curvedMultiplier * AppConfig.truckSoundVolume).clamp(0.0, 1.0);
      
      await _truckSoundPlayer.setReleaseMode(ReleaseMode.release);
      await _truckSoundPlayer.setVolume(finalVolume);
      print('🔊 Playing truck sound: sound/truck.m4a (volume: $finalVolume)');
      await _truckSoundPlayer.play(AssetSource('sound/truck.m4a'));
      
      // Start monitoring position to fade out 1 second before the end
      _startTruckSoundFadeMonitoring(finalVolume);
    } catch (e) {
      print('❌ Error playing truck sound: $e');
    }
  }
  
  /// Start monitoring truck sound position for fade-out
  void _startTruckSoundFadeMonitoring(double startVolume) {
    Duration? truckDuration;
    
    // Get duration after a short delay
    Future.delayed(const Duration(milliseconds: 100), () async {
      try {
        final duration = await _truckSoundPlayer.getDuration();
        if (duration != null) {
          truckDuration = duration;
        }
      } catch (e) {
        print('⚠️ Could not get truck sound duration: $e');
      }
    });
    
    // Monitor position every 50ms
    Timer.periodic(const Duration(milliseconds: 50), (timer) async {
      try {
        final position = await _truckSoundPlayer.getCurrentPosition();
        if (position == null || truckDuration == null) return;
        
        final timeRemaining = truckDuration! - position;
        const fadeOutDuration = Duration(seconds: 1);
        
        // If we're within 1 second of the end, start fading out
        if (timeRemaining <= fadeOutDuration) {
          timer.cancel();
          await _fadeOutTruckSound(fadeOutDuration, startVolume);
        }
        // If sound finished, cancel timer
        else if (position >= truckDuration!) {
          timer.cancel();
        }
      } catch (e) {
        timer.cancel();
      }
    });
  }
  
  /// Fade out truck sound over the specified duration
  Future<void> _fadeOutTruckSound(Duration duration, double startVolume) async {
    const steps = 20; // Number of fade steps
    final stepDuration = duration ~/ steps;
    final volumeStep = startVolume / steps;
    
    for (int i = steps; i >= 0; i--) {
      try {
        final currentVolume = volumeStep * i;
        await _truckSoundPlayer.setVolume(currentVolume);
        await Future.delayed(stepDuration);
      } catch (e) {
        // Sound might have finished, ignore errors
        break;
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _backgroundMusicPlayer.dispose();
    _soundEffectPlayer.dispose();
    _truckSoundPlayer.dispose();
  }
}

