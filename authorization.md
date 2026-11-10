# Local modding investigation

Date: 2026-10-23. Owner: Tristan (trism-dev).

The user owns the installed Lucid Blocks copy and explicitly requested this compatibility update. The developer documents recovery with GDRETools and modification of the native extension at https://lucidblocks.com/modding.html. This investigation uses that documented modding workflow, without DRM bypass or redistribution of the recovered game.

Target: Steam app 3495730, build 25451214, executable file version 5.1.0.0. Original installation remains read-only during recovery; extracted files and private test saves stay in ignored work/.

SHA-256:
- lucid-blocks.exe: 336FECEEB499A4FA3832FEA2D58BBE3C52B0B111086CAC42134DA4A16B051F83
- libgdblocks.windows.template_release.double.x86_64.dll: B25C20E9AE4CF0C21CBC015CDF58A8F4C3F0C5B8AA1652F81A071F471CD2CFEA

Upstream mod baseline: parkers0405/lucid-blocks-coop at 57140c7abe02a921defa4184d474fb3e0ef841eb. Preserve upstream attribution and notices; no new license is assigned to inherited work.

## Installed target update observed2026-10-26
Steam automatically updated the read-only installation to game5.2.0.0/build26206996. Current executable SHA256 CB6EA42754BA9075F4FC2141AEC39A13159DA7DDF835F13334D367E9FBC4A558. World nativeDLL remains B25C20E9AE4CF0C21CBC015CDF58A8F4C3F0C5B8AA1652F81A071F471CD2CFEA. Existing user authorization continues to cover mod compatibility for the owned installed game; no installation changes were made. Scripts-only recovery is ignored work/recovered-5.2-scripts, existingGDRE2.7.4, exit0 in18seconds.390game scripts compared to recorded5.1:4changed2new; relevant save/world/player interfaces unchanged. The mod targets5.2strictly; old5.1results remain historical contract evidence, not current compatibility proof.
