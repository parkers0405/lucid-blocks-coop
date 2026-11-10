# Lucid Blocks co-op — state
Updated 2026-11-10. Solo-maintainer simplification complete; ready for code review with existing gameplay limits.

- Branch fix/review-ready-compatibility. Original target unchanged: game5.2.0.0/build26206996, Godot4.6double/GodotSteam4.17.1, original native libraries.
- Removed 1,307 net code lines, including320 unused production lines. Tests23->13files; routine commands5->2. No active gameplay feature or persistence/authentication protection removed.
- Production cuts:15 definition-only manager helpers,2 alternate test-only store APIs, permanently false multi-region path. Local loading and fail-closed native guards remain.
- One builder: scripts/build_mod.ps1; -Test runs local contracts, -CombatTests is separate optional rendering regression. Removed duplicate exporter and5diagnostic-only modes. Profiles, explicit result/error/exit gates, deadlines and atomic publication remain.
- Tests use actual checkpoint/lease APIs. Overlapping primitive tests and repeated wire mismatch runs consolidated; channel/batching and metadata-boundary/corruption checks retained. Old world-process diagnostic launcher retired; historical evidence remains in logs/Git.
- Strict final c9adda97c9a44642afe55a8a2c04a2aa PASS326assertions/0failures+67scripts, exit0, noERROR/SCRIPT ERROR. Nested admission-data26excluded from total. Expected negative-case warnings/ObjectDB warning remain visible.
- Installer/build fixtures PASS23assertions, work/solo-installer-final.log. Initial sandbox atomic Replace failed; unchanged outside-sandbox run passed.
- Initial API-migration baseline dca42208832a4b9c9734f5bb4d51e0c1 PASS388+67. First lean-run f6b23f4020b44953befdb7c74528c3a4 failed a duplicate fixture variable; corrected name and made fixture load failures terminate promptly. Final rerun above passed.
- Candidate work/solo-final-output/lucid-blocks-coop.pck SHA B6131661D78BF84D88E27A48E278132EB810A05B4BC1635EF225AB4CEA425E03. dist remains stale; use source builds.
- Independent review found no significant issue or supported feature loss. Original install/native DLL/personal saves and102unrelated.import edits untouched. No owned test runtime remains.
- Deferred: expanded live exploration/private visits/chest/reconnect/restart/soak, real Steam/human tests and optional rendered combat rerun. Earlier two-process smoke passed8assertions but strict shutdown failed10errors/role, also in original/offline controls; unresolved, never whitelisted.
- Next: open review PR when requested. No PR/merge/main push/install/release performed. Local contracts do not certify a release.
