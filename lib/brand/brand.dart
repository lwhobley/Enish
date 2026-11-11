import 'package:flutter/material.dart';

/// The single source of brand truth. Every screen and every venue renders
/// from these tokens and components, so no location can drift off-brand.
/// Values are taken from enishglobal.com.
abstract final class EnishColors {
  static const background = Color(0xFF0F0E0E);
  static const surface = Color(0xFF1A1918);
  static const border = Color(0xFF2D2B28);
  static const cream = Color(0xFFEAE4DA);
  static const muted = Color(0xFF9A958D);
  static const oxblood = Color(0xFF801500);
  static const gold = Color(0xFFA0844B);
}

abstract final class EnishSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 40.0;
}

abstract final class EnishText {
  // TODO(brand): the website uses "Gyst Variable" for headings and DM Sans for
  // body. Bundle the licensed font files and set fontFamily here.
  static const display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.5,
    height: 1.15,
    color: EnishColors.cream,
  );
  static const title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
    color: EnishColors.cream,
  );
  static const eyebrow = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.2,
    color: EnishColors.gold,
  );
  static const body = TextStyle(
    fontSize: 15,
    height: 1.5,
    color: EnishColors.muted,
  );
  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.8,
    color: EnishColors.cream,
  );
}

ThemeData enishTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: EnishColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: EnishColors.oxblood,
      onPrimary: EnishColors.cream,
      secondary: EnishColors.gold,
      surface: EnishColors.background,
      onSurface: EnishColors.cream,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: EnishColors.background,
      foregroundColor: EnishColors.cream,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: EnishText.title,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: EnishColors.background,
      indicatorColor: Colors.transparent,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 10,
          letterSpacing: 1.4,
          color: s.contains(WidgetState.selected)
              ? EnishColors.cream
              : EnishColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? EnishColors.gold
              : EnishColors.muted,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: EnishColors.border, space: 1),
    inputDecorationTheme: const InputDecorationTheme(
      labelStyle: EnishText.body,
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: EnishColors.border),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: EnishColors.gold),
      ),
    ),
  );
}

/// Primary (filled oxblood) or secondary (outlined) call to action.
class EnishButton extends StatelessWidget {
  const EnishButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final IconData? icon;

  /// Fill colour for primary buttons; defaults to brand oxblood. Venue pages
  /// pass the venue's accent.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16),
          const SizedBox(width: EnishSpace.sm),
        ],
        Flexible(
          child: Text(
            label.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.8,
            ),
          ),
        ),
      ],
    );
    const shape = RoundedRectangleBorder();
    const padding = EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    return primary
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: color ?? EnishColors.oxblood,
              foregroundColor: (color != null && color!.computeLuminance() > 0.45)
                  ? EnishColors.background
                  : EnishColors.cream,
              disabledBackgroundColor: EnishColors.border,
              shape: shape,
              padding: padding,
            ),
            child: child,
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: EnishColors.cream,
              side: const BorderSide(color: EnishColors.muted),
              shape: shape,
              padding: padding,
            ),
            child: child,
          );
  }
}

class EnishSectionHeader extends StatelessWidget {
  const EnishSectionHeader({super.key, required this.title, this.eyebrow});

  final String title;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        EnishSpace.md,
        EnishSpace.lg,
        EnishSpace.md,
        EnishSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(eyebrow!.toUpperCase(), style: EnishText.eyebrow),
            const SizedBox(height: EnishSpace.xs),
          ],
          Text(title.toUpperCase(), style: EnishText.title),
        ],
      ),
    );
  }
}

/// Bordered panel used for every card-like surface in the app.
class EnishPanel extends StatelessWidget {
  const EnishPanel({super.key, required this.child, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: EnishColors.surface,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: EnishColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(EnishSpace.md),
          child: child,
        ),
      ),
    );
  }
}

/// Stand-in for venue photography until imagery is supplied.
class EnishHero extends StatelessWidget {
  const EnishHero({super.key, required this.title, this.eyebrow, this.height = 220});

  final String title;
  final String? eyebrow;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(EnishSpace.md),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF3A1208), EnishColors.surface, EnishColors.background],
        ),
        border: Border(bottom: BorderSide(color: EnishColors.border)),
      ),
      alignment: Alignment.bottomLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(eyebrow!.toUpperCase(), style: EnishText.eyebrow),
            const SizedBox(height: EnishSpace.sm),
          ],
          Text(title.toUpperCase(), style: EnishText.display),
        ],
      ),
    );
  }
}

/// Honest placeholder for a section whose data source is not connected yet.
class EnishComingSoon extends StatelessWidget {
  const EnishComingSoon({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: EnishSpace.md),
      child: EnishPanel(child: Text(message, style: EnishText.body)),
    );
  }
}
