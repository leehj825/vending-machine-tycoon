import 'dart:math' as math;

import '../../config.dart';
import 'product.dart';

/// Goal types a daily contract can ask for
enum ContractGoal {
  /// Sell a given number of units of one specific product
  sellProduct,

  /// Earn a given amount of revenue during the day
  earnRevenue,

  /// Sell a given number of units across all machines and products
  sellUnits,
}

/// A time limited goal offered by a corporate client.
///
/// Contracts are issued every morning, track their own progress while the day
/// runs and pay out automatically the moment the goal is reached. Unfinished
/// contracts simply expire when the next day is issued.
class DailyContract {
  final String id;
  final ContractGoal goal;

  /// Only set for [ContractGoal.sellProduct]
  final Product? product;

  /// Units to sell, or dollars to earn for [ContractGoal.earnRevenue]
  final double target;

  /// Progress so far, in the same unit as [target]
  final double progress;

  final double rewardCash;
  final int rewardReputation;

  /// Day number this contract was issued on
  final int dayIssued;

  /// Whether the reward has already been paid out
  final bool isPaid;

  /// Whether the player already swapped this contract today
  final bool wasRerolled;

  const DailyContract({
    required this.id,
    required this.goal,
    required this.target,
    required this.rewardCash,
    required this.rewardReputation,
    required this.dayIssued,
    this.product,
    this.progress = 0.0,
    this.isPaid = false,
    this.wasRerolled = false,
  });

  bool get isComplete => progress >= target;

  /// Progress as a 0.0 - 1.0 fraction, safe for progress bars
  double get progressRatio {
    if (target <= 0) return 1.0;
    return (progress / target).clamp(0.0, 1.0);
  }

  /// Short client-facing title
  String get title {
    switch (goal) {
      case ContractGoal.sellProduct:
        return '${product?.name ?? 'Product'} Supply Deal';
      case ContractGoal.earnRevenue:
        return 'Revenue Target';
      case ContractGoal.sellUnits:
        return 'Volume Deal';
    }
  }

  /// One line description of what has to be done
  String get description {
    switch (goal) {
      case ContractGoal.sellProduct:
        return 'Sell ${target.round()} ${product?.name ?? 'items'} today';
      case ContractGoal.earnRevenue:
        return 'Earn \$${target.round()} in sales today';
      case ContractGoal.sellUnits:
        return 'Sell ${target.round()} items today';
    }
  }

  /// Progress formatted for display, e.g. "12 / 40" or "\$320 / \$800"
  String get progressLabel {
    if (goal == ContractGoal.earnRevenue) {
      return '\$${progress.round()} / \$${target.round()}';
    }
    return '${progress.round()} / ${target.round()}';
  }

  DailyContract copyWith({
    String? id,
    ContractGoal? goal,
    Product? product,
    double? target,
    double? progress,
    double? rewardCash,
    int? rewardReputation,
    int? dayIssued,
    bool? isPaid,
    bool? wasRerolled,
  }) {
    return DailyContract(
      id: id ?? this.id,
      goal: goal ?? this.goal,
      product: product ?? this.product,
      target: target ?? this.target,
      progress: progress ?? this.progress,
      rewardCash: rewardCash ?? this.rewardCash,
      rewardReputation: rewardReputation ?? this.rewardReputation,
      dayIssued: dayIssued ?? this.dayIssued,
      isPaid: isPaid ?? this.isPaid,
      wasRerolled: wasRerolled ?? this.wasRerolled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'goal': goal.name,
      'product': product?.name,
      'target': target,
      'progress': progress,
      'rewardCash': rewardCash,
      'rewardReputation': rewardReputation,
      'dayIssued': dayIssued,
      'isPaid': isPaid,
      'wasRerolled': wasRerolled,
    };
  }

  factory DailyContract.fromJson(Map<String, dynamic> json) {
    final productName = json['product'] as String?;
    return DailyContract(
      id: json['id'] as String? ?? 'contract',
      goal: ContractGoal.values.firstWhere(
        (g) => g.name == json['goal'],
        orElse: () => ContractGoal.sellUnits,
      ),
      product: productName == null
          ? null
          : Product.values.firstWhere(
              // Product.name is the display name (see ProductExtension)
              (p) => p.name == productName,
              orElse: () => Product.soda,
            ),
      target: (json['target'] as num?)?.toDouble() ?? 1.0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      rewardCash: (json['rewardCash'] as num?)?.toDouble() ?? 0.0,
      rewardReputation: json['rewardReputation'] as int? ?? 0,
      dayIssued: json['dayIssued'] as int? ?? 1,
      isPaid: json['isPaid'] as bool? ?? false,
      wasRerolled: json['wasRerolled'] as bool? ?? false,
    );
  }
}

