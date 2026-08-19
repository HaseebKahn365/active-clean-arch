# Active Design System Specification (shadcn/ui + Apple Minimalist Monochromatic)

A comprehensive design language and motion engineering specification for building ultra-refined, high-contrast, kinetic Flutter interfaces inspired by **shadcn/ui**, **Vercel**, and **Apple iOS**.

---

## 1. Core Design Philosophy

1. **Monochromatic Restraint & High Contrast**:
   - The UI is anchored by deep obsidian blacks (`#09090B`, `#111113`) and crisp chalk whites (`#FFFFFF`, `#FAFAFA`).
   - Grays are meticulously calibrated neutral-zinc tones (`#71717A`, `#A1A1AA`, `#ECECEE`, `#27272A`).
   - Color is never decorative — it is strictly functional and reserved for semantic states (e.g., active streaks, record achievements, rectifications/destructive actions, data intensity).

2. **Pill & Card Hierarchy (Curvature Geometry)**:
   - **Full Pills (`999px`)**: Interactive buttons, segmented toggle sliders, stat chips, badge counters, and floating bottom navigation bars.
   - **Soft Square Cards (`24px` - `28px`)**: Primary containers, dashboard stat panels, chat bubbles, and modal dialogs.
   - **Icon Enclosures (`12px` - `16px`)**: Bounded contextual icon glyph boxes.

3. **Tactile Kinetic Physics**:
   - **Zero Abrupt State Changes**: Every expansion, tab switch, filter toggle, modal presentation, and data stream must possess physical inertia, smooth deceleration (`Curves.easeOutCubic`), or subtle elastic recoil (`Curves.easeOutBack`).
   - **Liquid Streaming Expansion**: Chat streams and expanding tiles grow continuously with `AnimatedSize` rather than popping abruptly.

---

## 2. Color Palette & Token System

### 2.1 Monochromatic Neutrals & Surfaces

| Token | Light Theme (Hex) | Dark / Obsidian Theme (Hex) | Usage |
|---|---|---|---|
| `background` | `#FFFFFF` | `#09090B` | Root page background |
| `surfaceCard` | `#FAFAFA` | `#111113` | Primary cards, list items, chat containers |
| `surfaceSubtle` | `#F4F4F5` | `#18181B` | Input fields, active icon backings, disabled pills |
| `surfaceDark` | `#111113` | `#FAFAFA` | Inverted hero cards, solid action pills, active tab indicator |
| `borderCard` | `#EEEEEE` | `#1F1F23` | Outer card boundary line (`1.0px` stroke) |
| `borderSubtle` | `#ECECEE` | `#27272A` | Secondary dividers, input borders, pill borders |
| `borderDivider` | `#F0F0F1` | `#1A1A1E` | List separators |

### 2.2 Text Hierarchy

| Token | Light Theme (Hex) | Dark / Obsidian Theme (Hex) | Weight & Tracking |
|---|---|---|---|
| `textPrimary` | `#0A0A0A` | `#FAFAFA` | `FontWeight.w700` - `w800`, tracking: `-0.5px` (Headers), `-0.2px` (Titles) |
| `textSecondary` | `#71717A` | `#A1A1AA` | `FontWeight.w500` - `w600`, tracking: normal |
| `textMuted` | `#A1A1AA` | `#52525B` | `FontWeight.w400` - `w500`, subtle annotations |
| `textSubtle` | `#D4D4D8` | `#3F3F46` | `FontWeight.w400`, placeholders & empty states |
| `textOnDark` | `#FAFAFA` | `#09090B` | Inverted text rendered on `surfaceDark` |

### 2.3 Semantic Accents

| Token | Light Theme (Hex) | Dark Theme (Hex) | Meaning |
|---|---|---|---|
| `fire` / `badgeTodayBg` | `#FEF3C7` / `#D97706` | `#2D1E05` / `#F59E0B` | Active streak / fire today |
| `goldAccent` | `#F59E0B` | `#FBBF24` | Best record, theme toggle glow, active day highlight |
| `error` | `#EF4444` | `#F87171` | Deletion, destructive confirmation, negative rectifications |
| `errorBg` | `#FEF2F2` | `#2E1214` | Destructive action card background |
| `countIcon` | `#0284C7` (Sky) | `#38BDF8` (Sky) | Quantitative count activities |
| `timeIcon` | `#D97706` (Amber) | `#FBBF24` (Amber) | Duration / minute activities |

---

## 3. Typography & Spatial Tokens

- **Typeface**: System San-Francisco (`SF Pro Display`), `Inter`, or Roboto.
- **Header Tracking**:
  - H1 Display (`24-26pt`): `letterSpacing: -0.5`, `fontWeight: FontWeight.w800`
  - H2 Section (`18-20pt`): `letterSpacing: -0.3`, `fontWeight: FontWeight.w800`
  - Card Title (`16-17pt`): `letterSpacing: -0.2`, `fontWeight: FontWeight.w700`
  - Body (`14-14.5pt`): `height: 1.4`, `fontWeight: FontWeight.w500`
  - Badges / Micro-labels (`10-12pt`): `fontWeight: FontWeight.w700`, `letterSpacing: 0.2`
