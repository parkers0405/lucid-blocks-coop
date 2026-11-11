# Two-player co-op compatibility update

## Pillars
1. Both players can explore independently, including different dimensions, with uninterrupted ordinary movement and camera control.
2. Host-owned saves preserve each player's world and inventory without duplication; routine saves stay outside the input path.
3. Joining and leaving work through Steam or LAN without restarting the game.

Goal/ambition: complete the existing two-player compatibility mod; the new-game retention tiers do not apply. Target: Windows Steam build26206996, executable5.2.0.0 (automatic installed update2026-10-26; prior target5.1). Upstream baseline 57140c7abe02a921defa4184d474fb3e0ef841eb.

Loop: host loads world; friend joins; explore/build/fight independently; visit personal Apotheosis; save, leave, and return with progress intact.

Include all upstream README Known Issues, Steam invites, independent terrain loading, simultaneous dimensions, personal Apotheosis visits, and bounded personal ender chest. Ender chest reuses an empty cache cube and standard inventory capacity, is designated by host with /enderchest, is personal per host save, and survives destruction of access blocks.

Exclude new art/models/skins, dedicated servers, more than two players, new recipes, hopper integration for ender chests, and unrelated issue-tracker requests.

Playtest questions: Can both players travel apart safely? Does every acknowledged edit survive restart? Can a guest leave/rejoin without restarting? Do gels and Manikins behave consistently? Can one player ever see or duplicate another's personal storage?

Applied lessons: require strict runtime error/completion gates rather than exit0; pin current installed build before compatibility work; preserve original native behavior and use local script checkpoints; atomic inventory/object commits and explicit source ownership prevent duplication/private-world loss. Evidence routes: playtest.md, retro.md and ../guide.md.

Current implementation hypotheses: latched ownership plus final checkpoint/install acknowledgement prevents moving-boundary losses; exact-UUID durable pickup receipts prevent reconnect replay; manager-owned chest transaction lifetime preserves acknowledged inventory after UI closure. These remain unproven until their named local fixtures and retained two-process scenario pass. Two-account Steam invite/reconnect evidence is unavailable; no release claim follows from local contracts alone.

Gameplay quality acceptance: routine terrain saves and pickup transactions preserve movement/camera; Close/Escape dismisses chest panels immediately; gliding survives ownership preparation; reconnect restores approved state; background file work requires no player setup. Verify focused contracts and bounded local gameplay rather than adding a permanent soak/test framework.
