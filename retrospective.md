# Lucid Blocks continuation retrospective — 2026-10-25

## Outcome and limit

Current-version combat behavior is exercised successfully:55 assertions, both original Gel silhouettes25/25, real Forward+/Vulkan readback, shader isolation and62 script checks. Native source baseline passes the same28 persistence/43 runtime/3 collision checks as the original library. These are narrow local results, not completed co-op or a clean rendered build.

The strict rendered build remains blocked on shutdown resource errors. The shipped game with only an observer pack, no co-op pack/overrides, no combat suite and no cache cleanup also reports509 retained resources and19 Jolt leaks. The modded fixture after test-only cache release reports77 and3. An inherited failure is demonstrated; an exact ownership chain for all77 is not. The strict ERROR gate stays enabled and no current artifact is approved for installation.

## What changed

- Local commit5a117d1 adds an early startup observer and detached-node/duplicate-callback regression fixture.
- Local commit12cdc23 restores mandatory three-argument Entity/Gel attacks, forwards actual hit positions through Attack/Heart/RPC paths, uses current Gel mesh indices/softbody relocation, retains actionable compatibility rejection UI and avoids offline Steam presence calls. The55-check fixture covers these contracts.
- Build tooling adds startup-only diagnostics, explicit rendered controls, fingerprinted native-baseline and collision probes, and rejects fixture switches that would otherwise silently take an untested export path.
- Disposable copies of the shipped executable use their embedded pack, because that executable rejects `--path` overrides. Installed game and personal saves remain unchanged.
- Native loading failure never frees a World while worker tasks may still reference it. The test requires a disposable marker and terminates that owned process; marker gates reject incomplete output even when Windows reports exit0.

## Evidence to reuse

| Evidence | Result |
|---|---|
| caff57dd1ff74fac8011780ae5a7f205 | Startup identity diagnostic passed; real SaveFileManager and ShaderLoader `.gd` identities and ready ordering observed. |
| a9189d1f77ce4156acf2407177fd968e | Combat55/0, original actors25/25 each, startup62; full gate failed shutdown77/Jolt3. |
| 3887012779a94d989849360065f9fb81 | Same combat result using exact shipped executable; same shutdown failure. |
| e899c40a684c4b1db0ffb778c6c3238a | Modded rendered startup without combat also fails77/Jolt3. |
| eed084e7eb6a47048eb59aebd8ebd99c | Original shipped-runtime control, observer pack only; no co-op code or cleanup; shutdown509/Jolt19. |
| df8bddc4fb7b49a79f8103c3e51f9ced | Compiled native baseline passed region28/runtime43/startup62. |
| 888d21a6a0304ea9973457d3ee8e6ea8 | Original native library additionally passed isolated collision3. |
| dccba86e445d4642a39aecad9c785a68 | Compiled baseline passed the identical collision3 plus28/43/62 and strict error/exit gates. |

Logs and screenshots are under ignored `work/build-logs/<id>`. Retained tooling checks: `tests/test_build_switches.ps1` (3), `tests/test_shader_deadline.ps1 -Godot <matching editor>` (2), `tests/test_native_timeout.ps1 -Godot <matching editor>` (owned-process termination). These tests extract actual deadline/abort functions rather than maintaining duplicate implementations.

## What failed, and what it taught

1. The old observer installed in `_ready()` missed earlier scene-entry events. `_enter_tree()` plus a snapshot finds nodes before readiness; snapshots can contain detached descendants. Guard path queries and make signal connections idempotent. A synthetic global workflow fixture was never used as evidence for this game's identities.
2. A15-second external diagnostic deadline cut off normal synchronous startup. A SceneTree timer does not interrupt that work. Retain a real external deadline and observe startup phases before calibrating it.
3. A10-second shader-completion deadline, even after World startup, interrupted original UI work on this GPU. Use the observed60-second post-World bound within the180-second process limit. Early profile seeding has its own10-second gate. Missing-shader and completed-shader branches have retained headless checks.
4. Early combat runs completed assertions but leaked554 resources. Releasing test-only ItemMap scene caches reduced this to77. That isolated a contribution; it did not prove a complete fix.
5. Feedback coroutines use pause-sensitive engine-clock timers. An initial real-clock wait failed three new assertions; matching the original clock passed all55. That fix did not eliminate the77 remaining leaks, so repeating it would not answer the remaining question.
6. Verbose leak inventories mapped retained Jolt shapes to scene resources, with no leaked Gel/Heart Nodes. A startup-only control then reproduced the same failure; an original-game control established the inherited boundary. No unsafe resource frees or unsupported changes to upstream preloads were made.
7. The first collision air ray crossed below the seeded chunk and hit generated ground at exactlyy0. Confining the ray to the intended chunk fixed the fixture without changing hit tolerances or claiming a native defect.
8. Parallel rendered/native execution confounded the first90-second baseline timeout. Serialized native checks passed. Keep these expensive runtime checks sequential.

Godot4.6 documents static script retention and an ineffective `@static_unload` annotation: https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/gdscript_basics.html#static-unload-annotation . A tiny local reproduction retained a script but did not reproduce the game shutdown errors; this is supporting engine context, not the diagnosed root cause.

## Review, cost and remaining work

Independent read-only review cleared the production combat contracts and identified two tooling issues (silent fixture skipping and shader-deadline coverage), plus unsafe native timeout destruction. Each was corrected; no reviewer modified source. Reused the compiled native baseline, matching tools, existing persistence fixtures and known Graphify failure instead of rebuilding or reinstalling for orientation.

The largest avoidable cost was discovering harness timing/clock assumptions through rendered runs. Future changes should use the retained small checks first, preserve exact progress/error markers, and run one expensive fixture only for a distinguishing question.

Remaining local scope: resolve the inherited rendered shutdown/build gate; authenticated sender-bound Steam identity and durable LAN identity; independent exploration/dimensions/visits and persistence barriers; host-validated transactional21-slot personal chest; save/rejoin, soak/rollback and final review. Two-account Steam invite/reconnect testing is externally unavailable; the user explicitly asked to finish local work first. No push, PR, release, install, driver change or unapproved engine download occurred.

Final latest-source baseline verification c2e277a7048341beaf6a6a0459b93b6f passed28/43/62 pluscollision3 after timeout safety correction. No owned runtime remains. Current strict rendered gate/decision boundary is documented in crash-diagnosis.md; it has not been relaxed.
