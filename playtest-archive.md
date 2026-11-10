# Archived playtest evidence
## 2026-10-23: baseline inventory
- Steam manifest: app 3495730, build 25451214, depot manifest 7072406399823411834.
- Executable metadata: 5.1.0.0; SHA-256 fingerprints recorded in authorization.md.
- Original installation contained the executable and three DLLs; no mods folder.
- Fork created at https://github.com/trism-dev/lucid-blocks-coop-updated; local branch fix/current-build-compatibility.
- GDRETools v2.7.4 downloaded from the official GitHub release. Help verified using an isolated APPDATA profile under work/.
- Gameplay, multiplayer, save persistence, Steam invites, and rollback: NOT YET TESTED.


## 2026-10-24: resumed verification
- Global execution/progress preferences saved outside the repository.
- Windows installer fixtures: parent reran tests/test_install.ps1 with Windows PowerShell; 34 assertions passed. Worker also reports 34 under pwsh. Synthetic fixtures do not establish game compatibility.
- Original game pack with matching editor and nested physical DLL layout: runtime probe reports steam_peer=true, world=true, steam=true. Missing Main-node errors are expected for this scene-free interface probe; vanilla gameplay remains unverified.
- Worker verified a two-file raw-source/remap sentinel PCK loads through the original ModLoader. Full mod packaging and script compilation remain pending.
- Checkpoint 1fd78c6 pushed to origin/fix/current-build-compatibility; no PR or release created.

### Current-version startup gate passed
- Candidate: work/production-build-check/lucid-blocks-coop.pck, SHA256 4F25E1293B97179E49305CE817914D8E5CCFF4E197E0B6AF7AAC56AC71A15935.
- Logs: work/build-logs/6ddc9311575d4727a5270b10a99c7a29. Normal original Main startup prints COOP_BUILD_CHECK_OK 61; no ERROR or SCRIPT ERROR lines.
- Assertions: LUCY=8, TORUS=9, Entity.dexterity=0, water-flow method exists and returns zero on unloaded terrain, offline remote-peer check returns false.
- Fixes: restored dimension/generator interfaces and shared water-flow/stat APIs; corrected MultiplayerAPI peer lookup; skip absent debug spawn resources and support current capsule names.
- Base game itself leaks its on-screen keyboard KeyListHandler at shutdown. The unpublished test-only probe frees that exact helper before quitting; production mod does not alter base-game cleanup.
- This establishes startup/interface compatibility only. Multiplayer, persistence, exploration, Steam invitations, and ender storage remain unverified.


## 2026-10-24: pre-pause admission result and layout adoption
- Last run began before the user's pause request and was collected during adoption; no implementation resumed.
- PASS: admission59, native guard4, startup61. Logs: work/build-logs/9ea0857f63304b5894e5dfea7f0c5964/runtime.stdout.log.
- Artifact SHA256: D9AB22FBB5B0F9C52F6D7A9F97933925799F951E47B608E49DD1AA0645DF9FEA. Working code/tests remain uncommitted.
- Original-path evidence predates move to Godot/Lucid Blocks. No post-move runtime test performed during documentation-only adoption; rerun from new directory on approved resume.
- Game-development workflow parse check: PARSE OK. Current STATE.md is 11 nonblank lines; old project path absent, new nested repository present.
- Implementation paused pending user's confirmation and explicit resume. Real Steam invites, gameplay, private persistence and remaining features unverified.


## Historical continuation checkpoints archived 2026-10-25
## 2026-10-25 renewed headless diagnostic — FAILED
Synthetic duplicate-ready guard check passed. Packed headless run3997b5d2d8684c43965d9147c73f67d6: setup marker and actual SaveFileManager .gd identity observed; snapshot path errors, no final result, external15s timeout. Safe-path correction unexecuted. No rendered/combat test. See process-log final entry. Stop at consumed capture allowance.

