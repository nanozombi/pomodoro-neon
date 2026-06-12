#Requires -Version 5.1
<#
.SYNOPSIS
    Pomodoro Neon — terminal timer with animated progress bar and session log.
.DESCRIPTION
    25-min focus / 5-min break cycles with ANSI color, sound alerts, and a
    daily log saved to sessions.json in the same folder.
.EXAMPLE
    pwsh -File pomodoro.ps1
    pwsh -File pomodoro.ps1 -Work 50 -ShortBreak 10 -LongBreak 20
#>
param(
    [int]$Work        = 25,
    [int]$ShortBreak  = 5,
    [int]$LongBreak   = 15,
    [int]$Rounds      = 4,   # long break after this many work rounds
    [switch]$NoSound
)

$LOG_FILE = Join-Path $PSScriptRoot "sessions.json"

# ── ANSI helpers ─────────────────────────────────────────────────────────────
$ESC = [char]27
function Ansi($code) { "${ESC}[${code}m" }
function Reset  { Ansi "0" }
function Bold   { Ansi "1" }
function Dim    { Ansi "2" }

# Neon palette
$CYAN    = Ansi "96"
$MAGENTA = Ansi "95"
$YELLOW  = Ansi "93"
$GREEN   = Ansi "92"
$RED     = Ansi "91"
$WHITE   = Ansi "97"
$GRAY    = Ansi "90"

# ── Cursor control ────────────────────────────────────────────────────────────
function Hide-Cursor { Write-Host "${ESC}[?25l" -NoNewline }
function Show-Cursor { Write-Host "${ESC}[?25h" -NoNewline }
function Clear-Line  { Write-Host "${ESC}[2K${ESC}[G" -NoNewline }
function Move-Up($n) { Write-Host "${ESC}[${n}A" -NoNewline }

# ── Sound (optional, Windows only) ───────────────────────────────────────────
function Beep($freq = 880, $dur = 200) {
    if (-not $NoSound) {
        try { [Console]::Beep($freq, $dur) } catch {}
    }
}
function StartSound  { Beep 660 150; Beep 880 150 }
function FinishSound { Beep 880 200; Beep 1100 200; Beep 1320 300 }

# ── Progress bar ─────────────────────────────────────────────────────────────
function Draw-Bar($elapsed, $total, $color) {
    $width   = 40
    $pct     = [math]::Min($elapsed / $total, 1.0)
    $filled  = [math]::Round($pct * $width)
    $empty   = $width - $filled
    $bar     = ("█" * $filled) + ("░" * $empty)
    $pctStr  = "{0,3:0}%" -f [math]::Round($pct * 100)
    "${color}${bar}$(Reset) ${WHITE}${pctStr}$(Reset)"
}

# ── Time formatter ────────────────────────────────────────────────────────────
function Fmt-Time($seconds) {
    $m = [math]::Floor($seconds / 60)
    $s = $seconds % 60
    "{0:D2}:{1:D2}" -f $m, $s
}

# ── Session log ───────────────────────────────────────────────────────────────
function Load-Log {
    if (Test-Path $LOG_FILE) {
        try { Get-Content $LOG_FILE | ConvertFrom-Json } catch { @() }
    } else { @() }
}

function Save-Session($type, $durationMin, $completed) {
    $sessions = @(Load-Log)
    $entry = [PSCustomObject]@{
        date      = (Get-Date -Format "yyyy-MM-dd")
        time      = (Get-Date -Format "HH:mm")
        type      = $type
        minutes   = $durationMin
        completed = $completed
    }
    $sessions += $entry
    $sessions | ConvertTo-Json -Depth 3 | Set-Content $LOG_FILE
}

function Show-Stats {
    $sessions = @(Load-Log)
    if ($sessions.Count -eq 0) {
        Write-Host "${GRAY}  No sessions logged yet.$(Reset)"
        return
    }
    $today     = Get-Date -Format "yyyy-MM-dd"
    $todayWork = $sessions | Where-Object { $_.date -eq $today -and $_.type -eq "work" -and $_.completed }
    $totalWork = $sessions | Where-Object { $_.type -eq "work" -and $_.completed }
    $focusMins = ($todayWork | Measure-Object minutes -Sum).Sum

    Write-Host ""
    Write-Host "  ${CYAN}$(Bold)Today$(Reset)   ${WHITE}$($todayWork.Count) pomodoros · ${focusMins} min focus$(Reset)"
    Write-Host "  ${GRAY}All time  $($totalWork.Count) completed pomodoros$(Reset)"
    Write-Host ""
}

