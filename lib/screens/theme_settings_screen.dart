import 'package:flutter/material.dart';

import '../app_theme.dart';
// import '../services/notification_service.dart';

class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  TimeOfDay? _reminderTime;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReminderTime();
  }

  Future<void> _loadReminderTime() async {
    // final time = await NotificationService.getDailyReminderTime();
    if (!mounted) return;
    setState(() {
      _reminderTime = null;
      _loading = false;
    });
  }

  Future<void> _pickReminderTime() async {
    final initial = _reminderTime ?? const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;

    // await NotificationService.setDailyReminderTime(picked);
    if (!mounted) return;
    setState(() => _reminderTime = picked);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Daily reminder set for ${picked.format(context)}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Theme Settings')),
      body: ValueListenableBuilder<AppThemePreset>(
        valueListenable: AppThemeController.notifier,
        builder: (context, currentTheme, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                ListTile(
                  leading: const Icon(Icons.alarm),
                  title: const Text('Daily meal reminder'),
                  subtitle: Text(_reminderTime?.format(context) ?? '08:00'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickReminderTime,
                ),
              const SizedBox(height: 14),
              const _ThemeOptionTile(
                preset: AppThemePreset.light,
                title: 'Light',
                subtitle: 'Clean white look',
                preview: Color(0xFF4F8BFF),
              ),
              const SizedBox(height: 12),
              const _ThemeOptionTile(
                preset: AppThemePreset.dark,
                title: 'Dark',
                subtitle: 'Night mode',
                preview: Color(0xFF7CCB92),
              ),
              const SizedBox(height: 12),
              const _ThemeOptionTile(
                preset: AppThemePreset.gray,
                title: 'Gray',
                subtitle: 'Soft neutral theme',
                preview: Color(0xFF7A7F87),
              ),
              const SizedBox(height: 12),
              const _ThemeOptionTile(
                preset: AppThemePreset.forest,
                title: 'Forest',
                subtitle: 'Default green theme',
                preview: Color(0xFF5E8B68),
              ),
              const SizedBox(height: 12),
              const _ThemeOptionTile(
                preset: AppThemePreset.ocean,
                title: 'Ocean',
                subtitle: 'Fresh blue style',
                preview: Color(0xFF2B7FFF),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final AppThemePreset preset;
  final String title;
  final String subtitle;
  final Color preview;

  const _ThemeOptionTile({
    required this.preset,
    required this.title,
    required this.subtitle,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemePreset>(
      valueListenable: AppThemeController.notifier,
      builder: (context, currentTheme, _) {
        final isSelected = currentTheme == preset;
        return InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () async {
            await AppThemeController.setTheme(preset);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title theme selected')),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45),
                width: isSelected ? 1.6 : 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: preview),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
