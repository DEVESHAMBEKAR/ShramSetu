---
name: National Civic Infrastructure
colors:
  surface: '#f7f9fc'
  surface-dim: '#d8dadd'
  surface-bright: '#f7f9fc'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f7'
  surface-container: '#eceef1'
  surface-container-high: '#e6e8eb'
  surface-container-highest: '#e0e3e6'
  on-surface: '#191c1e'
  on-surface-variant: '#44474e'
  inverse-surface: '#2d3133'
  inverse-on-surface: '#eff1f4'
  outline: '#74777f'
  outline-variant: '#c4c6cf'
  surface-tint: '#495f82'
  primary: '#001026'
  on-primary: '#ffffff'
  primary-container: '#0b2545'
  on-primary-container: '#778db2'
  inverse-primary: '#b1c7f0'
  secondary: '#a83900'
  on-secondary: '#ffffff'
  secondary-container: '#fc6018'
  on-secondary-container: '#531800'
  tertiary: '#001405'
  on-tertiary: '#ffffff'
  tertiary-container: '#002c10'
  on-tertiary-container: '#3a9e58'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d5e3ff'
  primary-fixed-dim: '#b1c7f0'
  on-primary-fixed: '#001c3b'
  on-primary-fixed-variant: '#314769'
  secondary-fixed: '#ffdbcf'
  secondary-fixed-dim: '#ffb59a'
  on-secondary-fixed: '#380d00'
  on-secondary-fixed-variant: '#802a00'
  tertiary-fixed: '#93f8a8'
  tertiary-fixed-dim: '#77db8e'
  on-tertiary-fixed: '#00210b'
  on-tertiary-fixed-variant: '#005224'
  background: '#f7f9fc'
  on-background: '#191c1e'
  surface-variant: '#e0e3e6'
typography:
  headline-xl:
    fontFamily: Plus Jakarta Sans
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 44px
    letterSpacing: -0.02em
  headline-xl-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.01em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.015em
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '700'
    lineHeight: 28px
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
    lineHeight: 16px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.04em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-md: 1.5rem
  gutter-lg: 2rem
  margin: 1rem
  margin-md: 2rem
  margin-lg: 3rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system establishes an authentic Indian Digital Public Infrastructure (DPI) standard, engineered to deliver civic trust, extreme operational clarity, and accessible public utility at population scale. The UI serves citizens, cooperative federations, informal workers, and state administrators. The visual tone must evoke sovereign credibility, civic dignity, and dependable digital governance—mirroring the institutional stature of the Government of India without the visual fatigue of legacy bureaucratic portals.

The overarching design aesthetic fuses **Corporate / Modern** institutional rigor with **High-Contrast Civic Utility**. Every surface utilizes crisp hairline borders (1px), authentic sovereign Indian colors (State Navy, Kesari/Saffron, Ashoka Blue, and Emerald Green), structured layouts, high-legibility typography, and accessible touch targets designed for multi-tier device ecosystems, low-bandwidth environments, and multi-lingual interfaces.

## Colors

The color palette is rooted in the sovereign and constitutional identity of the Republic of India:

- **Primary (`#0B2545` - Official State Navy):** Anchors headers, primary authority actions, main navigational sidebars, and structural focal points. Used alongside `#002147` (Ashoka Deep Navy) for high-order institutional mandates and title displays.
- **Secondary (`#E65100` / `#FF6F00` - Tiranga Deep Kesari / Saffron):** High-priority civic highlights, system notifications, pending action status, critical citizen alerts, and primary interactive progression cues. Never over-saturated; applied with civic restraint.
- **Tertiary (`#0A7E3C` - Official Emerald Green):** Verification badges, Aadhaar/e-KYC verified markers, completed lifecycle statuses, biometric confirmations, and positive state payouts/disbursements.
- **Secondary Accent (`#133E87` - Ashoka Chakra Blue):** Informational banners, active tabs, secondary links, and civic progress step indicators.
- **Neutral Base (`#F4F6F9` - Soft Slate):** Default background canvas providing superior contrast and eliminating ocular fatigue. Card surfaces remain pure `#FFFFFF`.
- **System Borders (`#DDE2E9`):** Uniform hairline separation token across all interactive cards, data cells, and utility bars.
- **Text & Semantics:** Primary text uses `#131921` (95% contrast ratio against white); secondary assistive text utilizes `#4B5565`. Error states rely on `#C62828`.