## 2026-10-25 startup diagnostic preparation — BLOCKED
PowerShell launcher parsing passed with matching Godot 4.6 double identity. No packed-game or rendered test launched. Empty-project selfcheck failed first on profile directory creation; corrected isolated APPDATA reached setup/node/ready/result markers but failed on duplicate ready connection. Guard added, unexecuted; stopped after two failures. Logs: work/startup-diagnostic-selfcheck/. Synthetic evidence does not establish real packed identities. Details and next gate: process-log.md final entry, CONTINUATION.md resume checkpoint.
# Verification evidence

## 2026-10-25: early-profile isolation failed
- Run0fa99aa1a7c143c4b4428ad232e17b20: Vulkan initialized, original shader baking completed; early observer emitted no seed marker, combat never started. 180-second timeout, launcher terminated runtime, exit1. No renderer pass or screenshots.
- PowerShell parser/whitespace checks passed. Next: observe actual packed node/script identities before another fixture edit/run. No production source or installation changes.


## 2026-10-24: isolated renderer attempt failed
- Run14b04f39095e410ab16a6d5d57899ae2: Forward+/Vulkan initialized; deferred disposable device setup did not prevent original shader baking. No isolation/combat/result marker or Gel screenshots. Strict gate failed; no rendered pass.
- Existing original baking produced Jolt softbody physics-space errors. This does not establish the cause of the earlier Intel driver crash. Next fixture ordering repair must occur before Main startup decision. No production combat edits or install; owned process inventory empty.


## 2026-10-24: combat and rendered visibility blocked
- Production candidate remains uncommitted and unverified. Current attack signatures match required-three-argument subclasses; existing Attack/Heart/RPC callers now send hit positions. Gel uses current mesh indices and softbody relocation. Terminal rejection UI and offline Steam guard were exercised.
- Last headless gate:44 checks,1 failure,62 startup scripts, no ERROR/SCRIPT ERROR; logs work/build-logs/ae08502fc9ff4ef0ae9321cbd1c0fb70. Reviewer found its remaining rest-pose assertion invalid after physical deformation; it was not treated as a pass.
- User authorized rendered replacement check once:50 checks,2 visibility failures,62 startup markers, plus real renderer errors and90-second cleanup timeout. Logs/images work/build-logs/cafca540174343a585f1d6d4953ce09e. Both PNGs blank; no rendered pass.
- Cause of verification block: target project uses Forward Plus; OpenGL3 on Intel Iris Xe exceeded shader-instance limits and failed original shader compilation (eye_offset). Next route is Forward+/Vulkan availability and an isolated original-material visibility test, requiring renewed cycle authorization. No further retry or install occurred.
- Failed diagnostic PCK SHA D66C3257856C69B49C0635F90A300C1DB2D2BB9D1674BFC71248154B295B98D6 is not a distributable build. Remote Manikin-to-guest combat remains unverified.

## 2026-10-24: reviewed region and legacy migration checkpoint
- PASS28 region fixtures,43 native/loader/ACK checks,62 startup scripts; matching Godot4.6 double original-pack -RegionTests gate.
- Logs: work/build-logs/3cb5a2c872c84177ba14da97eae12259. SHA ED2B56B51DD598A66FF5EE40617FBAC7AC690D9D0BBE173733895201CAB28F3A.
- Covered native block IDs/awake64, partial chunks/channels, owner isolation, corrupt/failed publication, host failed-save transitions, normal+legacy Alice/Bob/public handoff, conflict/precedence, retained legacy sources, failure cancellation before disposal. Targeted independent review resolved the prior P1s.
- Warnings remain: existing ObjectDB leak in expanded test harness and injected-write warnings. No ERROR/SCRIPT ERROR; not a leak-free claim.
- Still unverified: end-to-end multiplayer save/rejoin, Steam identities/visits, independent travel, combat, ender storage and physical power loss.



## 2026-10-25: native baseline region and collision probes pass
- Original library control888d21a6a0304ea9973457d3ee8e6ea8 and fingerprinted compiled baseline dccba86e445d4642a39aecad9c785a68 passed region28/runtime43/startup62 and isolated native collision3, strict error/exit gates. Residual ObjectDB warning recorded.
- Collision fixture uses separate physics space, seeded native chunk, loaded identity/solidity, exact top-face ray and bounded air ray. Initial air ray crossed generated ground below the chunk; corrected fixture bounds, unchanged tolerance. Native source baseline was reused, not rebuilt.
- Direct flags: -RegionTests -CollisionTests [-NativeBaseline]. Paths, target/tool identities and exact commands in process-log.md. Original install/personal saves unchanged; baseline test-only, not approved for installation or multiplayer streaming.


