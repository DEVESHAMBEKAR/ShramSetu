# UI Design System

Extracted directly from the embedded Tailwind configuration in the Stitch HTML files.

## Colors
- **Primary**: `#031636`
- **On-Primary**: `#ffffff`
- **Primary Container**: `#1a2b4c`
- **Secondary**: `#ac3400`
- **On-Secondary**: `#ffffff`
- **Secondary Container**: `#fd6a37`
- **Tertiary**: `#001d05`
- **Tertiary Container**: `#00340e`
- **Background**: `#f8f9fc`
- **Surface**: `#f8f9fc`
- **Surface Container Lowest**: `#ffffff`
- **Surface Container Low**: `#f2f4f6`
- **Surface Container**: `#eceef0`
- **Surface Container High**: `#e7e8eb`
- **Surface Container Highest**: `#e1e2e5`
- **Error**: `#ba1a1a`
- **Outline**: `#75777f`
- **Outline Variant**: `#c5c6cf`

## Typography
- **Families**:
  - Headings / Display: `Plus Jakarta Sans`
  - Body / Labels: `Inter`
- **Sizes**:
  - `display-lg`: 36px, Bold
  - `headline-lg`: 28px, Bold
  - `headline-md`: 20px, SemiBold
  - `headline-sm`: 18px, SemiBold
  - `title-lg`: 17px, SemiBold
  - `title-md`: 15px, SemiBold
  - `body-lg`: 16px, Regular
  - `body-md`: 14px, Regular
  - `body-sm`: 13px, Regular
  - `label-lg`: 14px, SemiBold
  - `label-md`: 12px, SemiBold
  - `label-sm`: 11px, SemiBold

## Spacing (Gaps/Padding)
- `spacing-4xs`: 0.125rem
- `spacing-3xs`: 0.25rem
- `spacing-2xs`: 0.375rem
- `spacing-xs`: 0.5rem
- `spacing-sm`: 0.75rem
- `spacing-md`: 1rem
- `spacing-lg`: 1.25rem
- `spacing-xl`: 1.5rem
- `margin-mobile`: 1rem
- `margin-tablet`: 2rem

## Border Radius
- `DEFAULT`: 0.25rem
- `lg`: 0.5rem
- `xl`: 0.75rem
- `full`: 9999px

## Components
- **Buttons**: Rounded-full or rounded-xl, primary uses `#031636` background.
- **Cards**: Uses `bg-surface-container-lowest` (white) with `shadow-sm` and `rounded-xl`.
- **Icons**: Material Symbols Outlined.
- **Responsive Behavior**: Built mobile-first. Uses breakpoints like `md:` for larger screens, but heavily prioritizes a mobile app aesthetic.