## Typography

The type system balances official authority with hyper-legibility across diverse Indian scripts and low-resolution hardware:

- **Headlines (Plus Jakarta Sans):** Selected for crisp, balanced geometric geometry with approachable humanist proportions, providing an authoritative identity for Ministry titles, portal banners, and scheme headers.
- **Body & Labels (Inter):** Utilized for its tall x-height, clear numerical distinction (critical for Aadhaar, UAN, phone numbers, and INR currency displays), and zero ambiguous character forms.
- **Multilingual Standards:** When rendering Indic official languages (Devanagari, Tamil, Telugu, Bengali, etc.), standard fallback font stacks must default to system Noto Sans / local script equivalents matching the height and optical weight of Inter.
- **Numeric Figures:** In financial and identity tables, tabular lining figures (`font-variant-numeric: tabular-nums`) must be enforced.

## Layout & Spacing

The layout is built around a structured 12-column responsive fluid grid designed to handle high data density while sustaining cognitive ease for rapid citizen task completion:

- **Desktop (>= 1200px):** 12-column layout with `margin-lg` (3rem / 48px) and `gutter-lg` (2rem / 32px). Maximum container width is constrained to `1280px` for civic portals or `1440px` for administrative dashboards.
- **Tablet (768px - 1199px):** 8-column layout with `margin-md` (2rem / 32px) and `gutter-md` (1.5rem / 24px).
- **Mobile (< 768px):** 4-column layout with `margin` (1rem / 16px) and `gutter` (1rem / 16px). Bottom sheets, sticky operational buttons, and single-column stacked forms replace sidebars and multi-step horizontal flows.
- **Rhythm:** Spacing follows a modular 4px/8px incremental scale (`space-xs` = 4px, `space-sm` = 8px, `space-md` = 16px, `space-lg` = 24px, `space-xl` = 32px). Padding within interactive data surfaces adheres to compact density (8px to 12px vertical) to maximize visible citizen records per viewport.

## Elevation & Depth

This design system avoids excessive skeuomorphic drop shadows and heavy blur layers in favor of crisp architectural separation:

- **Structural Outlines & Borders:** Depth is primarily defined through high-contrast 1px hairline borders (`#DDE2E9`) that frame elements firmly against the `#F4F6F9` slate canvas.
- **Flat Elevation (Level 0):** Base canvas `#F4F6F9`. Form inputs, resting cards, and standard data regions sit directly at this tier or elevate to `#FFFFFF` using pure border delineation.
- **Raised Surfaces (Level 1 - Civic Card):** Background `#FFFFFF`, border `1px solid #DDE2E9`, shadow `0px 1px 3px rgba(11, 37, 69, 0.06), 0px 1px 2px rgba(11, 37, 69, 0.04)`. Used for scheme application cards, cooperative summaries, and metric widgets.
- **Floating Surfaces (Level 2 - Navigation & Modals):** Background `#FFFFFF`, border `1px solid #CFD8DC`, shadow `0px 4px 12px rgba(11, 37, 69, 0.08), 0px 2px 4px rgba(11, 37, 69, 0.06)`. Reserved for global sticky headers, multi-lingual language selector sheets, and citizen verification dialogs.
- **Overlay States:** Full modal overlays use `rgba(11, 37, 69, 0.65)` (State Navy tint) to retain civic visual grounding during authentication or biometric approval screens.

## Shapes

