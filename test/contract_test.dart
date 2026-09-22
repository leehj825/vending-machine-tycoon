import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vending_empire/config.dart';
import 'package:vending_empire/simulation/models/contract.dart';
import 'package:vending_empire/simulation/models/product.dart';

void main() {
  group('ContractGenerator', () {
    test('issues one contract of every goal type', () {
      final contracts = ContractGenerator.generateForDay(
        day: 1,
        random: math.Random(42),
        recentDailyRevenue: 0.0,
        machineCount: 0,
        stockedProducts: const [],
      );

      expect(contracts.length, AppConfig.contractsPerDay);
      expect(
        contracts.map((c) => c.goal).toSet(),
        ContractGoal.values.toSet(),
      );
    });

    test('day one targets stay reachable without revenue history', () {
      final contracts = ContractGenerator.generateForDay(
        day: 1,
        random: math.Random(7),
        recentDailyRevenue: 0.0,
        machineCount: 1,
        stockedProducts: const [Product.soda],
      );

      final revenueContract =
          contracts.firstWhere((c) => c.goal == ContractGoal.earnRevenue);
      // Scaled off the minimum revenue estimate, not an empty history
      expect(revenueContract.target, greaterThan(0));
      expect(
        revenueContract.target,
        lessThanOrEqualTo(AppConfig.contractMinDailyRevenueEstimate),
      );

      final productContract =
          contracts.firstWhere((c) => c.goal == ContractGoal.sellProduct);
      expect(productContract.product, Product.soda);
      expect(
        productContract.target,
        greaterThanOrEqualTo(AppConfig.contractMinProductUnits.toDouble()),
      );
    });

    test('targets scale up with recent revenue', () {
      final small = ContractGenerator.generateForDay(
        day: 2,
        random: math.Random(1),
        recentDailyRevenue: 500.0,
        machineCount: 1,
        stockedProducts: const [Product.soda],
      ).firstWhere((c) => c.goal == ContractGoal.earnRevenue);

      final large = ContractGenerator.generateForDay(
        day: 2,
        random: math.Random(1),
        recentDailyRevenue: 5000.0,
        machineCount: 10,
        stockedProducts: const [Product.soda],
      ).firstWhere((c) => c.goal == ContractGoal.earnRevenue);

      expect(large.target, greaterThan(small.target));
      expect(large.rewardCash, greaterThan(small.rewardCash));
    });

    test('product deals only ask for goods the player stocks', () {
      for (var seed = 0; seed < 20; seed++) {
        final contract = ContractGenerator.generateForDay(
          day: 3,
          random: math.Random(seed),
          recentDailyRevenue: 1000.0,
          machineCount: 3,
          stockedProducts: const [Product.coffee, Product.chips],
        ).firstWhere((c) => c.goal == ContractGoal.sellProduct);

        expect(
          contract.product,
          anyOf(Product.coffee, Product.chips),
          reason: 'seed $seed picked an unstocked product',
        );
      }
    });

    test('a replacement swaps the goal type and is marked as rerolled', () {
      final original = ContractGenerator.generateForDay(
        day: 4,
        random: math.Random(3),
        recentDailyRevenue: 800.0,
        machineCount: 2,
        stockedProducts: const [Product.soda],
      ).first;

      final replacement = ContractGenerator.generateReplacement(
        previous: original,
        day: 4,
        random: math.Random(3),
        recentDailyRevenue: 800.0,
        machineCount: 2,
        stockedProducts: const [Product.soda],
      );

      expect(replacement.goal, isNot(original.goal));
      expect(replacement.wasRerolled, isTrue);
      expect(replacement.isPaid, isFalse);
      expect(replacement.progress, 0.0);
    });
  });

  group('DailyContract', () {
    const contract = DailyContract(
      id: 'c1',
      goal: ContractGoal.sellUnits,
      target: 20,
      rewardCash: 100,
      rewardReputation: 15,
      dayIssued: 1,
    );

    test('completes once progress reaches the target', () {
      expect(contract.isComplete, isFalse);
      expect(contract.copyWith(progress: 19).isComplete, isFalse);
      expect(contract.copyWith(progress: 20).isComplete, isTrue);
      expect(contract.copyWith(progress: 25).isComplete, isTrue);
    });

    test('progress ratio never leaves the 0..1 range', () {
      expect(contract.progressRatio, 0.0);
      expect(contract.copyWith(progress: 10).progressRatio, 0.5);
      expect(contract.copyWith(progress: 999).progressRatio, 1.0);
    });

    test('revenue goals are labelled in dollars', () {
      final revenue = contract
          .copyWith(goal: ContractGoal.earnRevenue, target: 500, progress: 250);
      expect(revenue.progressLabel, '\$250 / \$500');
      expect(contract.copyWith(progress: 5).progressLabel, '5 / 20');
    });

    test('survives a JSON round trip', () {
      final original = contract.copyWith(
        goal: ContractGoal.sellProduct,
        product: Product.coffee,
        progress: 7,
        isPaid: true,
        wasRerolled: true,
      );

      final restored = DailyContract.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.goal, original.goal);
      expect(restored.product, Product.coffee);
      expect(restored.target, original.target);
      expect(restored.progress, original.progress);
      expect(restored.rewardCash, original.rewardCash);
      expect(restored.rewardReputation, original.rewardReputation);
      expect(restored.dayIssued, original.dayIssued);
      expect(restored.isPaid, isTrue);
      expect(restored.wasRerolled, isTrue);
    });

    test('a contract without a product round trips too', () {
      final restored = DailyContract.fromJson(contract.toJson());
      expect(restored.product, isNull);
      expect(restored.goal, ContractGoal.sellUnits);
    });
  });
}
