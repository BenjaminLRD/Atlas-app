---
name: Vitality Design System
colors:
  surface: '#f9f9f9'
  surface-dim: '#dadada'
  surface-bright: '#f9f9f9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f3f3'
  surface-container: '#eeeeee'
  surface-container-high: '#e8e8e8'
  surface-container-highest: '#e2e2e2'
  on-surface: '#1b1b1b'
  on-surface-variant: '#4c4546'
  inverse-surface: '#303030'
  inverse-on-surface: '#f1f1f1'
  outline: '#7e7576'
  outline-variant: '#cfc4c5'
  surface-tint: '#5e5e5e'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#1b1b1b'
  on-primary-container: '#848484'
  inverse-primary: '#c6c6c6'
  secondary: '#5d5e63'
  on-secondary: '#ffffff'
  secondary-container: '#e0dfe4'
  on-secondary-container: '#626267'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#1b1b1b'
  on-tertiary-container: '#848484'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e2e2e2'
  primary-fixed-dim: '#c6c6c6'
  on-primary-fixed: '#1b1b1b'
  on-primary-fixed-variant: '#474747'
  secondary-fixed: '#e3e2e7'
  secondary-fixed-dim: '#c6c6cb'
  on-secondary-fixed: '#1a1b1f'
  on-secondary-fixed-variant: '#46464b'
  tertiary-fixed: '#e2e2e2'
  tertiary-fixed-dim: '#c6c6c6'
  on-tertiary-fixed: '#1b1b1b'
  on-tertiary-fixed-variant: '#474747'
  background: '#f9f9f9'
  on-background: '#1b1b1b'
  surface-variant: '#e2e2e2'
typography:
  display-metrics:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '800'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 34px
    fontWeight: '700'
    lineHeight: 41px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
  headline-md:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 20px
  label-caps:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  container-padding-mobile: 16px
  container-padding-desktop: 32px
  stack-gap-sm: 12px
  stack-gap-md: 24px
  stack-gap-lg: 40px
  column-gutter: 16px
---

## Brand & Style
The design system is rooted in the philosophy of "Intelligent Performance"—a premium, data-driven aesthetic that prioritizes clarity, focus, and motivation. It is designed for users who seek a professional-grade health and fitness experience that feels integrated into their lifestyle rather than distracting from it.

The style is a fusion of **Minimalism** and **Modern Corporate**, drawing heavily from the editorial layouts of premium fitness journals and the functional precision of professional athletic tools. The interface uses expansive whitespace to reduce cognitive load, allowing high-contrast typography and vibrant biological metrics to take center stage. The emotional response should be one of calm authority and encouraging progress.

## Colors
The palette is built on a foundation of neutral system tones to ensure data visualization is the primary focus. 

- **Backgrounds:** Use `#F2F2F7` for the base canvas to create a soft, non-clinical environment. In dark mode, transition to pure `#000000` for maximum OLED contrast.
- **Surfaces:** Cards and containers use `#FFFFFF` (Light) or `#1C1C1E` (Dark) to create a subtle lift from the background.
- **Accents:** Each macro-nutrient and activity metric is assigned a distinct, high-chroma color. These are reserved exclusively for data representation (rings, charts, progress bars) and should not be used for general UI decorations to maintain their semantic meaning.
- **Typography:** Primary text maintains absolute contrast, while secondary text uses `#8E8E93` to establish a clear information hierarchy.

## Typography
This design system utilizes **Inter** across all levels to emulate a modern, systematic, and highly legible aesthetic. The hierarchy is "top-heavy," meaning headings and metrics are significantly larger and bolder than body text to allow for quick scanning during physical activity.

- **Metric Display:** Use `display-metrics` for the most critical numbers (e.g., daily steps, heart rate).
- **Editorial Style:** Use `label-caps` for section headers to create a rhythmic, structured layout.
- **Scale:** On mobile devices, ensure `headline-lg` scales down to the mobile variant to prevent awkward line breaks while maintaining a bold presence.

## Layout & Spacing
The layout follows a **Fluid Grid** model with a focus on vertical stacking. 

- **The 8px Rhythm:** All spacing increments must be multiples of 8px to maintain mathematical harmony.
- **Margins:** Use a 16px safe margin for mobile and 32px for tablet/desktop views.
- **Grouping:** Use `stack-gap-md` (24px) between related cards and `stack-gap-lg` (40px) between major sections (e.g., Activity vs. Heart Health).
- **Desktop Adaptation:** Content should be centered in a max-width container (typically 1200px) on large screens, utilizing a 12-column grid to organize dashboard widgets.

## Elevation & Depth
Depth is primarily communicated through **Tonal Layering** rather than heavy shadows.

- **Surface Tiers:** In light mode, the background is slightly grey (#F2F2F7), and cards are pure white (#FFFFFF). This creates a physical "lift" without the need for visual noise.
- **Shadows:** When shadows are necessary for floating elements (like FABs or Modals), use a "High-Diffusion Ambient Shadow": `0px 4px 20px rgba(0, 0, 0, 0.05)`.
- **Separators:** Use 1px hairlines with 10% opacity of the text color to divide list items, maintaining a crisp, flat appearance.

## Shapes
The shape language is "Organic-Geometric," combining the precision of a grid with the softness of human-centric design.

- **Cards & Containers:** Use a generous `24px` radius to feel approachable and premium.
- **Interactive Elements:** Buttons, chips, and input fields should be **fully rounded (pill-shaped)** to distinguish them from informational cards.
- **Data Visuals:** Progress rings and bars must always use rounded end-caps to maintain the soft aesthetic.

## Components

### Buttons
- **Primary:** High-contrast (Black in Light mode, White in Dark mode), pill-shaped, with `body-lg` semibold text.
- **Secondary:** Transparent background with a 1px border or a soft grey fill, used for less critical actions.

### Cards (Health Widgets)
- White or Dark Grey background with `24px` corner radius.
- Internal padding should be a consistent `20px`.
- Icons should be placed in the top-left or top-right using their specific semantic metric color.

### Progress Rings
- The hallmark of the design system. Use a stroke width that is 10% of the total diameter. 
- Background tracks should be 10% opacity of the foreground accent color.

### Input Fields
- Pill-shaped with a subtle background fill (#E9E9EB in Light mode).
- Focus states are indicated by a 2px stroke of the primary color.

### Lists
- Standardized heights (min 44px for touch targets).
- Use chevrons for navigable items and "Value + Unit" strings for health data points.