# Theme Color Reference

Unified color palette using Base16 color scheme format. All theme files are automatically generated from the flavours Base16 scheme using `flavours`.

**⚠️ Important:** Theme files (`.scss`, `.conf`, `.toml`, etc.) are generated automatically. Do not edit them directly. To change colors, edit the Base16 scheme file and run `dotfiles theme apply`.

## Base16 Color Scheme

Colors are defined in `stow/flavours/.config/flavours/schemes/default/default.yaml` using the Base16 standard format. The scheme uses 16 colors (base00-base0F) that are automatically mapped to application-specific formats by `flavours`.

### Base16 Color Mappings

| Base16 | Hex | Tailwind Equivalent | Usage |
|--------|-----|---------------------|-------|
| `base00` | `#16161b` | `gray-900` | Default Background - main background |
| `base01` | `#20262a` | `gray-800` | Lighter Background - cards, surfaces |
| `base02` | `#495057` | - | Selection Background |
| `base03` | `#4a4a4a` | - | Comments, Invisibles, Line Highlighting |
| `base04` | `#b4b4b4` | `gray-400` | Dark Foreground - accents, muted elements |
| `base05` | `#dcdcdc` | `gray-300` | Default Foreground - secondary text |
| `base06` | `#f0f0f0` | - | Light Foreground |
| `base07` | `#fafafa` | `gray-50` | Lightest Foreground - primary text |
| `base08` | `#ff6464` | `red-500` | Variables, Errors, Diff Deleted |
| `base09` | `#ffc850` | - | Integers, Constants, Warnings |
| `base0A` | `#ffe066` | - | Classes, Markup Bold |
| `base0B` | `#64c864` | `green-500` | Strings, Success, Diff Inserted |
| `base0C` | `#4ecdc4` | - | Support, Regular Expressions |
| `base0D` | `#74c0fc` | - | Functions, Methods, Headings |
| `base0E` | `#da77f2` | - | Keywords, Storage, Diff Changed |
| `base0F` | `#ff8787` | - | Deprecated, Embedded Language Tags |

### Legacy Tailwind Naming (for reference)

These names are used in generated theme files for clarity, but map to Base16 colors:

| Variable | Base16 | Hex | Usage |
|----------|--------|-----|-------|
| `gray-50` | `base07` | `#fafafa` | Primary text |
| `gray-300` | `base05` | `#dcdcdc` | Secondary text |
| `gray-400` | `base04` | `#b4b4b4` | Accents, muted elements |
| `gray-800` | `base01` | `#20262a` | Cards, surfaces |
| `gray-900` | `base00` | `#16161b` | Main background |
| `red-500` | `base08` | `#ff6464` | Errors, warnings |
| `green-500` | `base0B` | `#64c864` | Success, active states |

### Alpha Overlays

Alpha overlays are calculated from base colors in generated files:

| Variable | RGBA | Usage |
|----------|------|-------|
| `alpha-subtle` | `rgba(255, 255, 255, 0.02)` | Very subtle dividers |
| `alpha-light` | `rgba(255, 255, 255, 0.05)` | Borders, subtle overlays |
| `alpha-medium` | `rgba(255, 255, 255, 0.1)` | Active borders, hover states |
| `alpha-dark` | `rgba(0, 0, 0, 0.5)` | Modals, tooltips, dark overlays |

---

## How to Modify Colors

1. **Edit the Base16 scheme file:**
   ```bash
   # Edit stow/flavours/.config/flavours/schemes/default/default.yaml
   # Change hex color values (without # prefix)
   ```

2. **Regenerate theme files:**
   ```bash
   dotfiles theme apply
   ```

3. **Restart applications** to see changes

**Note:** All theme files are automatically generated from the flavours scheme. Do not edit generated files directly as they will be overwritten.

---

## Quick Reference

```
BASE16          HEX         TAILWIND      USAGE
──────          ───         ────────     ──────────────
base00          #16161b     gray-900      Main background
base01          #20262a     gray-800      Card/surface
base04          #b4b4b4     gray-400      Accents
base05          #dcdcdc     gray-300      Secondary text
base07          #fafafa     gray-50       Primary text
base08          #ff6464     red-500       Errors
base0B          #64c864     green-500     Success
```

---

## Technical Details

- **Scheme Format:** Base16 YAML (compatible with flavours)
- **Generator:** flavours (https://github.com/misterio77/flavours)
- **Generation:** Automatic on `dotfiles theme apply`
- **Source of Truth:** `stow/flavours/.config/flavours/schemes/default/default.yaml`
- **Templates:** `stow/flavours/.config/flavours/templates/`

---

**Last Updated:** 2025-01-XX (Base16 migration)
