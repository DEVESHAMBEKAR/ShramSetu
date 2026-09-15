---
name: Elite Service Standard
colors:
  surface: '#faf8fe'
  surface-dim: '#dbd9df'
  surface-bright: '#faf8fe'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f4f3f8'
  surface-container: '#efedf3'
  surface-container-high: '#e9e7ed'
  surface-container-highest: '#e3e2e7'
  on-surface: '#1a1b1f'
  on-surface-variant: '#444748'
  inverse-surface: '#2f3034'
  inverse-on-surface: '#f1f0f6'
  outline: '#747878'
  outline-variant: '#c4c7c7'
  surface-tint: '#5f5e5e'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#1c1b1b'
  on-primary-container: '#858383'
  inverse-primary: '#c8c6c5'
  secondary: '#5a38e4'
  on-secondary: '#ffffff'
  secondary-container: '#7357fe'
  on-secondary-container: '#fffbff'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#002113'
  on-tertiary-container: '#229567'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e5e2e1'
  primary-fixed-dim: '#c8c6c5'
  on-primary-fixed: '#1c1b1b'
  on-primary-fixed-variant: '#474646'
  secondary-fixed: '#e5deff'
  secondary-fixed-dim: '#c8bfff'
  on-secondary-fixed: '#1a0063'
  on-secondary-fixed-variant: '#4413d0'
  tertiary-fixed: '#8df7c1'
  tertiary-fixed-dim: '#71dba6'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005235'
  background: '#faf8fe'
  on-background: '#1a1b1f'
  surface-variant: '#e3e2e7'
typography:
  display:
    fontFamily: Plus Jakarta Sans
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
  display-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 38px
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 36px
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 30px
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
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 18px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 14px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-desktop: 1.5rem
  margin: 1rem
  margin-tablet: 2rem
  margin-desktop: 3rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system delivers an elite, hyper-polished consumer service marketplace experience. Rooted in tactile clarity, modern luxury, and immediate trust, it bridges high-end service seekers with vetted, top-tier professionals. The aesthetic avoids utilitarian drabness, leaning instead into deliberate contrasts, pristine canvases, and surgical attention to micro-details.

The emotional goal is absolute confidence and effortless efficiency. Users must feel the precision of an Apple-grade ecosystem mixed with the authoritative operational reliability of an elite concierge app.

### Design Movement & Aesthetic Principles
- **Modern High-Contrast Precision:** Crisp white surfaces framed by deep obsidian typography and hairline borders. No ambiguous grays or muddy mid-tones.
- **Architectural Clarity:** Layouts rely on strict vertical rhythms, generous whitespace, and disciplined component hierarchies.
- **Micro-Delight & Tactile Polish:** Restrained use of vivid royal violet accenting and emerald verification indicators guarantees high visibility for critical decision-making nodes (ratings, guarantees, instantaneous booking triggers).

## Colors

The palette relies on stark, purposeful contrasts between pure luminescent surfaces and pitch-black focal points, accented by royal violet and emerald green for high-intent actions and verified states.

### Palette Breakdown
- **Canvas & Surfaces:**
  - Background Canvas: `#F7F7F8` for subtle canvas definition; pure `#FFFFFF` for actionable cards and elevation containers.
  - Subsurface / Inset: `#F0F0F2` for input fields, toggle tracks, and pill containers.
- **Obsidian Dark (Primary):**
  - `#111111` anchors high-contrast CTAs, key titles, and primary icons. It communicates authoritative execution and structural permanence.
  - `#1E1E24` serves as an alternate dark for selected states, high-priority badges, and floating bottom sheets.
- **Royal Violet / Indigo (Secondary Accent):**
  - `#4B22D6` and energetic highlight `#6B3CE9`. Reserved for brand moments, active tab underlines, checkout value highlights, and primary promotional accents.
- **Emerald Green (Trust & Verification):**
  - `#00875A` explicitly handles high-trust moments: 5-star rating tags, "UC Verified" partner shields, safety guarantees, and positive discount deductions.
- **Neutrals & Hairlines:**
  - Secondary Copy: `#6E6E73` provides legible hierarchy without drawing focal competition.
  - Subtle Borders & Dividers: `#E5E5EA` and hairline `#EEEEEE`. Never exceed 1px stroke weight; borders frame geometry without visual noise.

## Typography

The typography leverages `Plus Jakarta Sans` across all weights to marry friendly geometric clarity with tech-forward authority.

### Typographic Rules
- **Tracking:** Headlines feature subtle negative tracking (`-0.02em`) to deliver a compact, editorial impact. Labels under 12px utilize slight positive tracking (`+0.01em`) to preserve legibility on dense pricing matrices.
- **Hierarchy Enforcement:** Never place secondary text adjacent to primary text without an explicit contrast step (e.g., `#111111` 600 weight next to `#6E6E73` 400 weight).
- **Numbers & Metrics:** Ratings, service prices, and turnaround times use 600 or 700 weights with tabular figures to avoid ragged alignment in cart totals and quote breakdowns.

## Layout & Spacing

The layout is built upon an 8-point spatial cadence paired with an adaptable responsive grid system designed for mobile-first marketplace transactions.

