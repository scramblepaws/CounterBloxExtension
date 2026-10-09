# Counter-Blox Extension

A Roblox script extension for **Counter-Blox** that adds a custom menu system, key/mouse binding, movement features (Bunnyhop, TextureBug), and Box ESP visuals.

## Installation

Load the script using a loadstring function:

```lua
loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/scramblepaws/CounterBloxExtension@main/loader.lua"))()
```

## Features

### Menu System
- Open/close with `F4`
- Custom draggable menu
- Bind functions to keys (1-5) and mouse buttons (Mouse1-5)

### Movement
- **Bunnyhop** - Double-jump physics with adjustable force
- **TextureBug** - Slide against pixels for a "glitch" movement effect

### Visual
- **Box ESP** - See-through boxes showing player positions and health
- Custom cursor during menu interaction

## Controls

| Key | Action |
|-----|--------|
| `F4` | Open/close menu |
| `B` | Toggle Bunnyhop |
| `T` | Toggle TextureBug |
| `E` | Toggle ESP |
| `Shift` | Slide (when TextureBug enabled) |

## File Structure

```
counter-blox-extension/
├── loader.lua              # Entry point (loadstring)
├── main.client.lua         # LocalScript entry
├── modules/
│   ├── MenuManager.lua     # Menu UI + toggle
│   ├── InputHandler.lua    # Key/mouse binding
│   ├── MovementEngine.lua  # Bunnyhop + TextureBug
│   ├── VisualRenderer.lua  # Box ESP + visuals
│   ├── CameraControl.lua   # Camera lock + cursor
│   └── Utils/
│       ├── Signal.lua      # Event system
│       └── Tween.lua       # Animation helpers
├── config/
│   └── settings.json       # User settings
└── scripts/
    └── loader.server.lua   # Server-side loader
```

## Disclaimer

This script is for educational purposes only. Use responsibly and respect the game's terms of service.
