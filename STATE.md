# Lucid Blocks co-op — state
Updated 2026-11-10. Ready for a code-review PR; no PR opened, installation or release performed.

- Branch: fix/review-ready-compatibility. Current source includes radius fix db9794e and runtime restoration c08bcf7. User's unrelated .import edits preserved and excluded from commits.
- Scope: finish autonomous local work for review; tests involving other players or user input deferred by request. No native/base-game/personal-save changes.
- Target: game 5.2.0.0/build 26206996; Godot 4.6 double/GodotSteam 4.17.1; original native DLL unchanged.
- Strict build db2e550018b04ad392279a5e66786697: PASS 388 assertions (nested admission-data 26 excluded), 67 script checks, zero ERROR/SCRIPT ERROR. Expected negative-case warnings and ObjectDB leak warning remain visible.
- Tooling: installer 42 assertions, build switches 3, shader deadlines 2, native timeout 1 passed. Installer first attempt hit a transient Windows replacement error; unchanged rerun passed.
- First sandbox run ef06bfd6e1c440fcbc8dd33795fd2a54 failed admission RPCs due to blocked loopback traffic; suite passed with local socket access. No production fix required.
- Candidate: work/pr-ready-output/lucid-blocks-coop.pck; SHA256 0B9AE192C10BCE1B3E891D0E007B0543702A39C8232887ABBBF5BD67D195B157, identical to the prior verified candidate. dist remains stale and README directs source builds.
- Independent source review found no additional concrete production blocker in identity, ledger, chest, lease and travel paths. Corrected stale target/evidence/build docs and removed tracked local instructions and implementation-history references unrelated to the mod.
- Earlier two-process smoke 5b8064fc: host 3/0, guest 5/0, completion/exit 0, initial lease and durable checkpoint passed; strict FAILED 10 shutdown/resource errors per role. Original/offline controls match categories/count; exact causes unresolved, no whitelist or passing gameplay claim.
- Deferred: full exploration/convergence, dimensions/private visits, chest/reconnect/restart/failure/soak gameplay, real two-account Steam and human playfeel. Contract coverage does not certify these scenarios. No native/shutdown investigation or unchanged gameplay retry performed.
- Original install and personal saves remain read-only; recovered content, profiles, artifacts and logs remain ignored under work/. No owned test runtime remains.
- Next action: open the review PR when requested, carrying the known gameplay/shutdown limits. Release certification is a separate gate.
