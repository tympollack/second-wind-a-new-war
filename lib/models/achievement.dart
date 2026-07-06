/// The scope/tier of an achievement.
/// - [match]  = earned within a single match session (e.g. "First Blood" this game)
/// - [game]   = cumulative milestones across many matches (e.g. "Win 50 games")
/// - [player] = time/count-based personal goals / bounties (e.g. "Play today")
enum AchievementScope { match, game, player }

class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final AchievementScope scope;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.scope = AchievementScope.game,
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

    // ── MATCH achievements (earned within a single game session) ────
    Achievement(
      id: 'first_blood',
      name: 'First Blood',
      description: 'Win the very first round of a game',
      icon: '🩸',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'first_war',
      name: 'Trial by Fire',
      description: 'Survive the first War',
      icon: '⚔️',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'second_wind_receiver',
      name: 'Second Wind',
      description: 'Receive the reserve deck when your hand runs out',
      icon: '💨',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'second_wind_survivor',
      name: 'Phoenix Rising',
      description: 'Win a game after receiving the Second Wind',
      icon: '🦅',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'musketeer_master',
      name: 'Musketeer Master',
      description: 'Win a game with a Musketeer card as the final battle card',
      icon: '🗡️',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'trump_setter',
      name: 'Kingmaker',
      description: 'Your card helped set the Trump suit',
      icon: '👑',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'trump_win',
      name: 'Home Field',
      description: 'Win a round by Trump suit advantage',
      icon: '🏰',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'trump_domination',
      name: 'Trump Domination',
      description: 'Win 5 rounds in a row using Trump cards (in one game)',
      icon: '🥇',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'joker_wild',
      name: 'Wild Card',
      description: 'Win a round by playing a Joker',
      icon: '🃏',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'double_war',
      name: 'Double Trouble',
      description: 'Survive a War-within-a-War',
      icon: '⚔️⚔️',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'triple_war',
      name: 'Apocalypse',
      description: 'Survive three Wars in a chain',
      icon: '🌋',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'war_of_attrition',
      name: 'War of Attrition',
      description: 'Have 4 cards removed from the game via War',
      icon: '💀',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'perfect_game',
      name: 'Perfect Game',
      description: 'Win without ever going to War',
      icon: '⭐',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'comeback_kid',
      name: 'Comeback Kid',
      description: 'Win after being down to 5 or fewer cards',
      icon: '💪',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'cliffhanger',
      name: 'On the Edge',
      description: 'Win a round when you had only 1 card left',
      icon: '😰',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'speed_demon',
      name: 'Speed Demon',
      description: 'Win a game in under 20 rounds',
      icon: '⚡',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'war_machine',
      name: 'War Machine',
      description: 'Win 5 Wars in a single game',
      icon: '🤖',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'war_monger',
      name: 'War Monger',
      description: 'Trigger 10 Wars in a single game',
      icon: '💣',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'domination',
      name: 'Domination',
      description: 'Hold 30 or more cards at once',
      icon: '🏋️',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'supremacy',
      name: 'Supremacy',
      description: 'Hold 40 or more cards at once',
      icon: '👊',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'totality',
      name: 'Totality',
      description: 'Hold 50 or more cards at once',
      icon: '💯',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'joker_clash',
      name: 'Clash of Fools',
      description: 'Both players play Jokers simultaneously',
      icon: '🤡',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'lucky_streak',
      name: 'Lucky Streak',
      description: 'Win 10 rounds in a row',
      icon: '🍀',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'underdog',
      name: 'Underdog',
      description: 'Win after opponent triggered Second Wind',
      icon: '🐺',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'flawless_victory',
      name: 'Flawless Victory',
      description: 'Win with all 54 cards in your deck',
      icon: '💎',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'musk_creator',
      name: 'Musk Protocol',
      description: 'Your war created the Musk card value',
      icon: '🔥',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'musk_win',
      name: 'Unstoppable',
      description: 'Win a round with a Musk card',
      icon: '☠️',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'musk_vs_musk',
      name: 'Musk Collision',
      description: 'Both players play a Musk card simultaneously',
      icon: '💥',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'musk_destroyer',
      name: 'Power Vacuum',
      description: 'All four Musk-rank cards are destroyed in war',
      icon: '⚡',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'war_winner',
      name: 'Warlord',
      description: 'Win your first War',
      icon: '⚔️',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'ruthless',
      name: 'Ruthless',
      description: 'Win a War where the opponent played 0 face-down cards',
      icon: '😈',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'marathon',
      name: 'Marathon',
      description: 'Play 100 or more rounds in one game',
      icon: '🏃',
      scope: AchievementScope.match,
    ),
    Achievement(
      id: 'clean_sweep',
      name: 'Clean Sweep',
      description: 'Win without needing the Second Wind',
      icon: '✨',
      scope: AchievementScope.match,
    ),

    // ── GAME (cumulative cross-match) achievements ──────────────────
    Achievement(
      id: 'war_veteran',
      name: 'War Veteran',
      description: 'Win 10 matches',
      icon: '🏅',
      scope: AchievementScope.game,
    ),
    Achievement(
      id: 'war_hero',
      name: 'War Hero',
      description: 'Win 50 matches',
      icon: '🏆',
      scope: AchievementScope.game,
    ),
    Achievement(
      id: 'card_collector',
      name: 'Card Collector',
      description: 'Hold 40 or more cards in 5 different games',
      icon: '🎴',
      scope: AchievementScope.game,
    ),
    Achievement(
      id: 'social_butterfly',
      name: 'Social Butterfly',
      description: 'Play 5 different opponents',
      icon: '🦋',
      scope: AchievementScope.game,
    ),

    // ── PLAYER / BOUNTY achievements ────────────────────────────────
    Achievement(
      id: 'daily_mission',
      name: 'Daily Orders',
      description: 'Play at least 1 game today',
      icon: '📋',
      scope: AchievementScope.player,
    ),
    Achievement(
      id: 'veteran_player',
      name: 'Seasoned Commander',
      description: 'Play 250 total games',
      icon: '🎖️',
      scope: AchievementScope.player,
    ),
    Achievement(
      id: 'dedicated_player',
      name: 'Dedicated Soldier',
      description: 'Play 7 days in a row',
      icon: '📅',
      scope: AchievementScope.player,
    ),
  ];
}
