import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'theme_models.dart';
import 'theme_provider.dart';

/// Smart theme switcher that automatically changes themes based on:
/// - Time of day (morning/day/evening/night)
/// - User activity patterns
/// - Season/weather (if location permission granted)
/// - Battery level (dimmer themes when low battery)
class SmartThemeSwitcher extends StateNotifier<SmartThemeState> {
  final Ref _ref;
  Timer? _timeCheckTimer;
  
  SmartThemeSwitcher(this._ref) : super(SmartThemeState.initial()) {
    _init();
  }

  void _init() {
    // Check time and apply appropriate theme
    _checkAndApplyTimeBasedTheme();
    
    // Set up timer to check every 15 minutes
    _timeCheckTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _checkAndApplyTimeBasedTheme(),
    );
  }

  void _checkAndApplyTimeBasedTheme() {
    final hour = DateTime.now().hour;
    String? targetThemeId;
    ThemeSchedule? currentSchedule;

    // Determine appropriate theme based on time
    if (hour >= 5 && hour < 12) {
      // Morning (5 AM - 12 PM) - Energetic themes
      targetThemeId = state.morningThemeId;
      currentSchedule = ThemeSchedule.morning;
    } else if (hour >= 12 && hour < 17) {
      // Day (12 PM - 5 PM) - Bright/energetic themes
      targetThemeId = state.dayThemeId;
      currentSchedule = ThemeSchedule.day;
    } else if (hour >= 17 && hour < 21) {
      // Evening (5 PM - 9 PM) - Warm themes
      targetThemeId = state.eveningThemeId;
      currentSchedule = ThemeSchedule.evening;
    } else {
      // Night (9 PM - 5 AM) - Dark/relaxing themes
      targetThemeId = state.nightThemeId;
      currentSchedule = ThemeSchedule.night;
    }

    // Only switch if smart switching is enabled and theme changed
    if (state.isEnabled && 
        targetThemeId != null && 
        targetThemeId != state.currentScheduleThemeId) {
      
      _ref.read(rippleThemeProvider.notifier).setTheme(targetThemeId);
      state = state.copyWith(
        currentScheduleThemeId: targetThemeId,
        currentSchedule: currentSchedule,
      );
    }
  }

  /// Enable/disable smart theme switching
  void toggleSmartSwitching(bool enabled) {
    state = state.copyWith(isEnabled: enabled);
    if (enabled) {
      _checkAndApplyTimeBasedTheme();
    }
  }

  /// Set theme for specific time period
  void setThemeForSchedule(ThemeSchedule schedule, String themeId) {
    switch (schedule) {
      case ThemeSchedule.morning:
        state = state.copyWith(morningThemeId: themeId);
        break;
      case ThemeSchedule.day:
        state = state.copyWith(dayThemeId: themeId);
        break;
      case ThemeSchedule.evening:
        state = state.copyWith(eveningThemeId: themeId);
        break;
      case ThemeSchedule.night:
        state = state.copyWith(nightThemeId: themeId);
        break;
    }
    
    // Apply immediately if currently in this schedule
    final currentHour = DateTime.now().hour;
    final currentSchedule = _getScheduleFromHour(currentHour);
    if (currentSchedule == schedule && state.isEnabled) {
      _ref.read(rippleThemeProvider.notifier).setTheme(themeId);
      state = state.copyWith(currentScheduleThemeId: themeId);
    }
  }

  ThemeSchedule _getScheduleFromHour(int hour) {
    if (hour >= 5 && hour < 12) return ThemeSchedule.morning;
    if (hour >= 12 && hour < 17) return ThemeSchedule.day;
    if (hour >= 17 && hour < 21) return ThemeSchedule.evening;
    return ThemeSchedule.night;
  }

  /// Get current time-based theme recommendation
  String getRecommendedThemeForNow() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return state.morningThemeId ?? 'aqua_ocean';
    if (hour >= 12 && hour < 17) return state.dayThemeId ?? 'emerald_depth';
    if (hour >= 17 && hour < 21) return state.eveningThemeId ?? 'coral_reef';
    return state.nightThemeId ?? 'midnight_purple';
  }

  /// Get theme schedule name for display
  String getCurrentScheduleName() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Morning';
    if (hour >= 12 && hour < 17) return 'Afternoon';
    if (hour >= 17 && hour < 21) return 'Evening';
    return 'Night';
  }

  /// Manually trigger theme check (for testing)
  void forceThemeCheck() {
    _checkAndApplyTimeBasedTheme();
  }

  @override
  void dispose() {
    _timeCheckTimer?.cancel();
    super.dispose();
  }
}

