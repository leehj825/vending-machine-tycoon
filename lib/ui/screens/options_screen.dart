import 'package:flutter/material.dart';
import '../../services/sound_service.dart';
import '../utils/screen_utils.dart';

/// Options screen for adjusting game settings
class OptionsScreen extends StatefulWidget {
  const OptionsScreen({super.key});

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  late double _menuMusicVolume;
  late double _gameBackgroundVolume;
  late double _soundEffectsVolume;
  late SoundService _soundService;

  @override
  void initState() {
    super.initState();
    _soundService = SoundService();
    _menuMusicVolume = _soundService.musicVolume;
    _gameBackgroundVolume = _soundService.gameBackgroundVolume;
    _soundEffectsVolume = _soundService.soundVolume;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Options',
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(ScreenUtils.relativeSize(context, 0.04)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Menu Music Volume
              _buildVolumeControl(
                context: context,
                title: 'Menu Music Volume',
                value: _menuMusicVolume,
                onChanged: (value) {
                  setState(() {
                    _menuMusicVolume = value;
                  });
                  _soundService.setMusicVolume(value);
                },
              ),
              
              SizedBox(height: ScreenUtils.relativeSize(context, 0.04)),
              
              // Game Background Music Volume
              _buildVolumeControl(
                context: context,
                title: 'Game Background Music Volume',
                value: _gameBackgroundVolume,
                onChanged: (value) {
                  setState(() {
                    _gameBackgroundVolume = value;
                  });
                  _soundService.setGameBackgroundVolume(value);
                },
              ),
              
              SizedBox(height: ScreenUtils.relativeSize(context, 0.04)),
              
              // Sound Effects Volume
              _buildVolumeControl(
                context: context,
                title: 'Sound Effects Volume',
                value: _soundEffectsVolume,
                onChanged: (value) {
                  setState(() {
                    _soundEffectsVolume = value;
                  });
                  _soundService.setSoundVolume(value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeControl({
    required BuildContext context,
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final percentage = (value * 100).round();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: ScreenUtils.relativeFontSize(
                  context,
                  0.018,
                  min: 16,
                  max: 24,
                ),
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: ScreenUtils.relativeFontSize(
                  context,
                  0.016,
                  min: 14,
                  max: 20,
                ),
                fontWeight: FontWeight.w500,
                color: Colors.green[700],
              ),
            ),
          ],
        ),
        SizedBox(height: ScreenUtils.relativeSize(context, 0.015)),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.green,
            inactiveTrackColor: Colors.grey[300],
            thumbColor: Colors.green,
            overlayColor: Colors.green.withOpacity(0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            trackHeight: 6,
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            label: '$percentage%',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