## 2026-10-25: combat assertions pass; inherited rendered shutdown gate blocked
- Modded combat a9189d1f77ce4156acf2407177fd968e and exact shipped-runtime3887012779a94d989849360065f9fb81:55 checks0failures, both original actors center25/25, shader seeded/skipped/isolated,62 scripts. Overall FAIL:77 resources/Jolt3 at shutdown; no verified rendered artifact.
- Startup-only mod control e899c40a684c4b1db0ffb778c6c3238a reproduces77/Jolt3 without combat. Original shipped-runtime control eed084e7eb6a47048eb59aebd8ebd99c loads only observer pack (no co-op PCK/overrides, script-check loop or cache cleanup); it completes control/isolation markers and exits0 but reports509 resources/Jolt19. Inherited shutdown failure established; exact ownership root remains unproven. Strict ERROR gate retained.
- Diagnostic caff57dd1ff74fac8011780ae5a7f205 passed actual packed identities/ready ordering. Observer moved to entry+snapshot; detached paths and duplicate callbacks guarded. Tooling switch checks3, deadline checks2 and native abort check passed. Independent review corrections applied. Local commits5a117d1/12cdc23; no push/install.
- No cold-start shader/driver remediation claim. The prior Intel fault report does not establish the current shutdown cause. Details: process-log.md and retrospective.md.


## 2026-10-25: mod-only identity, chest and canonical terrain checkpoint
- Strict combined PASS33c9c4ab9c854c6096683443b229df96 using matching4.6double runtime, original game pack and unchanged native DLLs, isolated profile. Region28/runtime45,admission73,native guard4,storage17,chunk authority13,profile lifecycle/UI16,actual native canonical9:205 assertions0failures,66 script checks. Exit0 and no ERROR/SCRIPT ERROR. Tooling switch checks3 pass; scoped diff whitespace clean.
- Host-issued durable LAN credentials and transport-derived Steam IDs bind profile RPC to sender. Actual Steam peer mapping method observed; real two-account behavior remains unavailable. Reconnect revision snapshot seeding, unknown/duplicate/corrupt credentials and forged profile-key RPC covered.
- Durable profile/chest transaction, host restart, failed-write recovery, replay/stale rejection,21-slot UI command routing, broken-access invalidation and disconnected-guest write exclusion covered. Native fixture loaded two independent bubbles at0/1024 and applied live canonical blocks/water/fire; queued epoch guards covered.
- Repairs retained: packed-array copy API regression; UI emitter-free bug; native fire after block/water reconciliation; test-world dependency injection rather than global Ref substitution. Frozen tests now use packed-module path (standalone fallback retained). Each distinct failure had one successful repair round; no exhausted product retry branch.
- This is a passing implementation checkpoint, NOT end-to-end functional co-op certification. Remaining: entity/dropped-item authority and dimension-specific saved nodes, independent visits/rejoin integration, bounded checkpoint retention and final review. No native modification/install/push/release. Artifact only ignored work/mod-bounded-terrain-output (A0BC908C63B03B3E7A6C989E149AEBCC035C010454B9F564304152264220A0F0).


