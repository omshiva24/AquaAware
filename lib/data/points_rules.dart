/// How points are earned, in one place, so rules are easy to explain to
/// students and impossible to drift between screens.
abstract final class PointRules {
  static const moduleCompleted = 20;
  static const perCorrectAnswer = 10; // only for improvement over your best
  static const sortGame = 20;
  static const activityCheckIn = 10;
  static const pickupHandedOver = 15;
  static const waterTargetBonus = 5; // Q12, once per school day
  static const maxClaimsPerDay = 3; // Q8 fraud guard

  /// Fraud guards for self-reported pickups: a handover can't be confirmed
  /// the moment it is requested, and only a few per day earn points.
  static const minPickupWait = Duration(minutes: 2);
  static const maxRewardedPickupsPerDay = 2;
}

class EcoLevel {
  const EcoLevel(this.name, this.minPoints, this.meaning);
  final String name;
  final int minPoints;
  final String meaning;
}

abstract final class EcoLevels {
  static const all = <EcoLevel>[
    EcoLevel('Droplet', 0, 'Every reservoir starts with one drop.'),
    EcoLevel('Stream', 100, 'Your actions are starting to flow.'),
    EcoLevel('River', 250, 'You carry others along with you.'),
    EcoLevel('Lake', 500, 'A steady store your school can rely on.'),
    EcoLevel('Ocean Guardian', 1000, 'You protect the whole coast.'),
  ];

  static EcoLevel of(int points) {
    var current = all.first;
    for (final l in all) {
      if (points >= l.minPoints) current = l;
    }
    return current;
  }

  static EcoLevel? next(int points) {
    for (final l in all) {
      if (l.minPoints > points) return l;
    }
    return null;
  }

  /// 0–1 progress from the current level to the next (1.0 at the top level).
  static double progress(int points) {
    final cur = of(points);
    final nxt = next(points);
    if (nxt == null) return 1;
    return ((points - cur.minPoints) / (nxt.minPoints - cur.minPoints)).clamp(0.0, 1.0);
  }
}
