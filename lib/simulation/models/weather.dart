/// Weather types for the dynamic weather system
enum WeatherType {
  sunny,
  cloudy,
  rainy,
  stormy,
}

extension WeatherTypeExtension on WeatherType {
  /// Display name for the weather type
  String get name {
    switch (this) {
      case WeatherType.sunny:
        return 'Sunny';
      case WeatherType.cloudy:
        return 'Cloudy';
      case WeatherType.rainy:
        return 'Rainy';
      case WeatherType.stormy:
        return 'Stormy';
    }
  }
}
