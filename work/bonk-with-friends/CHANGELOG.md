# Changelog

## 0.3.2
* **Version Sync:** Updated the internal plugin version number to ensure everyone playing together is on the correct build.

## 0.3.1

* **Performance & Garbage Collection (GC) Overhaul:** 
  * Reworked some core network types under the hood — the game was doing way more memory cleanup than it needed to mid-match.
  * The targeting and enemy systems now recycle objects instead of constantly creating new ones (implemented zero-allocation object pooling for networking and spatial grids).
  * Converted high-frequency network payload data (like `EnemyState`, `PlayerInfo`, and `BossInfo`) from classes to structs to completely bypass heap allocations.
  * Replaced `Tuple` with `ValueTuple` in transform synchronization to eliminate continuous reference allocations.
  * Ripped out LINQ in a few critical spots (like boss orb targeting and enemy special attacks) and replaced it with manual loops and static pre-allocated buffers.
* **State Management & Stability:**
  * Match cleanup was kind of scattered before — it now all happens in one place when a match ends (`MatchContext.EndMatch`). No more weird leftover state bleeding into the next round.
* **Build & Logging Improvements:**
  * Debug logs are now completely gone from release builds, not just silenced. This saves CPU cycles by stripping out string formatting entirely when compiling for Release.
  * Fixed Visual Studio/Rider solution mapping so `Debug` and `Release` configurations display correctly in the editor UI.

## 0.3.0

* **Framework Migration:** We’ve officially moved the mod off MelonLoader and over to BepInEx 6 IL2CPP. This makes installation through r2modman way smoother and gives us better stability overall.
* **Massive Under-the-Hood Rewrite:** Completely gutted and rebuilt how the mod handles multiplayer sessions (`MatchContext`). This fixes quite a few issues.
* **Combat & Synced Interactables:** Enemies now sync their attacks and physics properly. Chests, shrines, and other interactables are also fully synced. 
* **New Features: Spectator Mode & Revives:** If you die, you aren't just stuck staring at a wall anymore. You'll enter Spectator Mode to watch your friends, and they can bring you back via the new Revive Feature.
* **Forest and Desert Playable:** We've ironed out the majority of the desyncs for the first two biomes. Forest and Desert are now running really well in co-op.
* **Bug Fixes:** 
  * Fixed the annoying "ghost pickup" bug where XP orbs would get stuck floating in the air.
  * Fixed the soft-lock where players would get stuck forever at the spawn portal if they loaded into the map a few seconds behind the host.