The shape vocabulary uses the **Soft (Level 1)** philosophy to uphold institutional gravitas and government authority. Overly rounded or playful bubble aesthetics are strictly avoided:

- **Base Radius (0.25rem / 4px):** Applied to form fields, data table rows, utility tooltips, status badges, and inline verification pills.
- **Container Radius (`rounded-lg` / 0.5rem / 8px):** Applied to administrative cards, modal windows, citizen scheme summary blocks, and workflow containers.
- **Emblem & Seal Exceptions:** Official state insignias (State Emblem of India, Ministry crests, Ashoka Chakra symbols) and citizen avatar thumbnails use circular masks (`rounded-full`), framed by a 1px `#DDE2E9` border or secondary Kesari accent ring.

## Components

### 1. Buttons
- **Primary Sovereign Button:** Background `#0B2545` (State Navy), text `#FFFFFF`, border `none`, padding `10px 20px`, font `label-lg`, radius `4px`. Hover state shifts to `#002147`.
- **Secondary / Action Accent:** Background `#E65100` (Deep Kesari), text `#FFFFFF`. Reserved for primary transactional citizen intents ("Apply Now", "Register Cooperative", "Verify Aadhaar OTP").
- **Tertiary / Verified Action:** Background `#0A7E3C` (Emerald), text `#FFFFFF`. Reserved for approved download vouchers, biometric acknowledgments, and claims.
- **Outline / Neutral Button:** Background `#FFFFFF`, text `#0B2545`, border `1px solid #DDE2E9`. Hover state shifts background to `#F4F6F9`.

### 2. Civic Status Chips & Verification Badges
- **Aadhaar / e-KYC Verified:** Background `#E8F5E9`, text `#0A7E3C`, border `1px solid #A5D6A7`. Prepended by a verified tick icon.
- **Pending Review:** Background `#FFF3E0`, text `#E65100`, border `1px solid #FFE082`.
- **Government Official / Ministry Tag:** Background `#E3F2FD`, text `#133E87`, border `1px solid #BBDEFB`.
- All chips enforce uppercase or tracking on `label-sm` with strict 4px padding-y and 8px padding-x.

### 3. Cards & Application Panels
- **Citizen Information Card:** Canvas `#FFFFFF`, border `1px solid #DDE2E9`, radius `8px`. Top card margin features an optional 3px thick institutional status bar (`#0B2545` for official programs, `#E65100` for active schemes, `#0A7E3C` for approved grants).
- **Summary Header:** Includes national scheme emblem on the left, official category name, and right-aligned national tracking ID in tabular mono numerals.

### 4. Input Fields & Form Controls
- **Text Inputs:** Height 44px (touch-compliant for mobile field workers), background `#FFFFFF`, border `1px solid #CBD5E1`, text `#131921`, radius `4px`.
- **Focus State:** 2px solid `#133E87` (Ashoka Blue) with a subtle zero-offset outline ring; no glowing shadows.
- **Identity Fields (UAN, Aadhaar, PAN):** Include dedicated formatting segments with explicit prefix badges and integrated verification status markers at the trailing edge.

### 5. Checkboxes & Radio Buttons
- Square checkboxes and circular radio selectors use `#0B2545` as active fill with an inset `#FFFFFF` tick or dot.
- Unchecked states use a distinct 1.5px border (`#94A3B8`) against white for high outdoors visibility in harsh sunlight conditions.

### 6. Lists & National Registries
- Dense tabular rows with 12px padding-y, separated by 1px solid `#E2E8F0` divider lines.
- Alternate row striping (`#F8FAFC`) on complex data arrays.
- Citizen identifiers, bank account masks, and IFSC codes rendered in fixed-width tabular formatting.

### 7. National Header Bar (Civic Specific Component)
- Top strip (`#002147` - Ashoka Deep Navy): Displays the State Emblem of India, "भारत सरकार | Government of India" in Hindi & English, screen reader access controls, font resizing buttons (`A- | A | A+`), and the official multi-language switch dropdown.