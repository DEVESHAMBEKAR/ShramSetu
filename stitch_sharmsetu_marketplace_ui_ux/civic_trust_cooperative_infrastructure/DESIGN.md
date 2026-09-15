---
name: Civic Trust & Cooperative Infrastructure
colors:
  surface: '#f8f9ff'
  surface-dim: '#ccdbf3'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e6eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d5e3fc'
  on-surface: '#0d1c2e'
  on-surface-variant: '#45464e'
  inverse-surface: '#233144'
  inverse-on-surface: '#eaf1ff'
  outline: '#75777f'
  outline-variant: '#c5c6cf'
  surface-tint: '#505e80'
  primary: '#000f2e'
  on-primary: '#ffffff'
  primary-container: '#162544'
  on-primary-container: '#7e8cb1'
  inverse-primary: '#b8c6ed'
  secondary: '#a63b00'
  on-secondary: '#ffffff'
  secondary-container: '#ff793f'
  on-secondary-container: '#652100'
  tertiary: '#001505'
  on-tertiary: '#ffffff'
  tertiary-container: '#002d10'
  on-tertiary-container: '#3d9f58'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d9e2ff'
  primary-fixed-dim: '#b8c6ed'
  on-primary-fixed: '#0a1b39'
  on-primary-fixed-variant: '#384667'
  secondary-fixed: '#ffdbce'
  secondary-fixed-dim: '#ffb599'
  on-secondary-fixed: '#370e00'
  on-secondary-fixed-variant: '#7f2b00'
  tertiary-fixed: '#95f8a7'
  tertiary-fixed-dim: '#79db8d'
  on-tertiary-fixed: '#00210a'
  on-tertiary-fixed-variant: '#005323'
  background: '#f8f9ff'
  on-background: '#0d1c2e'
  surface-variant: '#d5e3fc'
typography:
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
  display-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 38px
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  title-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-mobile: 0.75rem
  margin: 1.5rem
  margin-mobile: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.25rem
---

## Brand & Style

The design system establishes an authentic, institutional, and human-centric digital language for civic trade, cooperative labor, and decentralized commerce. It balances the sovereign gravity of constitutional public digital infrastructure (reminiscent of DigiLocker, BHIM, and ONDC) with the tactile warmth of grassroots enterprise and cooperative solidarity.

### Design Movement & Aesthetic
- **Institutional Clarity & Warm Utility**: A structured, accessible framework driven by functional density, crisp surface delineation, and immediate legibility under harsh sunlight and low-cost mobile displays.
- **Physical Ledger Metaphor**: Surfaces, tables, passbooks, and verification badges evoke physical stamp duties, municipal registries, and paper certificates, translated seamlessly into modern, responsive digital primitives.
- **Dignity & Accessibility**: Void of ephemeral tech-startup trends (no glassmorphic glow or neon synthetics). Typography and color deliver high readability across multilingual contexts, multi-generational users, and varying device capabilities.

## Colors

The palette grounds the interface in public trust, economic security, and organic warmth, strictly avoiding oversaturated digital tones.

### Functional Palette Structure
- **Primary (`#162544`) — Deep Navy Trust**: Represents administrative stability, legal integrity, and structural reliability. Used for primary interactive triggers, primary navigation bars, dominant headers, and core brand anchoring.
- **Secondary (`#D95D24`) — Terracotta Ochre**: Connects the digital ecosystem to Indian soil, handcraft, and cooperative trade. Used as a warm human touchpoint for call-to-action moments, primary notifications, and highlight badges without aggressive neon luminance.
- **Tertiary / Success (`#15803D`) — Forest Emerald**: Signifies verification, zero-commission guarantees, biometric clearances, and escrow balances. An organic, earth-rooted green that inspires financial peace-of-mind.
- **Neutral Core (`#475569`) & Text Levels**:
  - `High Contrast Slate` (`#0F172A`): Primary headings, monetary values, and legal terms.
  - `Body Slate` (`#334155`): Secondary descriptions and body text.
  - `Subtle / Ledger Slate` (`#64748B`): Meta stamps, timestamps, and placeholder copy.
- **Backgrounds & Structural Borders**:
  - Canvas / Foundation: `#F8F9FA` (Civic Off-White).
  - Elevated Cards / Modals: `#FFFFFF` (Stark White).
  - Tonal Recesses / Data Insets: `#F1F3F5` & `#E9ECEF`.
  - Hairline Dividers & Outlines: `#E2E8F0` and `#CBD5E1`.

## Typography

Typography establishes an institutional standard: structured, highly legible at small sizes, and resistant to distortion on varying screen densities.

- **Headlines (Plus Jakarta Sans)**: Used for main titles, balance metrics, account headers, and section statements. Provides a warm, confident, and contemporary presence without being decorative.
- **Body & Data Displays (Inter)**: Built for high-density readability in financial receipts, job orders, wage slips, and cooperative bylaws. Excellent x-height prevents fatigue during repetitive administrative use.
- **Currency & Metric Formatting**: Numerical sums, escrow amounts, and biometric tokens must use tabular/monospaced numbers (`font-feature-settings: 'tnum' on`) to ensure columns align across mobile and desktop interfaces.

## Layout & Spacing

The layout philosophy follows a disciplined, utility-driven fluid grid system calibrated for mobile-first utility in the field and structured data dashboards on desktop workstations.

