# Counter-Blox Extension

A single-file Roblox script for **Counter-Blox** adding a menu, ESP, bunnyhop, and texture-bug slide.

## Load

```lua
loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/scramblepaws/CounterBloxExtension@main/loader.lua"))()
```

## Controls

| Key | Action |
|-----|--------|
| `F4` | Open/close menu |
| `B`  | Toggle bunnyhop |
| `T`  | Toggle texture bug (slide) |
| `E`  | Toggle ESP |

## Features

- **ESP** — box + name + health bar around every player (uses the `Drawing` library, standard across executors).
- **Bunnyhop** — auto-jump on landing with a forward momentum boost.
- **Texture bug** — lowers friction so you slide against surfaces.
- **Menu** — draggable, top-priority overlay with `[ON]/[OFF]` toggle buttons.

## Structure

Single self-contained `loader.lua`. No build step, no module fetches — just `loadstring` the one file.

## Disclaimer

For educational purposes only.
