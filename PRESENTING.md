# Presenting

`./present.sh` rebuilds the slides if needed and starts pdfpc with a 20-minute timer
(red for the last 3). Extra options go straight to pdfpc. Keys below are from
`pdfpc -B` (pdfpc 4.7.0).

## Problems and fixes

| Problem | Fix |
|---|---|
| Slides on my laptop, presenter view on the projector | `./present.sh -s` (swap screens) |
| pdfpc sees only one screen | Turn mirroring off: System Settings → Displays. Then restart. |
| No projector, or must mirror anyway | `./present.sh -S` (single screen) |
| Want to choose screens explicitly | `./present.sh -M` lists them. `-1 <presenter> -2 <projector>` picks by name, but macOS shows `(null)` names: use `-s` instead. |
| pdfpc crashed mid-talk | `./present.sh -P 7` restarts at slide 7 |
| Timer started too early | `Ctrl+t` resets it, `s` starts it, `p` pauses |
| Rehearsing without a projector | `./present.sh -w both` (both views in windows) |
| Need to stop showing the slides for a moment | `b` blank screen, `f` freeze the projector, `h` hide |
| Lost on which slide I am | `Tab` overview, `g` go to slide number |
| Slides changed after starting | `Ctrl+r` reloads the PDF |
| Terminal flooded with GLib/GTK/GStreamer warnings at start | Harmless on this Mac (pdfpc links both GTK 3 and 4); ignore them. |

## Keys during the talk

| Key | Action |
|---|---|
| `→` `Space` `Return` | Next slide |
| `←` `Backspace` | Previous slide |
| `Home` / `End` | First / last slide |
| `g` | Go to slide number |
| `Tab` | Overview |
| `s` / `p` / `Ctrl+t` | Start / pause / reset timer |
| `b` / `f` / `h` | Blank / freeze / hide the projector |
| `z` | Zoom |
| `2` / `5` / `1` | Pointer / spotlight / back to normal |
| `?` | All key bindings |
| `Ctrl+q` | Quit |

## On the day

- Arrive early, plug in, turn mirroring off, run `./present.sh` and check both screens.
- Laptop charger, video adapter, and a USB stick with `build/presentation-16-9.pdf` and
  `.pdfpc` as a fallback (the PDF alone opens on any machine).
- Do Not Disturb on, notifications off.