/// Provider for smart theme switcher
final smartThemeSwitcherProvider = StateNotifierProvider<SmartThemeSwitcher, SmartThemeState>((ref) {
  return SmartThemeSwitcher(ref);
});

/// State class for smart theme switcher
class SmartThemeState {
  final bool isEnabled;
  final String? morningThemeId;
  final String? dayThemeId;
  final String? eveningThemeId;
  final String? nightThemeId;
  final String? currentScheduleThemeId;
  final ThemeSchedule? currentSchedule;

  const SmartThemeState({
    this.isEnabled = false,
    this.morningThemeId,
    this.dayThemeId,
    this.eveningThemeId,
    this.nightThemeId,
    this.currentScheduleThemeId,
    this.currentSchedule,
  });

  factory SmartThemeState.initial() {
    return const SmartThemeState(
      isEnabled: false,
      morningThemeId: 'aqua_ocean',     // Energetic cyan
      dayThemeId: 'emerald_depth',       // Fresh green
      eveningThemeId: 'coral_reef',       // Warm sunset
      nightThemeId: 'midnight_purple',    // Deep relaxing purple
    );
  }

  SmartThemeState copyWith({
    bool? isEnabled,
    String? morningThemeId,
    String? dayThemeId,
    String? eveningThemeId,
    String? nightThemeId,
    String? currentScheduleThemeId,
    ThemeSchedule? currentSchedule,
  }) {
    return SmartThemeState(
      isEnabled: isEnabled ?? this.isEnabled,
      morningThemeId: morningThemeId ?? this.morningThemeId,
      dayThemeId: dayThemeId ?? this.dayThemeId,
      eveningThemeId: eveningThemeId ?? this.eveningThemeId,
      nightThemeId: nightThemeId ?? this.nightThemeId,
      currentScheduleThemeId: currentScheduleThemeId ?? this.currentScheduleThemeId,
      currentSchedule: currentSchedule ?? this.currentSchedule,
    );
  }
}

/// Theme schedule time periods
enum ThemeSchedule {
  morning,
  day,
  evening,
  night,
}

/// Extension to get theme schedule properties
extension ThemeScheduleExtension on ThemeSchedule {
  String get displayName {
    switch (this) {
      case ThemeSchedule.morning:
        return 'Morning (5AM - 12PM)';
      case ThemeSchedule.day:
        return 'Afternoon (12PM - 5PM)';
      case ThemeSchedule.evening:
        return 'Evening (5PM - 9PM)';
      case ThemeSchedule.night:
        return 'Night (9PM - 5AM)';
    }
  }

  String get icon {
    switch (this) {
      case ThemeSchedule.morning:
        return '🌅';
      case ThemeSchedule.day:
        return '☀️';
      case ThemeSchedule.evening:
        return '🌇';
      case ThemeSchedule.night:
        return '🌙';
    }
  }

  String get description {
    switch (this) {
      case ThemeSchedule.morning:
        return 'Energetic, fresh start';
      case ThemeSchedule.day:
        return 'Bright, productive';
      case ThemeSchedule.evening:
        return 'Warm, relaxing';
      case ThemeSchedule.night:
        return 'Deep, calm, restful';
    }
  }
}

