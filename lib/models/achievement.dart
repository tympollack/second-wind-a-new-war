class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      isUnlocked: json['is_unlocked'] as bool? ?? false,
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.parse(json['unlocked_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon,
        'is_unlocked': isUnlocked,
        'unlocked_at': unlockedAt?.toIso8601String(),
      };
}

class AchievementDefinitions {
  static const List<Achievement> all = [
    Achievement(
      id: 'first_blood',
      name: 'First Blood',
      description: 'Win your first match',
      icon: '\u2694',
    ),
    Achievement(
      id: 'war_veteran',
      name: 'War Veteran',
      description: 'Win 10 matches',
      icon: '\u{1F3C5}',
    ),
    Achievement(
      id: 'war_hero',
      name: 'War Hero',
      description: 'Win 50 matches',
      icon: '\u{1F3C6}',
    ),
    Achievement(
      id: 'second_wind_survivor',
      name: 'Second Wind Survivor',
      description: 'Win a game after triggering Second Wind',
      icon: '\u{1F4A8}',
    ),
    Achievement(
      id: 'musketeer_master',
      name: 'Musketeer Master',
      description: 'Win a game with a Musketeer card as the final battle card',
      icon: '\u{1F5E1}',
    ),
    Achievement(
      id: 'trump_domination',
      name: 'Trump Domination',
      description: 'Win 5 rounds in a row using Trump cards',
      icon: '\u{1F451}',
    ),
    Achievement(
      id: 'joker_wild',
      name: 'Joker Wild',
      description: 'Win a round with a Joker card',
      icon: '\u{1F0CF}',
    ),
    Achievement(
      id: 'double_war',
      name: 'Double War',
      description: 'Trigger a War within a War',
      icon: '\u{1F525}',
    ),
    Achievement(
      id: 'triple_war',
      name: 'Triple War',
      description: 'Trigger three consecutive Wars in a single round',
      icon: '\u{1F30B}',
    ),
    Achievement(
      id: 'war_of_attrition',
      name: 'War of Attrition',
      description: 'Have 4 cards removed from the game via War',
      icon: '\u{1F480}',
    ),
    Achievement(
      id: 'perfect_game',
      name: 'Perfect Game',
      description: 'Win without ever going to War',
      icon: '\u{2B50}',
    ),
    Achievement(
      id: 'comeback_kid',
      name: 'Comeback Kid',
      description: 'Win after being down to 5 or fewer cards',
      icon: '\u{1F4AA}',
    ),
    Achievement(
      id: 'speed_demon',
      name: 'Speed Demon',
      description: 'Win a game in under 2 minutes',
      icon: '\u26A1',
    ),
    Achievement(
      id: 'war_monger',
      name: 'War Monger',
      description: 'Trigger 10 Wars in a single game',
      icon: '\u{1F4A3}',
    ),
    Achievement(
      id: 'card_collector',
      name: 'Card Collector',
      description: 'Hold 40 or more cards at once',
      icon: '\u{1F0A1}',
    ),
    Achievement(
      id: 'joker_clash',
      name: 'Joker Clash',
      description: 'Both players play Jokers simultaneously',
      icon: '\u26A1',
    ),
    Achievement(
      id: 'lucky_streak',
      name: 'Lucky Streak',
      description: 'Win 10 rounds in a row',
      icon: '\u{1F340}',
    ),
    Achievement(
      id: 'underdog',
      name: 'Underdog',
      description: 'Win after opponent triggered Second Wind',
      icon: '\u{1F43A}',
    ),
    Achievement(
      id: 'flawless_victory',
      name: 'Flawless Victory',
      description: 'Win with all 54 cards in your deck',
      icon: '\u{1F48E}',
    ),
    Achievement(
      id: 'social_butterfly',
      name: 'Social Butterfly',
      description: 'Play 5 different opponents',
      icon: '\u{1F98B}',
    ),
  ];
}
