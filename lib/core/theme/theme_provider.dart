import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_models.dart';

/// Current theme provider - provides the full theme data
final rippleThemeProvider = StateNotifierProvider<RippleThemeNotifier, RippleTheme>((ref) {
  return RippleThemeNotifier();
});

/// Theme notifier that manages the current theme
class RippleThemeNotifier extends StateNotifier<RippleTheme> {
  RippleThemeNotifier() : super(ThemePresets.aquaOcean) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeId = prefs.getString('ripple_theme_id') ?? 'aqua_ocean';
    state = ThemePresets.getById(themeId);
  }

  Future<void> setTheme(String themeId) async {
    final newTheme = ThemePresets.getById(themeId);
    state = newTheme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ripple_theme_id', themeId);
  }

  Future<void> setThemeByObject(RippleTheme theme) async {
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ripple_theme_id', theme.id);
  }

  /// Cycle to next theme
  Future<void> cycleNext() async {
    final themes = ThemePresets.all;
    final currentIndex = themes.indexWhere((t) => t.id == state.id);
    final nextIndex = (currentIndex + 1) % themes.length;
    await setTheme(themes[nextIndex].id);
  }
}

/// Animated theme switcher widget
class AnimatedThemeSwitcher extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const AnimatedThemeSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<AnimatedThemeSwitcher> createState() => _AnimatedThemeSwitcherState();
}

class _AnimatedThemeSwitcherState extends State<AnimatedThemeSwitcher>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedThemeSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnim,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnim.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Theme picker bottom sheet
class ThemePickerSheet extends ConsumerStatefulWidget {
  final VoidCallback? onThemeChanged;

  const ThemePickerSheet({super.key, this.onThemeChanged});

  @override
  ConsumerState<ThemePickerSheet> createState() => _ThemePickerSheetState();
}

class _ThemePickerSheetState extends ConsumerState<ThemePickerSheet> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(rippleThemeProvider);
    final themes = ThemePresets.all;

    return Container(
      decoration: BoxDecoration(
        color: currentTheme.colors.surface,
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
          Text(
            'Choose Theme',
            style: TextStyle(
              color: currentTheme.colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Theme grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: themes.length,
              itemBuilder: (_, index) {
                final theme = themes[index];
                final isSelected = theme.id == currentTheme.id;

                return GestureDetector(
                  onTap: _isSaving
                      ? null
                      : () => _selectTheme(theme.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: theme.gradients.surface,
                      border: Border.all(
                        color: isSelected
                            ? theme.colors.primary
                            : theme.colors.glassBorder,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected ? theme.shadows.primaryGlow : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Color preview
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: theme.gradients.primary,
                            boxShadow: theme.shadows.primaryGlow,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          theme.name,
                          style: TextStyle(
                            color: theme.colors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          theme.description,
                          style: TextStyle(
                            color: theme.colors.textMuted,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isSelected) ...[
                          const SizedBox(height: 8),
                          Icon(
                            Icons.check_circle,
                            color: theme.colors.primary,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_isSaving)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: CircularProgressIndicator(
                color: currentTheme.colors.primary,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _selectTheme(String themeId) async {
    setState(() => _isSaving = true);
    await ref.read(rippleThemeProvider.notifier).setTheme(themeId);
    setState(() => _isSaving = false);
    widget.onThemeChanged?.call();
    if (mounted) Navigator.pop(context);
  }
}

/// Quick theme toggle button (cycles through themes)
class QuickThemeToggle extends ConsumerWidget {
  const QuickThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(rippleThemeProvider);

    return GestureDetector(
      onTap: () => ref.read(rippleThemeProvider.notifier).cycleNext(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: theme.gradients.primary,
          boxShadow: theme.shadows.primaryGlow,
        ),
        child: Icon(
          Icons.palette_outlined,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