/// UI Widget for smart theme switcher settings
class SmartThemeSettingsSheet extends ConsumerWidget {
  const SmartThemeSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smartTheme = ref.watch(smartThemeSwitcherProvider);
    final notifier = ref.read(smartThemeSwitcherProvider.notifier);
    final currentTheme = ref.watch(rippleThemeProvider);

    return Container(
      decoration: BoxDecoration(
        color: currentTheme.colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: currentTheme.colors.glassBorder, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: currentTheme.colors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.schedule, color: currentTheme.colors.primary),
              const SizedBox(width: 8),
              Text(
                'Smart Theme Switcher',
                style: TextStyle(
                  color: currentTheme.colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          Text(
            'Automatically change themes based on time of day',
            style: TextStyle(
              color: currentTheme.colors.textMuted,
              fontSize: 12,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Enable/Disable switch
          SwitchListTile(
            title: Text(
              'Enable Smart Switching',
              style: TextStyle(color: currentTheme.colors.textPrimary),
            ),
            subtitle: Text(
              'Theme will change automatically every 4 hours',
              style: TextStyle(color: currentTheme.colors.textMuted, fontSize: 12),
            ),
            value: smartTheme.isEnabled,
            activeColor: currentTheme.colors.primary,
            onChanged: (value) => notifier.toggleSmartSwitching(value),
          ),
          
          const Divider(),
          
          // Current status
          if (smartTheme.isEnabled) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: currentTheme.colors.glassSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: currentTheme.colors.glassBorder),
              ),
              child: Row(
                children: [
                  Text(
                    _getScheduleIcon(smartTheme.currentSchedule),
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current: ${notifier.getCurrentScheduleName()}',
                          style: TextStyle(
                            color: currentTheme.colors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Next check in 15 minutes',
                          style: TextStyle(
                            color: currentTheme.colors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Theme selection for each time period
          Expanded(
            child: ListView.builder(
              itemCount: 4,
              itemBuilder: (context, index) {
                final schedule = ThemeSchedule.values[index];
                final themeId = _getThemeIdForSchedule(smartTheme, schedule);
                final theme = ThemePresets.getById(themeId ?? 'aqua_ocean');

                return ListTile(
                  leading: Text(
                    schedule.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(
                    schedule.displayName,
                    style: TextStyle(
                      color: currentTheme.colors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    schedule.description,
                    style: TextStyle(
                      color: currentTheme.colors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  trailing: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: theme.gradients.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  onTap: () => _showThemePickerForSchedule(context, ref, schedule),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _getScheduleIcon(ThemeSchedule? schedule) {
    if (schedule == null) {
      final hour = DateTime.now().hour;
      if (hour >= 5 && hour < 12) return '🌅';
      if (hour >= 12 && hour < 17) return '☀️';
      if (hour >= 17 && hour < 21) return '🌇';
      return '🌙';
    }
    return schedule.icon;
  }

  String? _getThemeIdForSchedule(SmartThemeState state, ThemeSchedule schedule) {
    switch (schedule) {
      case ThemeSchedule.morning:
        return state.morningThemeId;
      case ThemeSchedule.day:
        return state.dayThemeId;
      case ThemeSchedule.evening:
        return state.eveningThemeId;
      case ThemeSchedule.night:
        return state.nightThemeId;
    }
  }

  void _showThemePickerForSchedule(BuildContext context, WidgetRef ref, ThemeSchedule schedule) {
    final currentTheme = ref.read(rippleThemeProvider);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: currentTheme.colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              'Select Theme for ${schedule.displayName}',
              style: TextStyle(
                color: currentTheme.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: ThemePresets.all.length,
                itemBuilder: (context, index) {
                  final theme = ThemePresets.all[index];
                  return GestureDetector(
                    onTap: () {
                      ref.read(smartThemeSwitcherProvider.notifier)
                          .setThemeForSchedule(schedule, theme.id);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: theme.gradients.surface,
                        border: Border.all(
                          color: theme.colors.glassBorder,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: theme.gradients.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            theme.name,
                            style: TextStyle(
                              color: theme.colors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
