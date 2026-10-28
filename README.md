# Abyssal Salvage

A 640x360 isometric survival game written in Luau for Bytorio. A brass diving
suit, a failing pool of light, and things moving between the ribs of sunken ships.

Survive five minutes, kill the leviathan that arrives at 04:00, then return to
the submarine in the central chamber. Harpoons automatically target the nearest
visible enemy. Collect green salvage to choose upgrades; gold wreck caches give
salvage and repair your suit. Each new dive varies the connected trench chambers.

## Play

Install [mise](https://mise.jdx.dev/), then run from this folder:

```sh
mise trust
mise install
mise run play
```

Click **Play** in the browser player, then press **Space** to descend. The first
build downloads the exact SDK components recorded in `bytorio.lock.toml`.

| Control | Action |
| --- | --- |
| WASD or arrow keys | Walk in screen directions |
| Mouse movement | Aim the helmet light |
| Space | Sonar burst; start, confirm upgrade, or retry |
| I | Toggle sonar chart (Tab also works in the native player) |
| 1 / 2 / 3 | Choose an upgrade |
| Left / Right, then Space | Choose an upgrade without number keys |
| Escape | Pause or resume the dive |

The light follows movement when the pointer is outside the game. Sonar damages
and pushes back nearby enemies while briefly revealing the trench. Its cooldown
appears in the bottom bar. The chart marks caches in gold and the submarine in mint.

## Build and develop

```sh
mise run dev       # Rebuild and reload after edits
mise run check     # Luau types, cartridge contracts, startup frames
mise run build     # Browser and native exports
mise run validate  # Full project validation with retained logs
mise run assets    # Regenerate original sprites and bitmap font
```

`build/web/player.html` is a static browser export; serve the directory over HTTP.
`build/native/player.exe` launches the Windows export directly. Distribute the
entire native directory, including runtime files and license notices.
`build/game.png` is the portable Bytorio cartridge.

The project pins CLI **0.2.0-preview.2** and SDK **0.2.0-preview.4**, the newest
compatible releases available when created. Release provenance:
[CLI](https://github.com/ctxshift/bytorio/releases/tag/byt-v0.2.0-preview.2),
[SDK](https://github.com/ctxshift/bytorio/releases/tag/sdk-v0.2.0-preview.4).
Node is used only for asset generation and validation, not for native playback.

## Implementation

- `src/main.luau`: game lifecycle, combat, progression, interface and scene rendering.
- `src/world.luau`: seeded rooms, connected corridors, collision, visibility rays,
  and a breadth-first navigation field shared by enemies.
- `src/art.luau`: small UI drawing helpers and large pixel lettering.
- `tools/assets.mjs`: original 16-pixel art, palette and readable bitmap font.
- `tests/scenarios.luau.inc`: controlled gameplay scenarios appended to an ignored
  test cartridge; no test hooks or cheats are shipped in the game.

Lighting uses three discrete tile palettes with an occlusion-tested cone, a close
ambient pool, and an expanding sonar reveal. It is software tile lighting, not a
custom GPU shader. Terrain and actors use isometric projection and depth sorting.
The six upgrade families improve harpoons, fire rate, a proximity halo, collection
and speed, hull capacity, or sonar. Enemies include drifting jellies, fast eels,
armored crabs and the leviathan. Five original synthesized PCM cues use reusable
SDK audio resources.

## Validation and limits

`mise run validate` retains `.validation/report.json`, per-check logs, native
input replays and PNG captures. It checks connectivity across 24 generated maps,
collision boundaries, screen-direction movement, pause/resume, automatic fire,
salvage, sonar, cache healing, unique upgrades, hull upgrades, death/restart,
leviathan arrival/death, early-extraction rejection and successful extraction.
It also renders a 90-enemy scene and captures title, combat and pause frames from
the real native player. Native replay frame counts must match their inputs.

Browser startup and keyboard movement were also checked interactively. Full-run
difficulty balance, gamepad/touch controls and physical mobile devices are not
qualified. This is a complete small playable prototype: there is one biome,
no persistent progression, and no save or online service.
