# Theme Color Reference

Unified color palette using Tailwind CSS naming convention.

## Core Color Palette

### Gray Scale

| Variable | Hex | RGBA | Usage |
|----------|-----|------|-------|
| `gray-50` | `#fafafa` | `rgba(250, 250, 250, 1)` | Primary text |
| `gray-300` | `#dcdcdc` | `rgba(220, 220, 220, 0.8)` | Secondary text |
| `gray-400` | `#b4b4b4` | `rgba(180, 180, 180, 1)` | Accents, muted elements |
| `gray-800` | `#20262a` | `rgba(32, 38, 42, 0.5)` | Cards, surfaces |
| `gray-900` | `#16161b` | `rgba(22, 22, 27, 0.8)` | Main background |

### Semantic Colors

| Variable | Hex | RGBA | Usage |
|----------|-----|------|-------|
| `red-500` | `#ff6464` | `rgba(255, 100, 100, 1)` | Errors, warnings |
| `green-500` | `#64c864` | `rgba(100, 200, 100, 1)` | Success, active states |

### Alpha Overlays

| Variable | RGBA | Usage |
|----------|------|-------|
| `alpha-subtle` | `rgba(255, 255, 255, 0.02)` | Very subtle dividers |
| `alpha-light` | `rgba(255, 255, 255, 0.05)` | Borders, subtle overlays |
| `alpha-medium` | `rgba(255, 255, 255, 0.1)` | Active borders, hover states |
| `alpha-dark` | `rgba(0, 0, 0, 0.5)` | Modals, tooltips, dark overlays |

---

## Migration from Old Variables

| Old | New | Notes |
|-----|-----|-------|
| `bg` | `gray-900` | Main background |
| `bg-card` | `gray-800` | Surface background |
| `fg` | `gray-50` | Primary text |
| `fg-dim` | `gray-300` | Secondary text |
| `accent` | `gray-400` | Was misnamed |
| `border` | `alpha-medium` | Was hardcoded rgba |
| `red` | `red-500` | |
| `green` | `green-500` | |
| `white` | *removed* | Use inline when needed |
| `black` | *removed* | Use inline when needed |

---

## Quick Reference

```
TEXT             BACKGROUNDS       SEMANTIC         ALPHA
───────          ────────────      ─────────       ──────────
gray-50          gray-900          red-500         subtle (0.02)
gray-300         gray-800          green-500       light  (0.05)
gray-400                                           medium (0.1)
                                                   dark   (0.5)
```

---

**Last Updated:** 2025-11-14
