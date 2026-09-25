# Local Transparency Adjuster

A Roblox Luau utility for changing your character's transparency locally. It is designed to work with reanimation setups, including Mic Up-style workflows, where seeing through your own character can make tracking and positioning easier.

## Usage

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/zvzt/localtransparency.lua/refs/heads/main/transparent.lua"))()
```

## Features

- Local-only body transparency using `LocalTransparencyModifier`
- Adjustable 0–100% transparency slider
- Active/Disabled switch in the header
- Reanimation-aware character and camera-subject detection
- Event-driven transparency enforcement instead of a permanent render-step loop
- Automatic restoration when disabled or closed
- Rerun-safe cleanup
- clean, draggable, minimizable interface
- Header-only minimize/restore behavior
- Screen-edge drag clamping with `-57 / 57` vertical offsets

## Notes

The visual effect is local to your client rather than a server-side character change. The HumanoidRootPart remains locally hidden while the feature is active.

A synchronized deployment copy is maintained in `zxt.lol/public/reanimtrasparent.lua`.

## Files

- `transparent.lua` — main script
- `README.md` — documentation

## License

MIT — see [LICENSE](LICENSE).
