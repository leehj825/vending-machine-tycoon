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
  late double _soundVolumeMultiplier;
  late double _musicVolumeMultiplier;
  late SoundService _soundService;

  @override
  void initState() {
    super.initState();
    _soundService = SoundService();
    _soundVolumeMultiplier = _soundService.soundVolumeMultiplier;
    _musicVolumeMultiplier = _soundService.musicVolumeMultiplier;
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
              // Music Volume Multiplier
              _buildVolumeControl(
                context: context,
                title: 'Music',
                value: _musicVolumeMultiplier,
                maxValue: 1.0,
                onChanged: (value) {
                  setState(() {
                    _musicVolumeMultiplier = value;
                  });
                  _soundService.setMusicVolumeMultiplier(value);
                },
              ),
              
              SizedBox(height: ScreenUtils.relativeSize(context, 0.04)),
              
              // Sound Volume Multiplier
              _buildVolumeControl(
                context: context,
                title: 'Sound',
                value: _soundVolumeMultiplier,
                maxValue: 1.0,
                onChanged: (value) {
                  setState(() {
                    _soundVolumeMultiplier = value;
                  });
                  _soundService.setSoundVolumeMultiplier(value);
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
    double maxValue = 1.0,
    required ValueChanged<double> onChanged,
  }) {
    // Calculate percentage relative to max value
    final percentage = ((value / maxValue) * 100).round();
    
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
            max: maxValue,
            divisions: (maxValue * 100).round(),
            label: '$percentage%',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

