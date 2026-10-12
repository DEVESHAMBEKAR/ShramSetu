---
name: Bharat Civic Infrastructure
colors:
  surface: '#f7f9fb'
  surface-dim: '#d8dadc'
  surface-bright: '#f7f9fb'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f6'
  surface-container: '#eceef0'
  surface-container-high: '#e6e8ea'
  surface-container-highest: '#e0e3e5'
  on-surface: '#191c1e'
  on-surface-variant: '#43474d'
  inverse-surface: '#2d3133'
  inverse-on-surface: '#eff1f3'
  outline: '#74777e'
  outline-variant: '#c3c6ce'
  surface-tint: '#49607c'
  primary: '#00152a'
  on-primary: '#ffffff'
  primary-container: '#102a43'
  on-primary-container: '#7a92b0'
  inverse-primary: '#b0c9e8'
  secondary: '#a83900'
  on-secondary: '#ffffff'
  secondary-container: '#fe7034'
  on-secondary-container: '#5f1d00'
  tertiary: '#00190a'
  on-tertiary: '#ffffff'
  tertiary-container: '#003018'
  on-tertiary-container: '#44a16a'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d1e4ff'
  primary-fixed-dim: '#b0c9e8'
  on-primary-fixed: '#011d35'
  on-primary-fixed-variant: '#314863'
  secondary-fixed: '#ffdbcf'
  secondary-fixed-dim: '#ffb59a'
  on-secondary-fixed: '#380d00'
  on-secondary-fixed-variant: '#802a00'
  tertiary-fixed: '#99f6b7'
  tertiary-fixed-dim: '#7dda9d'
  on-tertiary-fixed: '#00210f'
  on-tertiary-fixed-variant: '#00522d'
  background: '#f7f9fb'
  on-background: '#191c1e'
  surface-variant: '#e0e3e5'
typography:
  headline-xl:
    fontFamily: Public Sans
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 52px
    letterSpacing: -0.02em
  headline-xl-mobile:
    fontFamily: Public Sans
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg:
    fontFamily: Public Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 44px
    letterSpacing: -0.015em
  headline-lg-mobile:
    fontFamily: Public Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Public Sans
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 34px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Public Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 30px
  title-lg:
    fontFamily: Public Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 28px
  title-md:
    fontFamily: Public Sans
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Noto Sans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 30px
  body-md:
    fontFamily: Noto Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 26px
  body-sm:
    fontFamily: Noto Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 22px
  label-lg:
    fontFamily: Public Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.02em
  label-md:
    fontFamily: Public Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 18px
    letterSpacing: 0.03em
  label-sm:
    fontFamily: Public Sans
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.04em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  gutter: 1.5rem
  gutter-sm: 1rem
  margin: 2rem
  margin-sm: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

## Brand & Style

This design system establishes an authoritative, accessible, and dignified visual foundation for national-scale Digital Public Infrastructure (DPI). The interface balances sovereign institutional trust with civic warmth, rejecting ornate ornamentation in favor of absolute clarity, low cognitive load, and high transactional confidence across a demographic spectrum spanning rural first-time mobile users to urban enterprise administrators.

The design movement combines **Corporate Modern** rigor with **Tactile Utility**:
- **Institutional Weight:** Grounded in sovereign presence through deep maritime tones and crisp informational divisions.
- **Universal Clarity:** Uncompromising contrast ratios, generous touch targets (minimum 48px), and legible typographic hierarchy capable of rendering complex non-Latin scripts without clipping or vertical misalignment.
- **Verification-First Affordances:** Physical badges, explicit authentication states, and clear ledger-style status indicators designed to demystify complex state mechanisms (Aadhaar/UIDAI, DigiLocker, UPI, eSign).

## Colors

The color system draws from sovereign civic identity, calibrated strictly for WCAG 2.1 AA/AAA compliance on both standard and low-cost, low-gamut mobile displays.

- **Primary (`#102A43` — Ashoka Navy):** Represents sovereign governance, institutional longevity, and structured authority. Used for primary app bars, main structural headings, dominant actions, and high-level navigational chrome.
- **Secondary (`#E05A1F` — Civic Saffron / Terracotta):** Represents citizen momentum and action. Reserved strictly for primary calls-to-action (CTAs), urgent citizen notices, key workflow steps, and active focus boundaries.
- **Tertiary (`#137A47` — Bharat Green):** The color of national verification, authenticity, and legal finality. Deployed exclusively for verified document badges (DigiLocker, Aadhaar authentication, digital signatures), approved application statuses, and monetary success confirmations.
- **Neutral Background & Surface (`#F8FAFC` & `#FFFFFF`):** High-clarity, cool-tinted off-white surfaces prevent glare while maximizing text sharpness.
- **Structural Outlines (`#E2E8F0`):** Defines clean component envelopes and card surfaces without creating visual clutter.
- **Typography Neutrals:** Canvas body text is anchored at `#0F172A` (950) with secondary metadata at `#475569` (600), securing a contrast ratio well above 7:1 against light surfaces.

## Typography

To support India's 22 scheduled languages seamlessly (Devanagari, Dravidian, Eastern Nagari, Gurmukhi, Nastaliq, and Ol Chiki scripts), the system pairs **Public Sans** for Latin administrative structures and headlines with **Noto Sans** (and its regional script counterparts) for all multi-script body and conversational text.

