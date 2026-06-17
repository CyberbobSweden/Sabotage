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
`3` = host LAN game · `4` = join LAN game · `R` = restart ·
`Esc` = back to menu (quit from the menu).

**Touch:** in vs-A.I. and LAN modes, on-screen buttons appear for the local
player (phone-friendly): `<` `>` move, `ACT`, `TRAP`, `SCAN`.

**LAN (two devices on the same Wi-Fi):** one device picks **`3` Host** and shows
its IP address; the other picks **`4` Join**, types that IP, and presses
**Connect**. The host plays WHITE, the joiner plays BLACK, each on their own
device with the same controls as Player 1.

---

## 🧩 How to play

- **Find** the four mission items hidden in furniture: 🧳 Briefcase, 🛂 Passport,
  🔑 Key, 📄 Documents. Walk to a cabinet/drawer/safe and press **Interact** to search.
- **Travel** between rooms through doors (brown). Walk to a door, press **Interact**.
- **Trap** your rival: press **Plant trap** next to furniture or a door. There
  are six trap flavours — Bomb, Spring, Drawer, Gun, Bucket and Anvil — each with
  its own cartoon death, warning-marker colour and one-letter tag. The selected
  type cycles automatically as you plant; the sneakier ones (Anvil, Gun) are
  harder for the A.I. to spot.
- **Scan** suspicious spots with the scan button. First press reveals a trap;
  a second press on a revealed trap disarms it (and gives you a trap back).
- Trigger an unseen trap → 💥 cartoon death, respawn at start, and you **drop all
  your loot** (it gets re-hidden somewhere).
- **Win** by collecting all four items and reaching the yellow **EXIT** door in the
  far room, then pressing Interact. If the clock runs out, most-loot wins.
- 🔊 **Sound:** all effects are synthesised in code (no audio files) for searching,
  finding loot, planting/disarming traps, doors, explosions and winning.

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
    TrapData.gd            STEP 3    trap data (6 types + marker colour/tag)
    GameState.gd           ALL rules: move, search, traps, deaths, win, BFS
                                     + snapshot serialize/deserialize for LAN
  entities/
    Spy.gd                 Spy data + tiny state (ALIVE/DYING/READY)
    AIController.gd         STEP 4    AI state machine (explore→search→escape)
  render/
    Renderer.gd            STEP 5    all drawing (split-screen rooms + HUD)
  audio/
    SoundBank.gd           Procedural retro SFX (synthesised, no audio files)
  net/
    NetworkManager.gd      LAN multiplayer (ENet, host-authoritative)
```

The five build steps you asked for map directly onto the files above:
**1** Mansion → `Mansion.gd`, **2** Loot → `Mansion._hide_items` + `Furniture`,
**3** Traps → `TrapData` + `GameState.place_trap/detect`, **4** AI → `AIController`,
**5** Retro look → `Renderer` + `Palette` + `project.godot` (320×180, nearest filter).

---

## 📡 Multiplayer

- ✅ **Local 2-player (same device):** done — hotseat on one keyboard, split-screen.
- ✅ **vs A.I.:** done — phone-friendly with touch controls.
- 🧪 **Phone-to-phone over Wi-Fi:** now **wired into the game** (menu `3` Host /
  `4` Join). It uses Godot ENet, host-authoritative: the client sends input
  intents → the host runs all of `GameState` → the host broadcasts a full world
  snapshot ~20×/sec → the client mirrors and renders it. This fits the
  logic/render split, so the client needs no game rules of its own.
  **Honest status:** it is written carefully but **not yet tested on real
  devices** — first contact between two phones is where LAN netcode usually
  needs a small tweak, so `NetworkManager.gd` is the place to look if something
  misbehaves. The single-device modes are unaffected.
- 🌍 **Over the internet:** LAN needs no extra setup; internet additionally needs
  port-forwarding of port `9559` on the host's router, or a relay (e.g. WebRTC +
  signalling). Notes are in `NetworkManager.gd`.

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

## 🌐 Play in the browser (automatic, no Godot needed)

This repo ships with a GitHub Actions workflow (`.github/workflows/deploy.yml`)
that builds the **web version on GitHub's servers** and publishes it to GitHub
Pages every time you push to `main`. You never have to open Godot yourself.

**One-time setup:** on GitHub go to **Settings → Pages → Build and deployment →
Source** and choose **GitHub Actions**. After your next push, watch the
**Actions** tab; when the run is green your game is live at
`https://<your-username>.github.io/<repo>/`.

How it works: the workflow runs headless Godot 4.3, exports the `Web` preset
(see `export_presets.cfg`), and deploys the result. The web build is configured
**single-threaded** so it runs on GitHub Pages without special COOP/COEP headers.

**Web caveat:** local 2-player and vs-A.I. work in the browser, but **LAN
phone-to-phone play does not** — browsers don't allow the raw ENet sockets it
uses. For networked play across devices, use a desktop or Android export
instead, or swap the transport to WebSocket/WebRTC.

---

## 🔧 Ideas to extend

- Free 2D movement inside rooms (currently a horizontal lane per room).
- Sprite/animation assets instead of code-drawn primitives.
- A trap-select button so you can choose the type instead of auto-cycling.
- Test and harden LAN play on real devices; add client-side prediction to hide
  latency, and an in-game host/IP browser so you don't have to type the IP.
- Online play (port-forwarding or a WebRTC relay) building on `NetworkManager.gd`.

## 📝 License

MIT — see [LICENSE](LICENSE).