## 2026-10-26: atomic instance ledger and installed5.2 compatibility checkpoint
- Strict PASSc1b7ee985c8044c8b4a4ba406bad6fd2: region28/runtime45,admission76,nativeguard4,store17,chunk13,profile16,canonical9,instance20=228assertions0failures+67scripts. Original5.2packedgame and unchanged nativeworldDLL, matching4.6double, disposableprofile. Build exits0 and strictERRORgatepasses. Tooling switch3pass. Storagecommitc0c83dd; no install/push.
- Atomic shared ledger preserves inventory+object sides through interruptedpickup; UUID ownershipCAS, formerownermissing/delete rejection, tombstones, unloadedobject capture, owner-isolatedsnapshot and explicitcorruption cancellation covered. GuestprofileACK now participates in travel barrier. Runtimeentityupdates no longer persist separate sidecar.
- First run84fd strictFAIL: admission73/16failures, follow-on disconnectedRPCerrors; storage/region/profile/canonical/instance allpassed. ObservedSteamauto-update to5.2.0.0/build26206996 explainsversionguard rejection. Scripts-only comparison390game scripts:4changed2new; relevant save/world/player interfaces unchanged. Modtargetstrict5.2 and BubblebearANGRYcompatibility added, old5.1 rejection/newHwobbbparse covered. Targetbranch repair1passed; no repeated unchangedprobe.
- Artifactwork/mod-ledger-5.2-output/lucid-blocks-coop.pck SHA53DD4479A57CC869AB2520659CB37EC3EDDCF6E2830A48C51524862738B3EBD8. Not completeco-opcertification: reviewP1s remain privatelegacyadoption, chestACKlifecycle/pickupreceipts, runtimeUUIDsplitbrain/droptransfer and latchedterrainhandoff. No two-processlivefixtureyet; no secondauthenticatedSteamaccount/machine.

## 2026-10-26: private objects and chest lifecycle checkpoint11b6bc5
- Strict PASS1509ba30e902441484425f47cfa92e15 using original5.2pack/nativeDLLs:239 assertions0failures+67scripts. Region28/runtime45,admission76,nativeguard4,store17,chunk13,profile24,canonical9,instance23. Exit0 and strictERRORgates pass; scopedwhitespacecheck clean. No new expensive repair needed for this reviewed branch.
- Private restore uses sourceowner before pendingowner changes. Ambiguous legacy nodes remain untouched and cancel load; proven owner and explicit namespaced nodes remain until canonical checkpoint. Three new assertions cover these cases.
- Manager owns chest transaction lock/token independently of panel. Forcedclose waitsACK; acknowledgedinventory applies before queuedpickup; duplicate/wrongACK ignored;5stimeout enters reconnect recovery with lock held until authoritative profile restore; inactive/downed chest requests rejected. Eight additional profile assertions pass. Durable host pickup receipts across crash remain nextphase.
- Artifactwork/mod-lifecycle-5.2-output/lucid-blocks-coop.pck SHAFFB27A843ED41C7301DE0E68E89E89A41055923C8756D1AAEF2BDD4A1DE8584C. Sourcecommit11b6bc5. No native/install/push/release changes. Remaining latchedchunk/UUIDhandoff, exactUUIDdroppickupdurability, originalsolo-adoption edge and retained two-process gameplay/Steamexternal limits.


## 2026-10-27: strict lease integration PASS; user requested stop
- Strict632f5b14e0c642db9fe424ba02a796e1 passed311assertions0failures+67scripts with original5.2pack/nativeDLLs andSteaminit0. Region28/runtime46/admission83/nativeguard4/store17/chunk13/profile24/canonical12/instance25/pure26/lease33. Tooling3pass; scopedwhitespacecheckclean. NoERROR/SCRIPTERROR; expectedmigrationfailure/ObjectDBwarnings retained.
- Latchedchunk/UUID ownership, frozenfinalcheckpoint/CAS/partinstallationACK/resume, staleepoch/phase rejection, exactUUIDdrop restoration, atomicpickupreceipts/capacityfailure/spillconservation, realcontrolled-lockpresence anddisconnectcanonicalreclaim covered bynamedfixtures. Helper/nativefixtures do not establish full two-process gameplay.
- Repair1 passed307assertions but strictfailed1resourceatexit. ShippedDrop preserve methods allocateunparentedInventoryNodes; mod-ownedcapture/load nowavoids them andfourallocation/nativeformat/motionregressions pass. Strictresourceerrorgone. Optionalverbose-stage-traces didnotappear, soexactpriorresourceidentitywasnotdirectlynamed.
- Artifactwork/mod-lease-repair2-output/lucid-blocks-coop.pck SHA AE56A9F254B3E8E5E813F7265A0F0F171285C25E54A720BEFD4368AC334D4D51. Useraskedfinishlastcommitthenstop. Remainingprivate respawnmetadata andactualtwo-processscenario unfinished; externaltwo-accountSteam unavailable. No native/baseinstall/push/release changes.


