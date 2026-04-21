import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_provider.dart';

/// Enhanced page wrapper with theme-aware animations and effects
class AnimatedPageWrapper extends ConsumerStatefulWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showParticles;
  final bool animate;
  final Duration animationDuration;
  final EdgeInsets padding;

  const AnimatedPageWrapper({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.showParticles = true,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 400),
    this.padding = const EdgeInsets.all(0),
  });

  @override
  ConsumerState<AnimatedPageWrapper> createState() => _AnimatedPageWrapperState();
}

class _AnimatedPageWrapperState extends ConsumerState<AnimatedPageWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.02),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(rippleThemeProvider);

    return Scaffold(
      backgroundColor: theme.colors.background,
      appBar: widget.title != null
          ? AppBar(
              title: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => Opacity(
                  opacity: _fadeAnim.value,
                  child: Text(
                    widget.title!,
                    style: TextStyle(
                      color: theme.colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: theme.colors.primary),
              actions: widget.actions,
            )
          : null,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colors.background,
                    theme.colors.surface,
                  ],
                ),
              ),
              child: child,
            ),
          ),
        ),
        child: widget.child,
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }
}

/// Smooth animated list item with theme colors
class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final VoidCallback? onTap;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.duration = const Duration(milliseconds: 300),
    this.onTap,
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 0.1),
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: widget.duration,
        child: widget.onTap != null
            ? InkWell(
                onTap: widget.onTap,
                child: widget.child,
              )
            : widget.child,
      ),
    );
  }
}

/// Theme-aware shimmer loading effect
class ThemeShimmer extends ConsumerWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ThemeShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(rippleThemeProvider);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colors.glassSurface,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Animated theme transition widget
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
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
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _controller.value,
        child: child,
      ),
      child: widget.child,
    );
  }
}