- **Vertical Metric Protection:** Indic scripts possess intricate conjuncts, matras, and vowel markers above and below the baseline. Body text is assigned a minimum `1.6x` line-height ratio to prevent diacritic clipping across all localized renderings.
- **Variable Font Fallback Hierarchy:** Systems must resolve glyphs through the local OS language pack before falling back to system defaults. The primary fallback sequence is: `Noto Sans, Noto Sans Devanagari, Noto Sans Tamil, Noto Sans Telugu, Noto Sans Bengali, sans-serif`.
- **Numerals:** Tabular figures are mandatory for application reference numbers, IFSC codes, Aadhaar masked identifiers, and rupee currency metrics.

## Layout & Spacing

The layout is built upon an 8pt baseline grid with an adaptive column framework designed for multi-tier device performance:

- **Mobile Viewports (<640px):** 4 columns, `margin-sm` (1rem / 16px), `gutter-sm` (1rem / 16px). Bottom-anchored navigation and sticky submit actions allow single-handed operation.
- **Tablet / Portal Viewports (640px - 1024px):** 8 columns, `margin` (2rem / 32px), `gutter` (1.5rem / 24px). Dual-pane layouts for form review and document inspection.
- **Desktop / CSC Operator Viewports (>1024px):** 12 columns, max-width constrained to `1280px` to maintain optimal line reading length, with standardized lateral gutters (1.5rem / 24px).

Components adhere strictly to touch accessibility: interactive targets never drop below 48x48px on mobile viewports, even when labels contain short localized strings.

## Elevation & Depth

To guarantee usability under intense sunlight on low-cost IPS displays, visual hierarchy relies on **crisp structural borders** and **purposeful tonal layers** rather than soft, low-contrast shadows.

- **Base Layer (Ground):** `#F8FAFC` represents background canvas space.
- **Card & Container Layer (Level 0):** Pure `#FFFFFF` surface bordered by a 1px solid `#E2E8F0` stroke.
- **Interactive / Elevated Layer (Level 1):** Employed exclusively for menus, localized language pickers, and active modals. Defined by a 1px border (`#CBD5E1`) paired with a tight ambient shadow: `0 4px 6px -1px rgba(16, 42, 67, 0.08), 0 2px 4px -2px rgba(16, 42, 67, 0.04)`.
- **Critical Dialogs (Level 2):** Biometric confirmation sheets and OTP authorization modals utilize `0 20px 25px -5px rgba(16, 42, 67, 0.12), 0 8px 10px -6px rgba(16, 42, 67, 0.06)` with a 50% opacity Ashoka Navy backdrop overlay (`rgba(16, 42, 67, 0.5)`).

## Shapes

The design system employs **Level 1 (Soft)** geometry. Interfaces prioritize functional precision over playful curviness. 

- **Base Corner Radius (0.25rem / 4px):** Standard buttons, text input fields, status chips, and verification badges.
- **Large Components (`rounded-lg`, 0.5rem / 8px):** Civic service cards, informational banners, data tables, and bottom drawers.
- **Full Radius (Pill):** Strictly reserved for dynamic biometric pulse indicators, live queue chips, and counter pills.

## Components

### Buttons
- **Primary Civic Action:** Filled background `#E05A1F`, crisp text `#FFFFFF`, 4px corner radius, bold label. Hover state darkens to `#C2410C`. Focus state has a 2px offset ring in `#102A43`.
- **Institutional Secondary:** Filled `#102A43` with `#FFFFFF` text. Used for sovereign actions like "Authenticate via Aadhaar" or "Proceed to Portal".
- **Tertiary / Outline:** 1.5px border `#102A43`, transparent background, text `#102A43`.
- **Size Standards:** Minimum height 48px on mobile, 40px on desktop operator consoles.

### DigiLocker & Verification Badges
- Verified status displays a `#137A47` badge with a 1px solid `#137A47` border, `#EBF7EE` background, accompanied by a clear checkmark icon and text "DigiLocker Verified" or "Aadhaar Linked".

### Form Inputs & Selectors
- **Fields:** Pure white background, 1px solid border `#CBD5E1`, text `#0F172A`, 4px radius, 48px height.
- **Focus State:** 2px solid `#102A43` border with zero blur spread to preserve edge sharpness.
- **Floating Script Labels:** Labels sit above the field with explicit font sizing to prevent script overlap during multi-lingual toggling.

### Checkboxes & Radios
- Size: 20x20px with a 2px border `#102A43`. Selected fill uses `#102A43` with a sharp white checkmark. Touch bounding target is padded to 48x48px.

### Language Switcher (Civic Critical)
- Persistent header component with high contrast. Uses an icon and direct endonym representation (e.g., "English / हिन्दी / தமிழ்") rather than translated equivalents. Displays active selection in an Ashoka Navy pill with 1px border.

### Identity & Scheme Cards
- Background `#FFFFFF`, 1px border `#E2E8F0`, 8px corner radius. A left-edge 4px vertical accent stripe identifies the scheme category (Civic Saffron for pensions/welfare, Ashoka Navy for tax/identity, Bharat Green for agriculture/health).