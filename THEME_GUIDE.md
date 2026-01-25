# Active Application - Theme System Guide

This guide outlines the principles and usage of the refined Active theme system. The goal is a minimalist, high-contrast, and scalable foundation that works exceptionally well in both light and dark modes.

## 1. Core Principles

- **True Dark Mode**: Surfaces use a deep carbon/ink palette (`#030408`) to ensure high contrast with primary and secondary accents.
- **Intentional Layering**: Depth is created using semantic `surfaceContainer` tokens rather than shadows or gray washes.
- **High Contrast Typography**: Text tokens (`onSurface`, `onSurfaceVariant`) are tuned for maximum readability against their respective backgrounds.
- **Calm Visuals**: Avoid loud gradients or excessive Material 3 "glassmorphism" unless specifically required for a primary CTA.

## 2. Semantic Token Usage

Always use `Theme.of(context).colorScheme` tokens to ensure your UI scales across profiles (Active Blue, Deep Forest, etc.).

| Token                  | Usage Case                                                                 |
| :--------------------- | :------------------------------------------------------------------------- |
| `surface`              | Main background of the page (Scaffold).                                    |
| `surfaceContainer`     | Default card background. Use for standard grouped items.                   |
| `surfaceContainerHigh` | Secondary elevation, e.g., hover effects or emphasized cards.              |
| `surfaceContainerLow`  | Subtle background for grouped lists or secondary sections.                 |
| `primary`              | Primary action colors (Buttons, Active states).                            |
| `secondary`            | Success or secondary progress indicators.                                  |
| `outline`              | Dividers and thin borders. Use `.withValues(alpha: 0.1)` for sublte lines. |
| `onSurface`            | Main body text and headlines.                                              |
| `onSurfaceVariant`     | Subtitles and muted information.                                           |

## 3. Visualization Guidelines

- **Charts**: Use `AppColors.chartPalette` for categorical data (e.g., categories in a pie chart).
- **Progress**: Use `primary` for global progress and `secondary` for goal-specific success states.
- **Micro-animations**: Keep pulse colors tied to `secondary` or `primary` based on the activity state.

## 4. Do's and Don'ts

### ✅ Do

- Use `CardTheme` defaults (automatically applied to `Card` widgets).
- Use `textTheme` (e.g., `displayMedium`, `labelLarge`) for consistent typography.
- Respect the `outline` border strategy for cards to maintain hierarchy.

### ❌ Don't

- Hardcode `Colors.white` or `Colors.black`.
- Use `fromSeed` for surface properties in new profiles.
- Add manual `withOpacity` overrides for primary text (use `onSurfaceVariant` instead).
- Use elevation values > 0 (all depth is color-driven).

## 5. Adding New Color Profiles

When adding a new profile in `app_color_schemes.dart`, manually define all `surfaceContainer` variants to maintain the intentional elevation strategy of the app.