### Form Factor Breakpoints
- **Mobile (< 768px):** 4-column fluid layout with `1rem` (16px) margins and gutters. Key interactions stay reachable within the bottom thumb zone via sticky drawers and bottom navigation bars.
- **Tablet (768px - 1024px):** 8-column layout with `2rem` margins and `1rem` gutters. Splits marketplace service categories into dual-column cards and multi-card horizontal scrollers.
- **Desktop (> 1024px):** 12-column fixed container capped at `1280px` max-width, with `3rem` margins and `1.5rem` gutters. Employs a 7:5 split layout on detail pages (left side: service configuration, inclusions, and reviews; right side: sticky booking engine and summary).

### Spatial Application
- **Micro Spacing (`space-xs` to `space-sm`):** Icon-to-label gaps, badge inner padding, metadata bullet delimiters.
- **Component Padding (`space-md` to `space-lg`):** Internal card padding, sheet margins, modular item blocks.
- **Section Rhythm (`space-xl` and above):** Clean breathing room between service categories, partner guarantees, and customer reviews.

## Elevation & Depth

Elevation conveys tangible, premium tactility without heavy drop shadows or visual clutter. The system combines multi-layered micro-shadows with razor-sharp hairline borders.

### Elevation Levels
- **Level 0 (Flat Canvas):** `#F7F7F8` background with zero shadow. Used for the base screen canvas.
- **Level 1 (Card & Modular Tier):** Pure `#FFFFFF` fill resting on canvas, bound by a 1px border of `#E5E5EA` and a dual micro-shadow: `0 1px 2px rgba(0, 0, 0, 0.04), 0 2px 8px rgba(0, 0, 0, 0.02)`.
- **Level 2 (Interactive Hover & Flyout):** Floating pill navigations, date picker popups, and hovered cards: `0 4px 16px rgba(0, 0, 0, 0.06), 0 1px 3px rgba(0, 0, 0, 0.04)`.
- **Level 3 (Sticky Checkout Drawers & Modals):** Bottom sheets and sticky checkout banners: `0 -4px 24px rgba(0, 0, 0, 0.08), 0 -1px 4px rgba(0, 0, 0, 0.02)`.

### Border Overlay Technique
Surfaces at Level 1 and Level 2 maintain a constant 1px hairline perimeter (`#E5E5EA` or `#EEEEEE`). Shadows provide diffuse separation, while the hairline guarantees contrast against near-white canvases.

## Shapes

The design system employs a refined rounded shape language (`roundedness: 2`), projecting accessibility, modern warmth, and structural polish.

### Radius Scale
- **Base Elements (`0.5rem` / 8px):** Stepper buttons, internal thumbnail images, service feature pills, and inline dropdown menus.
- **Containers & Cards (`rounded-lg` - `1rem` / 16px):** Primary marketplace cards, modal dialogs, review blocks, and accordion headers.
- **Large Contextual Units (`rounded-xl` - `1.5rem` / 24px):** Bottom sheet containers, hero promotional banners, and category hubs.
- **Full Pill (`9999px`):** Status indicators, price tags, "Add" stepper controls, and verified badges.

## Components

### Buttons & CTAs
- **Primary CTA:** Solid obsidian `#111111` background, `#FFFFFF` text, `rounded-lg`, `label-lg` typography. 0 2px 6px shadow. Pressed state: scale(0.98) with `#1E1E24`.
- **Secondary CTA:** Pure `#FFFFFF` background, `#111111` border (`1px solid #E5E5EA`), `#111111` text.
- **Brand Accent CTA:** Solid `#4B22D6` with white text; reserved for special campaigns, checkout milestones, or subscription upgrades.
- **Service Add / Quantity Stepper Button:** Minimalist white capsule pill (`9999px`) with `#E5E5EA` border, housing obsidian `+` and `-` icons flanking bold numerical counts. Emits emerald feedback on quantity increments.

### Cards
- **Service Card:** Base `#FFFFFF`, 16px border-radius, hairline `#E5E5EA` border, Level 1 shadow. Image sits flush or with 8px radius; title in `headline-sm`, pricing in bold tabular `title-md`, secondary descriptive bullets in `#6E6E73`.
- **Trust & Rating Badges:** Embedded emerald pills (`#00875A` background with `#FFFFFF` text or `#F0FDF4` tint with `#00875A` text) displaying verified star values with zero visual artifacts.

### Chips & Filter Pills
- **Inactive:** `#FFFFFF` surface, 1px `#E5E5EA` border, `#6E6E73` text, `9999px` pill radius.
- **Active:** `#111111` background with white text, or `#F3E8FF` lavender background with `#4B22D6` text and border for brand filtering modes.

### Input Fields
- **Container:** `#F0F0F2` background, transitioning to `#FFFFFF` on active focus. 1px border shifting from transparent to `#111111`. 12px corner radius.
- **Typography:** Placeholder text in `#6E6E73`, active user input in `#111111`. Clear labels positioned above in `label-md`.

### Checkboxes & Radio Controls
- Unselected: 1.5px border of `#E5E5EA`, white fill, 6px radius (checkbox) or circular (radio).
- Selected: Solid `#111111` fill containing pure white check icon or concentric ring.

### Floating Cart & Bottom Sticky Sheet
- Clean mobile-anchored bar: Level 3 shadow, white surface, separated by hairline `#EEEEEE`. Left edge displays itemized count and total; right edge hosts the primary obsidian "View Cart / Proceed" CTA button.