/// Builds the contracts offered on a given day.
///
/// Targets scale with how the empire is actually performing (recent revenue and
/// machine count) so early game contracts stay reachable and late game ones stay
/// meaningful.
class ContractGenerator {
  const ContractGenerator._();

  /// Generate a fresh set of contracts for [day].
  ///
  /// [recentDailyRevenue] is the average revenue of the last few days (0 when
  /// the player has no history yet) and [machineCount] the number of placed
  /// machines. [stockedProducts] biases product deals towards goods the player
  /// actually sells.
  static List<DailyContract> generateForDay({
    required int day,
    required math.Random random,
    required double recentDailyRevenue,
    required int machineCount,
    required List<Product> stockedProducts,
  }) {
    final contracts = <DailyContract>[];
    for (var i = 0; i < AppConfig.contractsPerDay; i++) {
      contracts.add(
        _generate(
          goal: ContractGoal.values[i % ContractGoal.values.length],
          day: day,
          index: i,
          random: random,
          recentDailyRevenue: recentDailyRevenue,
          machineCount: machineCount,
          stockedProducts: stockedProducts,
        ),
      );
    }
    return contracts;
  }

  /// Generate a single replacement contract (used by the reroll button).
  static DailyContract generateReplacement({
    required DailyContract previous,
    required int day,
    required math.Random random,
    required double recentDailyRevenue,
    required int machineCount,
    required List<Product> stockedProducts,
  }) {
    // Pick a goal other than the one being swapped out when possible
    final alternatives =
        ContractGoal.values.where((g) => g != previous.goal).toList();
    final goal = alternatives[random.nextInt(alternatives.length)];

    return _generate(
      goal: goal,
      day: day,
      index: random.nextInt(1000),
      random: random,
      recentDailyRevenue: recentDailyRevenue,
      machineCount: machineCount,
      stockedProducts: stockedProducts,
    ).copyWith(wasRerolled: true);
  }

  static DailyContract _generate({
    required ContractGoal goal,
    required int day,
    required int index,
    required math.Random random,
    required double recentDailyRevenue,
    required int machineCount,
    required List<Product> stockedProducts,
  }) {
    // Estimated daily revenue to scale targets against. Machines that were only
    // just placed have no history, so fall back to a per machine estimate.
    final estimatedRevenue = math.max(
      AppConfig.contractMinDailyRevenueEstimate,
      math.max(
        recentDailyRevenue,
        machineCount * AppConfig.contractRevenuePerMachineEstimate,
      ),
    );

    // 0.9x - 1.1x so two days never feel identical
    final variance = 0.9 + random.nextDouble() * 0.2;
    final id = 'c${day}_${index}_${random.nextInt(100000)}';

    switch (goal) {
      case ContractGoal.earnRevenue:
        final target =
            _roundTo(estimatedRevenue * AppConfig.contractRevenueShare * variance, 50);
        return DailyContract(
          id: id,
          goal: goal,
          target: target,
          rewardCash: _roundTo(target * AppConfig.contractRewardRate, 10),
          rewardReputation: AppConfig.contractRewardReputation,
          dayIssued: day,
        );

      case ContractGoal.sellProduct:
        final pool = stockedProducts.isNotEmpty
            ? stockedProducts
            : const [Product.soda, Product.chips, Product.coffee];
        final product = pool[random.nextInt(pool.length)];
        final revenueSlice = estimatedRevenue * AppConfig.contractProductRevenueShare;
        final target = math.max(
          AppConfig.contractMinProductUnits.toDouble(),
          _roundTo(revenueSlice * variance / product.basePrice, 5),
        );
        return DailyContract(
          id: id,
          goal: goal,
          product: product,
          target: target,
          rewardCash: _roundTo(
            target * product.basePrice * AppConfig.contractProductRewardRate,
            10,
          ),
          rewardReputation: AppConfig.contractRewardReputation,
          dayIssued: day,
        );

      case ContractGoal.sellUnits:
        // Average item price across the catalogue keeps unit goals sane
        final averagePrice = Product.values
                .map((p) => p.basePrice)
                .reduce((a, b) => a + b) /
            Product.values.length;
        final revenueSlice = estimatedRevenue * AppConfig.contractUnitsRevenueShare;
        final target = math.max(
          AppConfig.contractMinTotalUnits.toDouble(),
          _roundTo(revenueSlice * variance / averagePrice, 5),
        );
        return DailyContract(
          id: id,
          goal: goal,
          target: target,
          rewardCash: _roundTo(
            target * averagePrice * AppConfig.contractProductRewardRate,
            10,
          ),
          rewardReputation: AppConfig.contractRewardReputation,
          dayIssued: day,
        );
    }
  }

  /// Round [value] up to the nearest [step] so targets read as clean numbers
  static double _roundTo(double value, int step) {
    if (step <= 0) return value;
    return (value / step).ceil() * step.toDouble();
  }
}
