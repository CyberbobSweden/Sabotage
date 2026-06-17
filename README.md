# 🕵️ Sabotage!

A retro 2D spy-duel game inspired by the classic **Spy vs Spy** (C64 / NES). Two rival
spies — **WHITE** and **BLACK** — race through a procedurally generated mansion,
hunt for four mission items hidden in the furniture, booby-trap each other, and
try to be first to grab everything and reach the exit.

Built with **Godot 4** + **GDScript**. Split-screen, Commodore-64-inspired
pixel art, 320×180 internal resolution, cartoon deaths.

> 🇸🇪 **Snabbstart:** öppna mappen i **Godot 4.3+** (Project → Import → välj
> `project.godot`) och tryck på ▶️ Play. Tryck **1** för två spelare på samma
> tangentbord, eller **2** för att spela mot datorn. Se kontroller nedan.

---

## ▶️ How to run

1. Install **Godot 4.3 or newer** — https://godotengine.org/download
2. Open Godot → **Import** → select this folder's `project.godot`.
3. Press **F5** (or the ▶️ Play button).

> ⚠️ This project was generated and reviewed but **not run** by the author in
> the build environment. Open it in Godot once to confirm it compiles on your
> version; Godot will tell you immediately if anything needs a tweak.

---

## 🎮 Controls

**Player 1 — WHITE** (top screen)

| Action | Key |
|---|---|
| Move left / right | `A` / `D` |
| Interact (search furniture / use door / exit) | `W` |
| Plant trap | `S` |
| Scan / disarm trap | `Q` |

**Player 2 — BLACK** (bottom screen, 2-player mode)

| Action | Key |
|---|---|
| Move left / right | `←` / `→` |
| Interact | `↑` |
| Plant trap | `↓` |
| Scan / disarm trap | `/` |

**Menu:** `1` = 2 players · `2` = vs A.I. (or **tap** the screen on a phone) ·
`R` = restart · `Esc` = quit.

**Touch:** in vs-A.I. mode, on-screen buttons appear for Player 1 (phone-friendly).

---

## 🧩 How to play

- **Find** the four mission items hidden in furniture: 🧳 Briefcase, 🛂 Passport,
  🔑 Key, 📄 Documents. Walk to a cabinet/drawer/safe and press **Interact** to search.
- **Travel** between rooms through doors (brown). Walk to a door, press **Interact**.
- **Trap** your rival: press **Plant trap** next to furniture or a door. Trap type
  cycles Bomb → Spring → Drawer.
- **Scan** suspicious spots with the scan button. First press reveals a trap;
  a second press on a revealed trap disarms it (and gives you a trap back).
- Trigger an unseen trap → 💥 cartoon death, respawn at start, and you **drop all
  your loot** (it gets re-hidden somewhere).
- **Win** by collecting all four items and reaching the yellow **EXIT** door in the
  far room, then pressing Interact. If the clock runs out, most-loot wins.

---

## 🏗️ Architecture

Game **logic** is fully separated from **rendering** — the renderer only ever
*reads* state, so the same code can later drive networked clients.

```
project.godot              Engine config (320×180, pixel-perfect, mobile-ready)
scenes/Main.tscn           Tiny scene → attaches Main.gd
scripts/
  Main.gd                  Orchestrator: phases, input, touch UI, draws panels
  core/
    Palette.gd             C64 colour palette
    Mansion.gd             STEP 1+2  procedural 20-room generator + hidden items
    Room.gd                Room data: doors, furniture, door-traps
    Furniture.gd           Searchable container (may hide an item or a trap)
    TrapData.gd            STEP 3    trap data (Bomb / Spring / Drawer)
    GameState.gd           ALL rules: move, search, traps, deaths, win, BFS
  entities/
    Spy.gd                 Spy data + tiny state (ALIVE/DYING/READY)
    AIController.gd         STEP 4    AI state machine (explore→search→escape)
  render/
    Renderer.gd            STEP 5    all drawing (split-screen rooms + HUD)
  net/
    NetworkManager.gd      Optional LAN scaffolding (see Multiplayer)
```

The five build steps you asked for map directly onto the files above:
**1** Mansion → `Mansion.gd`, **2** Loot → `Mansion._hide_items` + `Furniture`,
**3** Traps → `TrapData` + `GameState.place_trap/detect`, **4** AI → `AIController`,
**5** Retro look → `Renderer` + `Palette` + `project.godot` (320×180, nearest filter).

---

## 📡 Multiplayer

- ✅ **Local 2-player (same device):** done — hotseat on one keyboard, split-screen.
- ✅ **vs A.I.:** done — phone-friendly with touch controls.
- 🧪 **Phone-to-phone over Wi-Fi:** scaffolding is in `scripts/net/NetworkManager.gd`
  (Godot ENet, host-authoritative). It is **not yet wired into the main loop** so the
  single-device game always runs. The file documents the integration sketch
  (clients send input → host runs `GameState` → host broadcasts snapshots →
  clients render). This part is untested — treat it as a solid starting point.
- 🌍 **Over the internet:** LAN needs no extra setup; internet additionally needs
  port-forwarding or a relay (e.g. WebRTC + signalling). Notes are in that file.

---

## 🚀 Put it on GitHub

The repo is **already initialised and committed** in the download, so you only
need to point it at GitHub and push.

First create a **new, empty** repository on github.com named `sabotage`.
Do **not** tick "Add a README", ".gitignore" or "license" — leaving it empty
avoids a conflict with the commit that already exists here.

Then, from inside this folder:

```bash
git branch -M main
git remote add origin https://github.com/<your-username>/sabotage.git
git push -u origin main
```

---

## 🔧 Ideas to extend

- Free 2D movement inside rooms (currently a horizontal lane per room).
- Sprite/animation assets instead of code-drawn primitives.
- More trap types and gadget inventory like the original.
- Finish and wire up LAN/online play via `NetworkManager.gd`.

## 📝 License

MIT — see [LICENSE](LICENSE).
