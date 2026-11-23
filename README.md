# 孔明の罠 // KAIZO TRAP (Godot 4 Fan Recreation)

> A 16-bit pixel-art playable fan recreation of Guy Collins' iconic 2015 animated short **Kaizo Trap (孔明の罠)** — combining **Celeste-grade precision platforming feel**, **Celeste-style Assist Mode**, and a reborn **in-game Instruction Manual + ZhugeDOS 14 + Multi-Ending ARG** experience.

## ✨ Highlights

* **High-FPS Smoothness (`120Hz` Physics + Physics Interpolation + 8-Frame Run Cycle + Full-Refresh-Rate Spring Hair)**:
  * Crisp 16-bit pixel art rendered cleanly in `canvas_items` stretch mode with `TEXTURE_FILTER_NEAREST` and static terrain caching for locked 120–240+ FPS.
  * Dynamic 6-node *Celeste*-style ponytail hair physics that communicates Dash charge color in real time (`Orange-Red` = Ready, `Cyan` = Spent, `White Flash` = Refilled).
* **1:1 Celeste-Aligned Feel & Flow-Driven Level Design**:
  * 8-Way Air Dash (45ms freeze-frame, 4px corner correction, Wave/Hyper/Super Dash, Wall Bounce), Wall Grab & Climb with 110 Stamina, Jump Apex anti-gravity hang, Coyote Time & Jump Buffering.
  * Sight-readable *Celeste*-style rooms featuring **Green Dash Refill Crystals**, **Traffic Zip-Mover Blocks**, **Starry Glitch Dream Blocks** (dash straight through corrupted code!), **Omni-Springs**, and **Celeste Strawberry-style Following Bagua Trigrams**.
* **Full Celeste Assist Mode (`F2`)**:
  * Stepped **Game Speed (`100%` down to `50%`)**, **Invincibility Shield** (hazard & bottomless pit bounce), **Air Dashes (`1 / 2 / Infinite`)**, **Infinite Stamina**, Hidden Block Outlines, Save States (`F5`/`F7`), and toggleable CRT Scanlines.
* **Full 5-Biome Campaign + Arrange Mode (2nd Loop) + Multi-Ending ARG**:
  * Stage 0 Living Room CRT Intro → Stage 1 Overworld (Falling Coconut, Golden Bagua Kaizo Blocks, Misleading Arrow) → Stage 2 Ice Zone (Icicles + Arrange Mode Blizzards) → Stage 3 Volcano Cavern (Rising Lava) → Stage 4 Factory Lab (Sawblades, `液体痛み/敗者の涙/濃厚苦しみ` tanks, buried `1983` NES) → `CONTINUE? (Y/N)` Void Chamber → Stage 5 Corrupted Zo Core Boss (Heart Cable Pull + Glitch Silhouette Escape + Return Coconut Callback!).
  * Interactive Retro Manual (`Tab` / `M`) + External Companion Booklet (`manual/KAIZO_TRAP_MANUAL.md`).
  * Built-in **`ZhugeDOS 14` (`F1` / `` ` ``)** terminal & Right-Click **CRT Inspect Cursor** (rebirth of the lost `7M01S` YouTube annotation!).

## 🎮 Quick Start

1. Download **Godot 4.7+ (Linux x86_64)** (or run `./play.sh` if installed at `tools/godot/godot4`).
2. Launch the game:
   ```bash
   ./play.sh
   ```
3. Run the automated headless TAS & ARG verification suite:
   ```bash
   ./tools/godot/godot4 --headless --path game res://tests/TestRunner.tscn
   ```

## 🛠️ Developer Pipelines

* `tools/gen_assets.py` + `tools/pixel_pipeline.py`: GPT Image API batch asset generator with OpenCV blob auto-slicing & locked 16-bit palette quantization.
* `tools/gen_sfx.py` & `tools/gen_bgm.py`: Procedural 8/16-bit retro SFX & looping chiptune BGM synthesizers.
* `manual/KAIZO_TRAP_MANUAL.md`: Companion vintage instruction booklet containing subtle ARG hints.

## 📜 Disclaimer
This is a non-commercial fan homage inspired by *Kaizo Trap* (Guy Collins Animation). All in-game pixel art, shaders, GDScript code, and synthesized audio in this repository are freshly generated/original works.
