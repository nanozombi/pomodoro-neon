# Pomodoro Neon

Terminal Pomodoro timer with animated neon progress bar, sound alerts, and a daily session log.

![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-blue)

## Features

- Animated progress bar with ANSI neon colors
- Configurable work / short break / long break durations
- Optional sound alerts (Windows)
- Session log saved to `sessions.json`
- Daily and all-time stats on start and finish

## Usage

```powershell
# Default: 25 min work / 5 min break / 15 min long break
pwsh -File pomodoro.ps1

# Custom durations
pwsh -File pomodoro.ps1 -Work 50 -ShortBreak 10 -LongBreak 20

# Disable sound
pwsh -File pomodoro.ps1 -NoSound
```

### Keyboard shortcuts

| Key | Action |
|-----|--------|
| `S` | Skip current block |
| `Q` / `Esc` | Quit session |
| `Enter` | Continue to next round |

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-Work` | `25` | Work block duration in minutes |
| `-ShortBreak` | `5` | Short break duration in minutes |
| `-LongBreak` | `15` | Long break duration in minutes |
| `-Rounds` | `4` | Work rounds before a long break |
| `-NoSound` | — | Disable beep alerts |

## Requirements

- PowerShell 5.1 or later (`pwsh` recommended)
- A terminal that supports ANSI escape codes (Windows Terminal, VS Code terminal, etc.)
