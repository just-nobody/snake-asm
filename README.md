# Snake – x86 Assembly (FASM) for Windows

The classic **Snake** game written in pure **x86 assembly** and built with the
**Flat Assembler (FASM)**.

---
# Snake

On launch a 10 × 10 field (200 × 200 px) opens and the difficulty selection is drawn inside it.
  Once a level is picked the labels disappear and the game starts immediately in that same,
  already visible field.

## Difficulty Levels

Every level starts with just the head, no tail. The only difference is how many tail
segments an apple adds – and the score follows the same number, 10 points per new segment:

| Level | Tail per apple | Score per apple |
| :--- | :--- | :--- |
| `EASY` | +1 | +10 |
| `NORMAL` *(default)* | +2 | +20 |
| `HARD` | +3 | +30 |
| `ULTRA` | +4 | +40 |

The current score is drawn in a large font in the playfield background.

## Growing Field

The growth rule is the same for every level: **on an N × N field you must eat N apples**, then
the field grows **by one cell on all four sides** and becomes (N+2) × (N+2). So 10 × 10 → 10
apples, 12 × 12 → 12 apples, 14 × 14 → 14 and so on, up to 50 × 50 (or as far as the screen
allows), after which you simply play on.

Every snake segment and the apple shift by one cell while the window expands by 20 px on each
side and its corner moves by −20, −20. Nothing on screen moves – a new ring of cells simply
appears around the field.

## Controls

| Action | Keys |
| :--- | :--- |
| Select level | arrows / `WASD`, or `1` `2` `3` `4` |
| Start | `Enter` or `Space` |
| Movement | `W A S D` or arrows |
| Pause | `P` or `Space` |
| Back to menu | `R` |
| Sound | `M` |
| Quit | `Esc` |

Build:
```cmd
set "INCLUDE=%CD%\fasm\INCLUDE" && fasm\FASM.EXE snake.asm snake.exe
```
or just doubleclick:
```cmd
build.bat
```