## 2026-10-27: private respawn metadata strict PASS
- Strict dd4c62d66fe64113b2832b3422e78bd1:369 assertions, zero failures,67 script checks; original5.2 binaries, Steam0, no ERROR/SCRIPT ERROR. Region28/runtime46/admission90/native4/store17/chunk13/profile24/canonical12/instance25/lease26/runtime33/private20/respawn31.
- Atomic per-instance typed respawn map, absent-versus-empty migration, leased resident merges, private owner/visitor isolation, FIRMAMENT reset/restart restoration and public/solo path compatibility covered. Protocol5 rejects old peers. Two changed-input repairs consumed and resolved.
- Artifact work/mod-metadata-repair2-output/lucid-blocks-coop.pck SHA256 766BD86D1368FBB402F560B19B545D51AA3C950EFFFEE1AD7E0FC347EF5F1DED, commit2451c54. Helper fixtures do not certify full two-process gameplay. Expected UID/ObjectDB warnings retained.


## 2026-10-27: strict373PASS; live smoke BLOCKED
- Strict3ccaad4290b14a79a8730d4a2565ccd9:373assertions0failures+67scripts, Steam0, original5.2binaries; tooling3pass. Profile26 and instance27 include real closed-ENet cleanup and generic saved-map restore regressions. Independent review found no extra blocker in final fixes/harness. Productiond6fdf19.
- Finaltwo-processsmoke3bab2ce32a6f4ba3bf1aa74157ed1e98: hostloaded+host_session1PASS, guestmenu1PASS+joinattempt, bothport37927/Steam0. NativeWorld159 set_loaded_region_center crashes0xC0000005; no role completion/result, no final preserve-map error. StrictFAIL. Two smoke repairs exhausted. Native cause unverified; no native edits.
- Full exploration/dimensions/visits/chest/reconnect/failure/onehoursoak UNRUN. Real two-accountSteam/human testing also unavailable. Final six-roleownedprocessaudit0; stopped. Artifactwork/mod-cleanup-final-output SHA2C21B96C2E695DBD5CFBD6CE313BBE3FA90D56FD4CD171C82B729681D109F006 is contract-verified/gameplay-unverified, not installed/released.

## 2026-10-27: readability revision PASS
- Strict7651d1bc41834fae8e06dead92f37e2d passed379 assertions, zero failures and67 script checks. Tooling3pass. Original5.2 binaries, Steam0, no ERROR/SCRIPT ERROR. First attempt passed; no repairs used.
- Personal store23 includes six new checks for stack merging, item positions, empty chest withdrawal and unchanged revisions after refusal. Existing identity/terrain/profile/lease/private-respawn checks passed.
- Artifactwork/mod-revise-output/lucid-blocks-coop.pck SHA FD1B3FDAC2DD5DFC8C941B650CC3AAC870369E18FAA71F4F7935991D2C375DA1. Only readability changed; save format/protocol unchanged. Full gameplay/native crash not retried; earlier blocker and limits remain.



## 2026-10-27: broad readability correction PASS
- Strict3d21aab9ba904f2d833f37257430def1 passed383assertions0failures+67scripts, Steam0/original5.2binaries/noERROR. LANfixturecompilemarker present without executing it. Fournewchunkchannel/seedchecks pass (chunk17). Existingchest23/otherfixturespassed. Firstbroadattemptpassed/norepairs. PSparsers/scopeddiff/tooling3pass; independentreview no significantissues.
-15 implementation/test/toolfiles changed; fullcoverage revision-coverage.md. Originalprotocol/saveformat/guards preserved. Artifactwork/mod-revise-full-output SHA F5FBC38A96127C19F4D3DEE8A0ED77E7ED84CCDE1FBEE7873604A2B3063B5219. No native/livegameplayretry/install/push/release. Earliernativecrashandtwo-repairlimitremain; fullco-opnotcertified.

