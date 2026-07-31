---
name: CaterPro Admin
colors:
  surface: '#f0fdf3'
  surface-dim: '#d0ddd4'
  surface-bright: '#f0fdf3'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eaf7ed'
  surface-container: '#e4f1e7'
  surface-container-high: '#dfebe2'
  surface-container-highest: '#d9e6dc'
  on-surface: '#131e18'
  on-surface-variant: '#404940'
  inverse-surface: '#28332d'
  inverse-on-surface: '#e7f4ea'
  outline: '#707a6f'
  outline-variant: '#bfc9bd'
  surface-tint: '#1b6c37'
  primary: '#0e6430'
  on-primary: '#ffffff'
  primary-container: '#2f7d46'
  on-primary-container: '#cdffd2'
  inverse-primary: '#89d897'
  secondary: '#0d6d2c'
  on-secondary: '#ffffff'
  secondary-container: '#9df7a5'
  on-secondary-container: '#187432'
  tertiary: '#535851'
  on-tertiary: '#ffffff'
  tertiary-container: '#6b7069'
  on-tertiary-container: '#f0f4eb'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#a4f5b2'
  primary-fixed-dim: '#89d897'
  on-primary-fixed: '#00210b'
  on-primary-fixed-variant: '#005224'
  secondary-fixed: '#9df7a5'
  secondary-fixed-dim: '#82da8b'
  on-secondary-fixed: '#002108'
  on-secondary-fixed-variant: '#00531e'
  tertiary-fixed: '#e0e4db'
  tertiary-fixed-dim: '#c3c8bf'
  on-tertiary-fixed: '#181d18'
  on-tertiary-fixed-variant: '#434842'
  background: '#f0fdf3'
  on-background: '#131e18'
  surface-variant: '#d9e6dc'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  title-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 26px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  data-mono:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  sidebar_width: 260px
  container_padding: 24px
  gutter: 16px
  row_height_dense: 40px
  row_height_standard: 56px
  stack_sm: 8px
  stack_md: 16px
---

## Brand & Style
The design system is engineered for high-utility enterprise environments, specifically catering and food service administration. The brand personality is professional, dependable, and efficient, prioritizing data clarity over decorative flair.

The visual style follows a **Corporate / Modern** aesthetic with a subtle **Organic** influence derived from the green-centric palette. It utilizes a structured hierarchy, clean lines, and a high-density information architecture to ensure administrators can manage complex logistics with minimal cognitive load. The atmosphere is calm and focused, evoking the reliability required in professional kitchen and event management.

## Colors
The palette is rooted in a "Fresh Professional" spectrum. The primary **Deep Green** provides an authoritative anchor for navigation and primary actions, while the **Fresh Green** accent is used for highlights and active states.

- **Backgrounds:** The application uses a tinted off-white (`#F7FBF2`) to reduce eye strain compared to pure white, providing a soft contrast for the primary white surface cards.
- **Typography:** The core text color is a deep charcoal-green to maintain a softer, more premium feel than pure black, while muted text provides clear hierarchical separation for metadata.
- **System States:** Standardized semantic colors for success, warning, and error ensure critical operational feedback is immediately recognizable.

## Typography
This design system utilizes **Inter** for its exceptional legibility and systematic approach to interface design. The type scale is optimized for density and readability.

- **Headlines:** Use tighter letter spacing and semi-bold weights to create strong visual anchors for page headers.
- **Body:** The 14px size is the workhorse for data tables and forms to maximize information density without sacrificing readability.
- **Labels:** Uppercase or bolded 12px labels are used for table headers and form field captions to provide clear structural categorization.

## Layout & Spacing
The layout employs a **Fixed Sidebar** model for consistent navigation. The main content area uses a fluid grid with fixed outer margins.

- **Sidebar:** A constant 260px left-hand navigation allows for deep nested menu structures essential for SaaS administration.
- **Density:** Spacing is compact. A 4px/8px baseline grid ensures alignment across all components. 
- **Data Tables:** Tables should utilize sticky headers. Standard rows are 56px, while "Dense Mode" can be toggled to 40px for auditing large datasets.
- **Breakpoints:**
  - Desktop: 1200px+ (Standard Sidebar)
  - Tablet: 768px - 1199px (Collapsed Sidebar/Icon Only)
  - Mobile: <768px (Hamburger menu, full-width content stack)

## Elevation & Depth
The design system uses **Tonal Layers** and **Low-Contrast Outlines** rather than heavy shadows to maintain a clean, professional aesthetic.

- **Level 0 (Background):** `#F7FBF2` - The canvas.
- **Level 1 (Surface):** `#FFFFFF` - Primary cards and containers, defined by a 1px solid border of `#D8DBD3`.
- **Level 2 (Hover/Active):** Subtle elevation using a very soft shadow (0px 2px 4px rgba(31, 42, 36, 0.05)) and a slightly darker border.
- **Level 3 (Modals/Popovers):** Higher elevation with a diffused shadow to indicate clear separation from the workspace.

Interactions are primarily communicated through color shifts (e.g., button hover states) rather than dramatic changes in depth.

## Shapes
The shape language is consistently **Rounded**. A base radius of 8px (`rounded-md` equivalent) is applied to all primary containers, input fields, and buttons.

- **Small elements (Checkboxes, Tags):** Use 4px radius for precision.
- **Medium elements (Buttons, Inputs, Cards):** Use 8px radius for a modern, approachable feel.
- **Large elements (Modals, Featured Sections):** Use 12px or 16px radius.
- **Data Highlight:** Table row selections should use a 4px radius on the selection indicator or highlight bar.

## Components
- **Buttons:** Primary buttons use `#2F7D46` with white text. Secondary buttons use a white background with a `#D8DBD3` border and `#1F2A24` text.
- **Input Fields:** 8px rounded corners with a 1px border. On focus, the border shifts to the primary green with a soft 2px outer glow.
- **Data Tables:** Sticky headers with a light grey background (`#F9FAFA`). Borders are horizontal-only to emphasize the row flow. Use "Status Chips" within cells to indicate order status.
- **Status Chips:** Small, rounded-pill components using light tinted backgrounds of the semantic colors (e.g., Success: light green background with dark green text).
- **Navigation:** The 260px sidebar uses a dark theme (optional) or a high-contrast light theme with the primary green indicating the active page via a left-edge 4px accent bar.
- **Cards:** All cards must have a 1px border. Padding inside cards is standardized at 24px for desktop and 16px for mobile.