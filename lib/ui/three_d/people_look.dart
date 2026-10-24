import 'dart:math' as math;
import 'dart:ui' show Color;

/// How one person looks: the colour of each part of the figure.
class PersonLook {
  const PersonLook({
    required this.shirt,
    required this.pants,
    required this.skin,
    required this.hair,
    this.hat,
    this.bag,
  });

  final Color shirt;
  final Color pants;
  final Color skin;
  final Color hair;

  /// A hat over the hair, or null for bare hair.
  final Color? hat;

  /// A backpack on the back, or null for none.
  final Color? bag;
}

const _shirts = [
  Color(0xFF3949AB), Color(0xFFD81B60), Color(0xFF43A047), Color(0xFFFB8C00),
  Color(0xFF8E24AA), Color(0xFF00897B), Color(0xFFE53935), Color(0xFFFDD835),
  Color(0xFF6D4C41), Color(0xFF546E7A), Color(0xFFEC407A), Color(0xFF7CB342),
];

const _pants = [
  Color(0xFF263238), Color(0xFF1565C0), Color(0xFF5D4037), Color(0xFF455A64),
  Color(0xFF6D6D6D), Color(0xFF4E342E), Color(0xFF283593), Color(0xFFBCAAA4),
];

const _skins = [
  Color(0xFFF6D5B0), Color(0xFFE2B88E), Color(0xFFC68642), Color(0xFF8D5524),
  Color(0xFF5C3A21),
];

const _hairs = [
  Color(0xFF1B1B1B), Color(0xFF4E342E), Color(0xFF8D6E63), Color(0xFFD4A24C),
  Color(0xFFB71C1C), Color(0xFF9E9E9E), Color(0xFFEEEEEE),
];

const _hats = [
  Color(0xFFB79A52), Color(0xFF1E88E5), Color(0xFFFFEB3B), Color(0xFF2E7D32),
  Color(0xFFE53935),
];

const _bags = [
  Color(0xFF3E2723), Color(0xFF263238), Color(0xFF1B5E20), Color(0xFFF57C00),
];

/// The look of the person with [seed]. The same seed always gives the same look, so a
/// person keeps their clothes between frames. Neighbouring seeds differ in shirt colour.
PersonLook personLook(int seed) {
  final random = math.Random(seed * 7919 + 17);
  T pick<T>(List<T> options) => options[random.nextInt(options.length)];
  return PersonLook(
    // Each seed takes the next shirt in turn, so people near each other are never alike.
    shirt: _shirts[seed % _shirts.length],
    pants: pick(_pants),
    skin: pick(_skins),
    hair: pick(_hairs),
    hat: random.nextBool() ? pick(_hats) : null,
    bag: random.nextInt(3) == 0 ? pick(_bags) : null,
  );
}
