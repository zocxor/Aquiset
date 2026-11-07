# AQUISET Liquid Glass design system

**Status:** approved direction, replaces blueprint section 04 (the earlier "design lock").
The owner chose a full premium redesign on 6 November 2026. Day and Night are still
colour modes only: every screen keeps the same layout, widgets and controls in both.

Visual reference: the *AQUISET Liquid Glass* design canvas (two working phone
prototypes: Hydrate · Day and Sleep · Night).

## 1. Principles

1. **Glass needs something to refract.** Every screen sits on a painted nature
   scene (sky, sun or moon, hills, lake, foreground leaves). Glass over flat
   colour reads as grey plastic.
2. **One primitive.** Every surface is a `GlassSurface` at one of four weights.
   No ad-hoc blurs.
3. **Readable first.** Every text colour passes WCAG 2.2 AA (4.5:1) on every
   glass weight over the darkest and brightest parts of the scene, in both modes.
4. **Motion explains state.** Springs for what the person moves, nothing loops
   except the water surface, and Reduce motion removes all of it.
5. **Calm.** No guilt, no streak shaming, no volume pressure ("Goal reached ·
   no need for more").

## 2. Glass material

| Weight | Use | Day fill | Night fill | Blur σ |
|---|---|---|---|---|
| thin | chips, steppers, small buttons | white 52% | `#1A283C` 50% | 12 |
| regular | cards | white 60% | `#1A283C` 58% | 20 |
| strong | nav bar, toasts, sheets | white 72% | `#1C2C42` 70% | 28 |
| lens | selection droplet | white 78% | white 14% | 8 |

Each surface = backdrop blur + **175% saturation** (colour glows through instead of
turning grey) + tinted fill with a diagonal specular sheen + rim light (gradient
hairline brightest top-left, lit top lip, faint shaded bottom edge) + soft shadow.

**Reduce transparency** (in-app switch, or OS high contrast) renders the same tokens
as solid surfaces and runs no backdrop filter.

**Performance:** top-level surfaces share one backdrop read through `BackdropGroup` /
`BackdropFilter.grouped` (Flutter 3.29+). Nested surfaces blur their parent.
Keep nesting to two levels.

## 3. Colour tokens

| Token | Day | Night | Use |
|---|---|---|---|
| ink | `#10222B` | `#EEF2F6` | primary text |
| ink2 | `#3B4E57` | `#B3BFCE` | body text |
| ink3 | `#4A5D66` | `#98A6B8` | captions, labels |
| aqua | `#06666D` | `#62D6D9` | hydration, primary actions (text-safe) |
| aqua2 | `#36BFC3` | `#2BA9AF` | fills only |
| leaf | `#2A6445` | `#7FCB9F` | nature, rituals (text-safe) |
| lav | `#5D4F9E` | `#BBADF4` | sleep (text-safe) |
| gold | `#705316` | `#E2C37A` | restrained highlight (text-safe) |
| danger | `#962F28` | `#F2A49B` | destructive actions |
| water top / bottom | `#8FE1E3` / `#1595A0` | `#53CDD3` / `#12597A` | vessel, progress |

Measured worst case (thin glass over the darkest/brightest backdrop point, unblurred):

| | ink | ink2 | ink3 | aqua | leaf | lav | gold | danger |
|---|---|---|---|---|---|---|---|---|
| Day | 12.5 | 6.7 | 5.3 | 5.1 | 5.3 | 5.2 | 5.5 | 5.9 |
| Night | 11.0 | 6.7 | 5.0 | 7.2 | 6.5 | 6.1 | 7.3 | 6.2 |

Status is never shown by colour alone: switches move, checks appear, kept days show a
tick, out-of-band nights are hollow rings.

## 4. Type

| Style | Font | Size / weight |
|---|---|---|
| display | Instrument Serif | 28–56, regular |
| eyebrow | Manrope | 11, 800, +14% tracking, uppercase |
| title | Manrope | 15, 800 |
| body | Manrope | 13.5, 400, 1.5 line height |
| caption | Manrope | 12, 400 |
| label | Manrope | 13, 800 |

Both fonts are OFL. Bundle them under `assets/google_fonts/` for offline first launch.

## 5. Components

- **LiquidGlassNavBar**: floating strong-glass capsule, four tabs, with a lens
  whose two edges are separately sprung (lead stiff 520/30, trail soft 240/24), so it
  stretches and thins slightly in flight and settles. A detached 66 pt quick-log orb sits
  beside it.
- **GlassButton / GlassIconButton**: 44 pt minimum, press scale to 94% on a spring.
- **GlassSwitch**: thumb position is the signal; track colour is secondary.
- **GlassSegmented**: same lens as the nav bar (System / Day / Night).
- **GlassToast**: strong glass, live region, optional Undo.
- **LiquidVessel**: tumbler whose water rises on an overshooting spring after each log,
  with a two-layer surface wave (7 s loop).
- **Sleep dial**: 24-hour ring, bedtime→wake arc (lavender→aqua), moon and sun
  handles, ±15 min steppers (rest kept between 4 h and 12 h).

## 6. Motion

| Moment | Spec |
|---|---|
| Card entrance | rise 14 px + fade, 620 ms, cubic (.2,.9,.25,1.12), 40 ms stagger |
| Water fill | 1050 ms, cubic (.3,1.35,.45,1) |
| Press | 380 ms, cubic (.3,1.6,.5,1), scale .94 |
| Day ↔ Night | 650 ms, every token, the backdrop, sun and moon interpolate |
| Wave | 7 s linear loop; stops under Reduce motion |

## 7. Accessibility checklist

- Text scaling: no fixed-height text containers except the vessel stats column; test at 200%.
- Screen readers: every icon-only control has a label; the vessel, dial and timeline
  expose a sentence summary.
- Touch targets ≥ 44 pt; alarm Stop/Snooze ≥ 64 dp.
- Reduce motion and Reduce transparency both available in-app and honoured from the OS.

## 8. Platform surfaces

Widgets, Control Center, Live Activities and the watch use system materials, not our
Flutter glass. On iOS 26+ the system renders widgets in Liquid Glass (clear and tinted
modes) automatically; mark tintable content with `.widgetAccentable()`. Android widgets
use Glance with `GlanceTheme` so they follow Material You colours.