# ── Timer loop ────────────────────────────────────────────────────────────────
function Run-Timer($label, $totalMin, $color) {
    $totalSec = $totalMin * 60
    $start    = Get-Date
    $done     = $false

    Hide-Cursor
    StartSound

    Write-Host ""
    Write-Host "  ${color}$(Bold)$label$(Reset)"
    Write-Host "  $(Draw-Bar 0 $totalSec $color)"
    Write-Host "  ${WHITE}$(Fmt-Time $totalSec) remaining$(Reset)"

    try {
        while ($true) {
            Start-Sleep -Milliseconds 500

            $elapsed = [int]((Get-Date) - $start).TotalSeconds
            if ($elapsed -ge $totalSec) { $done = $true; break }

            $remaining = $totalSec - $elapsed
            Move-Up 2
            Clear-Line
            Write-Host "  $(Draw-Bar $elapsed $totalSec $color)"
            Clear-Line
            Write-Host "  ${WHITE}$(Fmt-Time $remaining) remaining$(Reset)" -NoNewline

            # check for keypress to skip/quit
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.Key -eq "Q" -or $key.Key -eq "Escape") { break }
                if ($key.Key -eq "S") { $done = $true; break }  # skip
            }
        }
    } finally {
        Show-Cursor
    }

    Write-Host ""
    if ($done) {
        FinishSound
        Write-Host "  ${GREEN}$(Bold)Done!$(Reset)"
    } else {
        Write-Host "  ${YELLOW}Interrupted$(Reset)"
    }

    Save-Session ($label.ToLower().Split()[0]) $totalMin $done
    $done
}

# ── Header ────────────────────────────────────────────────────────────────────
function Show-Header($round, $totalRounds) {
    Clear-Host
    Write-Host ""
    Write-Host "  ${MAGENTA}$(Bold)◉ POMODORO NEON$(Reset)  ${GRAY}Round $round / $totalRounds  ·  Q quit  ·  S skip$(Reset)"
    Write-Host "  ${GRAY}$("─" * 52)$(Reset)"
}

# ── Main ──────────────────────────────────────────────────────────────────────
$Host.UI.RawUI.WindowTitle = "Pomodoro Neon"

Show-Header 1 $Rounds
Show-Stats

Write-Host "  ${WHITE}Work: ${CYAN}${Work}m$(Reset)  ${WHITE}Break: ${GREEN}${ShortBreak}m$(Reset)  ${WHITE}Long break: ${YELLOW}${LongBreak}m$(Reset)  (after $Rounds rounds)"
Write-Host ""
Write-Host "  ${GRAY}Press any key to start...$(Reset)"
$null = [Console]::ReadKey($true)

$round = 1
while ($true) {
    Show-Header $round $Rounds

    # ── Work block ──────────────────────────────────────────────────────────
    $completed = Run-Timer "Work  — focus" $Work $CYAN
    if (-not $completed -and $?) {
        # user quit (Q/Esc)
        break
    }

    # ── Break ───────────────────────────────────────────────────────────────
    if ($round -ge $Rounds) {
        Write-Host ""
        Write-Host "  ${YELLOW}$(Bold)Long break — you earned it!$(Reset)"
        $null = Run-Timer "Break — long rest" $LongBreak $YELLOW
        $round = 1
    } else {
        Write-Host ""
        Write-Host "  ${GREEN}Short break!$(Reset)"
        $null = Run-Timer "Break — short rest" $ShortBreak $GREEN
        $round++
    }

    # ── Continue? ────────────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "  ${WHITE}Continue next round? ${GRAY}[Enter] yes  [Q] quit$(Reset)  " -NoNewline
    $key = [Console]::ReadKey($true)
    Write-Host ""
    if ($key.Key -eq "Q" -or $key.Key -eq "Escape") { break }
}

Show-Header $round $Rounds
Write-Host "  ${MAGENTA}$(Bold)Session complete!$(Reset)"
Show-Stats
Write-Host "  ${GRAY}Log saved to: sessions.json$(Reset)"
Write-Host ""
