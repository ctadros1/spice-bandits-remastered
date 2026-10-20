# README image sources

[Project README](../../README.md) · [R200 packaged review](../../docs/validation/2026-10-19-r200-packaged-native-review.json)

The four screenshots are unmodified 1280 × 960 PNG captures from the **R200 macOS application**, recorded during the October 19, 2026 packaged verification sessions. They are copied byte for byte from the retained candidate galleries. The scenes use isolated test profiles; combat and shop captures include staged state.

| Published image | Retained source under `builds/bubble-runtime-r200-candidate/` |
| --- | --- |
| [Main menu](screenshots/main-menu.png) | `menu-gallery/main-menu-1200.png` |
| [Campaign map](screenshots/campaign-map.png) | `menu-gallery/world-observed-level2.png` |
| [Combat and effects](screenshots/combat.png) | `projectile-gallery/projectiles-3000.png` |
| [Tech shop](screenshots/tech-shop.png) | `menu-gallery/shop-support-branches.png` |

The menu and projectile package audits bind these sessions to PCK SHA-256 `3424f7f38bf0ae6e07426e3e0fa78cf0b926ccb2d608e6f11294eaa9c8158009`. The original full-resolution captures remain in the ignored local evidence directories and archived checkpoint evidence.

The [game icon](game-icon.png) is the 144 × 144 runtime-compatible copy of the original `Icon-72@2x.png`, taken from `game/assets/`. The content importer converts the preserved iOS image; this publication copies the converted file without further changes.

The original game's icon and artwork belong to their respective rights holders. These captures show the reconstruction's development state; the [status report](../status.md) retains its known fidelity, visual, and performance limits.
