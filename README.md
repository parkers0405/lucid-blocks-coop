# Lucid Blocks Co-op Updated

Compatibility update and completion of [parkers0405/lucid-blocks-coop](https://github.com/parkers0405/lucid-blocks-coop). Original co-op implementation by parkers0405 and upstream contributors; this fork preserves their history and attribution.

**Status: NOT READY; handoff freeze gates G4 and G6 failing (see playtest.md).** Target: Steam build **26206996**, game **5.2.0.0**, Godot **4.6 double** with GodotSteam **4.17.1**. See [playtest.md](playtest.md) for dated verification and limits. The inherited `dist` artifacts are stale; build from source rather than installing them. No new build has been installed or released.

Scope: two-player Steam/LAN co-op, independent exploration and dimensions, persistent personal Apotheosis with visits, the known-issue fixes below, and personal ender-chest storage. New player models, skins, dedicated servers, and larger player counts are excluded. See [tasks.md](tasks.md) and [playtest.md](playtest.md) for actual progress and evidence.

No new license is assigned to inherited code or assets. Existing attribution and notices remain applicable. Recovered commercial game files are not part of this repository.

## Current mod behavior and remaining work

Identity is bound to an authenticated Steam transport ID or a host-issued LAN reconnect credential. Names and peer numbers do not identify a saved character. Profiles, chest contents and preserved world objects share an atomic host ledger; region terrain uses separate verified checkpoints. Preserve the complete save folder, including its co-op sidecars, when backing it up.

Routine terrain saves and built-in background file transactions preserve movement/camera. Pickups retain mining, melee attacks and hotbar selection; conflicting drop/item-use inputs wait for acknowledgement. Sparse pickup updates preserve ongoing tool wear, conserve partial stacks and wait until an active glide or item interaction ends. Routine personal checkpoints run every5seconds; durable inventory transactions take priority over queued routine work. No external worker, hosting service or extra player configuration is required. Both peers must use this protocol6 update.

The host can designate an empty ordinary cache cube with `/enderchest`. It opens a personal21-slot chest with explicit quantity-based Store/Take actions. Contents belong to the authenticated character and survive destruction of the access block. Ordinary cubes and hoppers retain their normal behavior.

Individual dimension travel, private owner namespaces, terrain residency, acknowledged ownership handoffs and chest lifecycle recovery are implemented. Local contracts cover persistence and transaction failures; an automated real LAN scenario completes19 gameplay assertions including independent exploration, reconnect and cross-dimension following. Chest render/click checks cover the small logical viewport. See [playtest.md](playtest.md) for final artifact details and retained failures. Real two-account Steam invite/reconnect and subjective human playfeel checks remain untested. Expanded native runs still report offline Steam and shutdown/resource errors; these are recorded separately from functional assertions. This is a source update for review, with no new installed or published release.

## Build and verify locally

Use the matching Godot 4.6 double editor and GDRETools 2.7.4 with your owned game 5.2 installation. Generic single-precision Godot builds are incompatible. From the repository root in PowerShell:

```powershell
./scripts/build_mod.ps1 -Godot <matching-editor.exe> -Gdre <gdre_tools.exe> -GameExe <lucid-blocks.exe> -Test
./tests/test_install.ps1
```

Replace the angle-bracket paths with quoted absolute paths. The builder uses disposable profiles and copies of the original libraries, validates explicit result markers and errors, then publishes only the mod PCK to the chosen output directory. It leaves the original installation and personal saves unchanged. Admission fixtures need local ENet socket access. Installer tests use synthetic game directories; they do not install into Steam. Keep recovered commercial files, tool binaries, test profiles and logs under ignored `work/`.

The default output is `work/local-build`; use `-OutputDir` to change it. Omit `-Test` for a build with script-load checks only. After a combat or rendering change, run the same builder with `-CombatTests` instead of `-Test`; it retains the original rendered Gel checks and their deadlines. Routine changes need the relevant local tests, not a native rebuild or a multiplayer soak. The generic recovered-project exporter and old diagnostic-only modes are retired.

## Upstream README (historical)

The instructions and known issues below describe the upstream 4.0.1 release, not the current 5.2 development branch. In particular, its download/install steps refer to old artifacts.

Multiplayer Co-op mod For Lucid Blocks.


## Quick start

1) Download From Github
2) Unzip, and open "dist"
3) Copy `lucid-blocks-coop.pck`.
4) Paste it into your mods folder — the `mods` folder sits next to `lucid-blocks.exe`
   (EX: `SteamLibrary/steamapps/common/lucid-blocks/mods`). Create the folder if it
   does not exist.

> Updating from an older build? The June 2026 game update (build 4.0.1) moved
> `lucid-blocks.exe` up one folder. If you previously installed into the old nested
> `common/lucid-blocks/lucid-blocks/mods`, delete that old `.pck` and reinstall next to
> the new exe, or the mod will silently fail to load.


## How To Join Co-op

1) [Host] needs to go into the world press F5 or do /host
2) [Host] Enter IP (you can use LogMeInHamchi, Tailscale, or Port Forward and use your public IP address, etc...)
3) [Guest] Once they are hosting, enter their IP and click join.


## Compatibility

- Updated for game build **4.0.1** (June 2026). The 4.0.1 update changed the save
  format (chunks now live in per-region files instead of one big save dictionary) and
  added a backup/restore menu, which is what bricked older versions of this mod.

## Known Issues

- Apotheosis is 'working' but its not super tested so make sure to back up your world
- **Shared-world co-op saves fine** on 4.0.1: when both players are in the same world,
  the guest isn't the save authority, so its edits go through the host's live world and
  persist normally.
- **Private-instance features (separate pockets / per-player Apotheosis) are not yet
  reconciled with the 4.0.1 region-file save format** and can lose/revert that instance's
  data on reload. Back up before relying on them. See the co-op save-sync notes for the
  exact spots (guest world-patches still persist via the old in-save-dict path).
- Host can save and quit great, but guest has to relauch game after playing COOP
- Manikin can't agro Guest, and will always attack
- Gel, and small gel are invisble to Gust but can beat the heck out the guest anyway


## Future

- Steam-Join: able to join freinds from steam instead of lan joining.
- Real-Mutliplayer, Instead of Guest being "rubber banded" to the host, each player can play independent of one another on a world.
- Seprate-Apotheosis: Per player in coop, and you can visit each other Apotheosis (but I do  kinda like one per world its kind of cozy)
- Player-Model: I put this player model in pretty fast but it is kinda fitting, I want to add more aniamtions to it, and add in easy way to get any 3d model playable, and be able to add skins, and pick skin in game.
- Ender Chest: Minecraft like ender-chest.
- Dedtcated server: Be able to host the server independent from lan or steam, and have a ton of players on one world for 2B2T vibes.