- **Padding & Grid**:
  - Screen edge margins: `EdgeInsets.symmetric(horizontal: 20)`
  - Bottom scroll padding for floating bar: `110px`
  - Card inner padding: `EdgeInsets.all(14)` or `EdgeInsets.all(18)`
  - Segmented toggle height: `46px`
  - Floating navigation pill height: `52px`

---

## 4. Animation & Motion Engineering Specifications

Motion in this design system is **fluid, springy, and deliberate**. No state change should ever pop in instantaneously.

### 4.1 Motion Curve Tokens & Durations

```dart
static const Duration durationFast = Duration(milliseconds: 150);      // Micro-taps, press scale
static const Duration durationStandard = Duration(milliseconds: 250);  // Pill sliding, fade transitions
static const Duration durationStructural = Duration(milliseconds: 280);// Card expansion, bottom bar slide
static const Duration durationEmphasis = Duration(milliseconds: 350);  // Chart morphing, page transitions

static const Curve curveEnter = Curves.easeOutCubic;                   // Smooth deceleration
static const Curve curveSpring = Curves.easeOutBack;                  // Subtle elastic recoil
static const Curve curveMorph = Curves.easeInOutCubic;                // Morphing curves
```

---

### 4.2 Pattern: Sliding Pill Segmented Controls

Instead of switching tabs or segmented buttons by re-rendering raw boxes, use a **floating solid capsule** behind the choices that physically glides across the container with spring physics.

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final pillWidth = constraints.maxWidth / itemCount;
    return Stack(
      children: [
        // 1. Sliding Solid Capsule Indicator
        AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: selectedIndex == 0
              ? Alignment.centerLeft
              : selectedIndex == 1
                  ? Alignment.center
                  : Alignment.centerRight,
          child: Container(
            width: pillWidth,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.getSurfaceDark(isDark),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black45 : Colors.black12,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
        // 2. Clickable Touch Targets & Text / Icon layer
        Row(
          children: items.map((item) => Expanded(
            child: InkWell(
              onTap: () => onSelect(item.index),
              borderRadius: BorderRadius.circular(999),
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? AppColors.getTextOnDark(isDark)
                        : AppColors.getTextPrimary(isDark),
                  ),
                  child: Text(item.label),
                ),
              ),
            ),
          )).toList(),
        ),
      ],
    );
  },
)
```

---

### 4.3 Pattern: Expandable Tile with Liquid Expansion

Tile expansion must use `AnimatedSize` combined with `flutter_animate` staggered entrance for internal children so that cards smoothly roll open and closed.

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 250),
  curve: Curves.easeInOutCubic,
  decoration: BoxDecoration(
    color: AppColors.getSurfaceCard(isDark),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: isExpanded ? AppColors.getBorderSubtle(isDark) : AppColors.getBorderCard(isDark),
      width: isExpanded ? 1.5 : 1.0,
    ),
  ),
  child: Column(
    children: [
      // Tile Header Header (Always visible)
      InkWell(
        onTap: () => setState(() => isExpanded = !isExpanded),
        borderRadius: BorderRadius.circular(24),
        child: Padding(...),
      ),
      // Liquid Smooth Expansion
      AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: isExpanded
            ? Container(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    // Staggered contents
                  ],
                ),
              )
                .animate()
                .fadeIn(duration: 200.ms, curve: Curves.easeOut)
                .slideY(begin: -0.05, end: 0, duration: 200.ms, curve: Curves.easeOutCubic)
            : const SizedBox.shrink(),
      ),
    ],
  ),
)
```

---

### 4.4 Pattern: iMessage-Style Spring Bubble Pop-In

Chat bubbles pop in with an elastic spring scale anchored directly to the speech bubble's tail corner (`Alignment.bottomRight` for the user, `Alignment.bottomLeft` for assistant).

```dart
Align(
  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
  child: AnimatedSize(
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOutCubic,
    alignment: isUser ? Alignment.topRight : Alignment.topLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 20),
        ),
      ),
      child: content,
    ),
  )
    .animate(key: ValueKey('bubble_$id'))
    .fadeIn(duration: 200.ms, curve: Curves.easeOut)
    .scale(
      begin: const Offset(0.85, 0.85),
      end: const Offset(1.0, 1.0),
      alignment: isUser ? Alignment.bottomRight : Alignment.bottomLeft,
      duration: 260.ms,
      curve: Curves.easeOutBack, // Elastic spring recoil
    )
    .slideY(begin: 0.1, end: 0, duration: 240.ms, curve: Curves.easeOutCubic),
)
```

---