- **Breakpoints**:
  - Mobile (`< 640px`): 4-column layout, edge margins of `1rem` (`16px`), gutters of `0.75rem` (`12px`). Critical actions and navigation remain bottom-docked within thumb reach.
  - Tablet (`640px - 1024px`): 8-column layout, edge margins of `1.5rem` (`24px`), gutters of `1rem` (`16px`).
  - Desktop (`> 1024px`): 12-column fixed-max layout (max width `1200px`), edge margins of `2rem` (`32px`), gutters of `1.5rem` (`24px`).
- **Spacing Rhythm**: Governed by an 8px spatial grid with an intermediate 4px micro-token (`space-xs`) for form labels and icon-to-text alignments. Dense layouts allow operators and cooperative administrators to view critical audit trails without excessive vertical travel.

## Elevation & Depth

To remain grounded, clear, and functional, this design system avoids heavy drop shadows or dramatic Z-index stacking. Depth is achieved via **tonal layering coupled with crisp structural outlines**.

- **Level 0 (Base Foundation)**: Canvas background `#F8F9FA`. Recessed containers use `#F1F3F5` with a subtle outline of `1px solid #E2E8F0`.
- **Level 1 (Card & Module Resting)**: Pristine white `#FFFFFF` surface enclosed in a `1px solid #E2E8F0` border. Ambient shadow is strictly restrained: `0 1px 3px 0 rgba(15, 23, 42, 0.05)`.
- **Level 2 (Interactive Floating / Active State)**: Dropdown drawers, pinned bottom action panels, and sticky header summaries use `#FFFFFF` enclosed in `1px solid #CBD5E1` with a calibrated shadow: `0 4px 6px -1px rgba(15, 23, 42, 0.07), 0 2px 4px -2px rgba(15, 23, 42, 0.05)`.
- **Escrow & Trust Enclosures**: Escrow locked modules and verified credentials feature a deliberate left-accent stroke (`3px solid #15803D`) rather than multi-layered shadows to communicate status instantly.

## Shapes

The design system embraces a **Soft (Level 1)** geometry, establishing a neat, municipal, and functional profile. 

- **Base Components (Inputs, Buttons, Badges)**: Corner radius is standardized at `0.25rem` (`4px`). This slight softening maintains the formal authority of paper documentation and legal registries without feeling harsh or jagged.
- **Cards & Data Modules (`rounded-lg`)**: Structured with `0.5rem` (`8px`) border radius, preserving compact layout density while delineating discrete chunks of verification data.
- **Overlays, Sheets & Modals (`rounded-xl`)**: Configured with `0.75rem` (`12px`) along top edges for mobile drawer dismissals.
- **Pill Exceptions**: Small status pills (e.g., "KYC Active", "Direct Escrow") may employ full-radius rounding (`9999px`) purely to separate metadata tags from actionable rectilineal buttons.

## Components

### Buttons
- **Primary Administrative Action**: Background `#162544`, text `#FFFFFF`, border `1px solid #0F1E36`, corner radius `4px`. Hover / active shifts to `#0F1E36`.
- **Secondary Civic / Highlight Action**: Background `#D95D24`, text `#FFFFFF`, border `1px solid #C84E1B`. Used for pivotal commitments (e.g., "Accept Job Contract", "Release Payment").
- **Tertiary / Outline**: Background `#FFFFFF`, text `#162544`, border `1px solid #CBD5E1`. Hover uses `#F1F3F5`.
- **Height**: Mobile target `48px` minimum to ensure unhindered field usability; desktop default `40px`.

### Verification Chips & Badges
- **KYC / Escrow Settled**: Background `#F0FDF4`, border `1px solid #BBF7D0`, text `#15803D`. Accompanied by a bold verification tick icon.
- **Pending / Audit**: Background `#FFFBEB`, border `1px solid #FDE68A`, text `#B45309`.
- **Neutral Categorization**: Background `#F1F3F5`, border `1px solid #E2E8F0`, text `#475569`.

### Input Fields & Controls
- **Text Inputs**: Surface `#FFFFFF`, border `1px solid #CBD5E1`, text `#0F172A`, placeholder `#94A3B8`. Focus state applies border `#162544` with a sharp `2px` focus ring in `rgba(22, 37, 68, 0.15)`. No floating labels; labels sit decisively above inputs in `label-md` bold slate.
- **Checkboxes & Radios**: Outer border `1.5px solid #94A3B8`, background `#FFFFFF`. Selected state fills with `#162544` and renders a stark white internal glyph.

### Cards & Ledger Tables
- **Civic Record Card**: Base `#FFFFFF`, border `1px solid #E2E8F0`, interior padding `1.25rem`. Section divides within the card use a hairline border (`1px dashed #E2E8F0`) mimicking physical tear-off receipts.
- **Escrow Summary Container**: Subtle tinted background `#F8FAFC`, bordered by `1px solid #E2E8F0` with a solid forest green (`#15803D`) keyline along the active status boundary.
- **Ledger Rows**: Alternate backgrounds between `#FFFFFF` and `#F8F9FA` on dense tabular records, with standard row heights of `44px` for touch accessibility.

### Cooperative Trust Stamp
- An authentic, badge-like component for worker collectives and cooperatives. Composed of an inner hairline border, a dual-ring seal icon, uppercase `label-sm` tracking, and an authentic badge tag confirming sovereign registry registration and 0% intermediary fee status.