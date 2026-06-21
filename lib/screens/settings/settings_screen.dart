import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/metal_panel.dart';
import '../../widgets/military_button.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  String _selectedCardBack = 'evolution_matrix';
  bool _soundEnabled = true;
  bool _musicEnabled = true;

  static const List<Map<String, String>> cardBacks = [
    {'id': 'evolution_matrix', 'name': 'The Evolution Matrix'},
    {'id': 'canyon_overlay', 'name': 'Canyon Overlay'},
    {'id': 'interwoven_hex', 'name': 'Interwoven Hex'},
    {'id': 'plate_armor_weave', 'name': 'Plate Armor Weave'},
    {'id': 'pulse_core', 'name': 'The Pulse Core'},
    {'id': 'data_node_array', 'name': 'Data Node Array'},
    {'id': 'armored_suite', 'name': 'The Armored Suite'},
    {'id': 'interlocking_treads', 'name': 'Interlocking Treads'},
    {'id': 'hangar_coil', 'name': 'Hangar Coil'},
    {'id': 'binary_conflict', 'name': 'Binary Conflict'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = ref.read(authProvider).displayName ?? '';
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;
    final data = await SupabaseService.getUser(userId);
    if (data != null && mounted) {
      setState(() {
        _selectedCardBack =
            data['selected_card_back'] as String? ?? 'evolution_matrix';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: const Text(
          'ARSENAL',
          style: TextStyle(
            fontFamily: 'RobotoCondensed',
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppTheme.metalLight,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTheme.metalGray),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Display name
            MetalPanel(
              title: 'COMMANDER PROFILE',
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(
                      fontFamily: 'RobotoCondensed',
                      color: AppTheme.metalLight,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'COMMANDER NAME',
                    ),
                  ),
                  const SizedBox(height: 12),
                  MilitaryButton(
                    label: 'UPDATE',
                    color: AppTheme.primaryCyan,
                    onPressed: () {
                      ref
                          .read(authProvider.notifier)
                          .updateDisplayName(_nameController.text.trim());
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Sound settings
            MetalPanel(
              title: 'AUDIO',
              child: Column(
                children: [
                  _buildToggle('SOUND EFFECTS', _soundEnabled, (v) {
                    setState(() => _soundEnabled = v);
                  }),
                  const SizedBox(height: 8),
                  _buildToggle('MUSIC', _musicEnabled, (v) {
                    setState(() => _musicEnabled = v);
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Card back selection
            MetalPanel(
              title: 'CARD BACK SKIN',
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: cardBacks.length,
                itemBuilder: (context, index) {
                  final back = cardBacks[index];
                  final isSelected = back['id'] == _selectedCardBack;
                  return GestureDetector(
                    onTap: () async {
                      setState(() => _selectedCardBack = back['id']!);
                      final userId = ref.read(authProvider).user?.id;
                      if (userId != null) {
                        await SupabaseService.updateCardBack(
                            userId, back['id']!);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryCyan
                              : AppTheme.metalGray.withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                        color: AppTheme.darkSurface,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryCyan
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.style,
                            color: isSelected
                                ? AppTheme.primaryCyan
                                : AppTheme.metalGray,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontFamily: 'RobotoCondensed',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? AppTheme.primaryCyan
                                  : AppTheme.metalGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'RobotoCondensed',
            fontSize: 13,
            color: AppTheme.metalGray,
            letterSpacing: 1,
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppTheme.primaryCyan,
        ),
      ],
    );
  }
}
