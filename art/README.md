# Cartridge artwork

- `abyssal-salvage-sticker.png`: original square label, generated with the built-in imagegen tool.
- `bytorio-cartridge-template.png`: blank shell from the Bytorio website source,
  [`site/assets/brand/cartridge.png`](https://github.com/ctxshift/bytorio/blob/main/site/assets/brand/cartridge.png).
- `abyssal-salvage-cover.png`: blank cartridge composed by `byt cover`, with the
  exact sticker and programmatic platform/language/display footer.
- `../dist/abyssal-salvage.png`: packed cartridge containing the game and the
  same cover bytes. Share this original PNG without image-service re-encoding.

Reproduce from the project root using a CLI build with `cover` support:

```text
byt cover art/abyssal-salvage-sticker.png --output art/abyssal-salvage-cover.png --language luau --display 640x360 --force
byt pack . --cover art/abyssal-salvage-cover.png --output dist/abyssal-salvage.png
```

The project's originally pinned released CLI predates `cover`. The initial cover
was produced with the new local Bytorio development build. No AI generation is
needed to repeat the composition; the sticker is a saved input asset.

## Sticker generation prompt

Use case: illustration-story. Create a polished SQUARE 1:1 game cartridge label sticker for the original indie game ABYSSAL SALVAGE. Flat artwork only, edge-to-edge square, no cartridge shell, no mockup, no perspective. Premium retro 1990s illustrated game label with precise pixel-art inspired chunky shapes and restrained screenprint texture. Deep black navy abyss with luminous mint teal and warm antique brass gold. Hero subject: a heavy brass diving helmet with a thick glass porthole, eerie mint reflection, attached bulky deep sea suit shoulders, centered lower-middle, three-quarter angle. A bright angular helmet flashlight beam cuts through black water toward delicate glowing jellyfish; silhouettes of a sunken pirate ship and tiny submarine in the background. Claustrophobic underwater horror, adventurous rather than gruesome. Strong iconic silhouette, restrained detail, legible at 256px. Upper third: very large beautifully designed two-line title, exact text "ABYSSAL" above "SALVAGE", mint upper line and warm brass lower line, squared industrial lettering. Small lower margin text exactly "DEEP SEA SURVIVAL". Thin double-line brass border inset 3% from the edge, square corners. All title text comfortably within 7% safe margins. No other text, no logos, no watermark. Output 1024x1024.
