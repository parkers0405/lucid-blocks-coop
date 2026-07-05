# Lucid Blocks Co-op Mod

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
