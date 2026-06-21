import 'dart:math';

class BotService {
  static const botUserId = '00000000-0000-0000-0000-000000000b07';

  static final _random = Random();

  static final _prefixes = [
    'Shadow', 'Iron', 'Steel', 'Storm', 'Ghost', 'Frost', 'Blaze', 'Crimson',
    'Dark', 'Silent', 'Thunder', 'Night', 'Grim', 'Phantom', 'Viper', 'Rogue',
    'Silver', 'Cobra', 'Hawk', 'Wolf', 'Fox', 'Raven', 'Eagle', 'Dagger',
    'Blade', 'Spartan', 'Titan', 'Apex', 'Nova', 'Reaper',
  ];

  static final _suffixes = [
    'Commander', 'Captain', 'Warden', 'Sentinel', 'Guardian', 'Knight',
    'Striker', 'Hunter', 'Ranger', 'Pilot', 'Vanguard', 'Marshal',
    'Enforcer', 'Operative', 'Tactician', 'Specialist', 'Officer', 'Agent',
  ];

  static String generateBotName() {
    final prefix = _prefixes[_random.nextInt(_prefixes.length)];
    final suffix = _suffixes[_random.nextInt(_suffixes.length)];
    final num = _random.nextInt(99) + 1;
    return '${prefix}_$suffix$num';
  }
}
