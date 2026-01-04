/// Types of research available in the lab
enum ResearchType {
  turboTrucks,
  premiumBranding,
  efficientCooling,
}

/// Data class for research items
class ResearchData {
  final String id;
  final String name;
  final String description;
  final double cost;
  final double benefitValue;
  final ResearchType type;

  const ResearchData({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.benefitValue,
    required this.type,
  });

  /// All available research items
  static const List<ResearchData> allResearch = [
    ResearchData(
      id: 'turboTrucks',
      type: ResearchType.turboTrucks,
      name: 'Turbo Logistics',
      description: 'Trucks move 25% faster.',
      cost: 2000.0,
      benefitValue: 1.25,
    ),
    ResearchData(
      id: 'premiumBranding',
      type: ResearchType.premiumBranding,
      name: 'Premium Branding',
      description: 'Increase product prices by 10% without losing customers.',
      cost: 5000.0,
      benefitValue: 1.10,
    ),
    ResearchData(
      id: 'efficientCooling',
      type: ResearchType.efficientCooling,
      name: 'Efficient Cooling',
      description: 'Reduces spoilage rate by 50%.',
      cost: 3000.0,
      benefitValue: 0.5,
    ),
  ];

  /// Get research data by type
  static ResearchData getByType(ResearchType type) {
    return allResearch.firstWhere((r) => r.type == type);
  }
}