### 4.5 Pattern: Wave-Bouncing Typing Indicator (3-Dot Sine Wave)

A custom, physics-driven typing wave replaces static spinner boxes:

```dart
class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: 46,
          height: 18,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (i) {
              final phase = (_controller.value * 2 * math.pi) - (i * 0.85);
              final sine = math.sin(phase);
              final bounce = sine > 0 ? sine : 0.0;
              final offsetY = -6.0 * bounce;
              final scale = 0.85 + (0.35 * bounce);
              final opacity = (0.4 + (0.6 * bounce)).clamp(0.0, 1.0);

              return Transform.translate(
                offset: Offset(0, offsetY),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 7.5,
                      height: 7.5,
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
```

---

### 4.6 Pattern: Equalizer Waveform Busy State on Action Buttons

Action buttons animate from their standard action icon (e.g., Send arrow) to a dancing 3-bar equalizer when active:

```dart
class _ButtonBusyIndicatorState extends State<_ButtonBusyIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final t = (_controller.value + (i * 0.25)) % 1.0;
            final height = 5.0 + (11.0 * math.sin(t * math.pi));
            return Container(
              width: 3.0,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        );
      },
    );
  }
}
```

---

### 4.7 Pattern: Staggered Page List Entrances

Whenever lists load (e.g. Dashboard Activities, Charts, Records), stagger their appearance to guide the eye:

```dart
for (int i = 0; i < items.length; i++)
  CardWidget(item: items[i])
    .animate(key: ValueKey('item_${items[i].id ?? i}'))
    .fadeIn(duration: 250.ms, curve: Curves.easeOut)
    .slideY(begin: 0.08, end: 0, duration: 250.ms, curve: Curves.easeOutCubic),
```

---

### 4.8 Pattern: Floating Pill Bottom Navigation Bar

A floating navigation bar detached from the bottom edge by `22px` with a sliding pill highlight:

```dart
Positioned(
  left: 16,
  right: 16,
  bottom: 22,
  child: Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: isDark ? AppColors.darkSurfaceCard : AppColors.lightBackground,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.getBorderCard(isDark), width: 1),
      boxShadow: [
        BoxShadow(
          color: isDark ? const Color(0x77000000) : const Color(0x24000000),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / 3;
        return Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: currentTab == AppTab.home
                  ? const Alignment(-1.0, 0.0)
                  : currentTab == AppTab.stats
                      ? const Alignment(0.0, 0.0)
                      : const Alignment(1.0, 0.0),
              child: Container(
                width: itemWidth,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.getSurfaceDark(isDark),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                _TabButton(label: 'Home', icon: Icons.home_rounded, isSelected: currentTab == AppTab.home),
                _TabButton(label: 'Stats', icon: Icons.bar_chart_rounded, isSelected: currentTab == AppTab.stats),
                _TabButton(label: 'Agent', icon: Icons.smart_toy_rounded, isSelected: currentTab == AppTab.agent),
              ],
            ),
          ],
        );
      },
    ),
  ),
)
```

---

## 5. UI Overflow Safety & Robustness Rules

1. **Avoid Rigid Rows for Multi-Item Badges**:
   - Always wrap stat pills (e.g. `Today`, `Weekly`, `Monthly`, `Yearly`) in `Wrap(spacing: 7, runSpacing: 7)`.
2. **Compact Heat Map & Calendar Cells**:
   - Always enclose cell texts in `Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(..., style: TextStyle(height: 1.0))))` so numbers ranging into thousands (`1000+`) scale smoothly without throwing `RenderFlex` exceptions.
3. **FlChart Y-Axis Headroom**:
   - Always assign `reservedSize: 32` or higher on left title axes for 4-digit numbers.

---

## 6. How Another Agent Should Apply This Design System to Any App

When modernizing or reskinning another application with this design language:
1. **Set Up Theme Tokens**: Define `AppColors` for Light (`#FFFFFF` background, `#FAFAFA` card) and Dark (`#09090B` background, `#111113` card, `#FAFAFA` text).
2. **Add Motion Dependency**: Include `flutter_animate: ^4.5.2` in `pubspec.yaml`.
3. **Replace Standard Navbars**: Replace bottom `NavigationBar` with the Floating Pill Navigation Bar.
4. **Implement Smooth Toggles**: Convert standard `TabBar` or `Switch` widgets into the sliding capsule layout (`Stack` + `AnimatedAlign` + `LayoutBuilder`).
5. **Convert Expandable Tiles**: Wrap expandable panels with `AnimatedSize(duration: 280ms, curve: Curves.easeOutCubic)` and staggered `.fadeIn().slideY()` children.
6. **Add Dynamic Feedback to Busy States**: Replace standard static spinners with animated wave/equalizer pulses.
7. **Ensure Overflow Resilience**: Use `Wrap` for statistic pills and `FittedBox` inside grid/calendar day cells.
