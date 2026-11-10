# Vulkan crash diagnosis — 2026-10-24

Read-only investigation; no runtime retry, source repair, driver change or installation.

## Evidence
- Windows Application event 1000, report bedb68c3-4ebb-4fed-b08f-f4bf95174a61, identifies the exact executable under work/build-logs/8164c667753a454287093ce0b4ee3655/runtime/godot.exe.
- Faulting module: igvk64.dll version 32.0.101.7088, offset 0x14d102; exception 0xc0000005. The fault is in Intel's Vulkan driver, not a reported GDScript exception. This does not establish the originating defect.
- runtime.stdout.log identifies Forward+/Vulkan on Intel Iris Xe; large Gel center coverage 25/25, followed by COMBAT_SCENE. No mini visibility or COMBAT_RESULT marker.
- Last stdout: original shader baker loads Agate and enables Blood GPUParticles3D. Temporal correlation only; no stack or dump identifies the triggering call.
- Private reference work/recovered/main/main.gd:99-110 starts shader baking after world startup and transitions. tests/combat.gd starts after only two process frames through the generated build probe. Both asynchronous flows can advance together.
- Private shader_loader.gd:37-49 loads every cached scene with frame_post_draw awaits. Lines 113-123 reparent GPU particles and enable emission; it also enables SDFGI. The fixture is therefore not isolated from original background rendering.
- Windows event access was initially denied in the sandbox; approved read-only escalation succeeded. Graphify has no existing graph and its launcher fails with uv trampoline failed to canonicalize script path; direct rg/source inspection used.

## Reassessed strategy, pending one renewed bounded cycle
1. Change only the generated CombatTests probe in scripts/build_raw_mod.ps1: before Main's startup decision, set save_version to the current version and shaders_baked=true on the disposable in-memory device file. Assert this setup and require the original `Shader baking skipped.` log; reject any `Baking shaders...` log. Do not modify production scripts, original assets, driver settings, personal profiles or persistent shader flags. Confirm initialization order before implementing this choice.
2. Keep Forward+/Vulkan, actual original Gel/mini scenes, materials, physics and PNG visibility assertions. Run once with strict COMBAT_RESULT, startup count, log and exit gates. A pass proves this isolated fixture only; cold-start shader baking stays unresolved.
3. If native crash recurs, stop that cycle; inspect its matching Windows event/dump rather than increasing timeouts or changing renderer blindly. No driver install is authorized.
4. Separately probe the compiled native baseline headlessly in a disposable runtime, retaining original-library control and region/collision assertions before terrain edits. Compilation is not compatibility evidence. No automatic retry or DLL installation.

## Boundary
The prior one-cycle allowance is consumed. This continuation authorizes diagnosis and reassessment, not repeated rendered repair attempts. Minimum next user action: authorize one fixture-isolation edit and one rendered rerun. Safe implementation remains b395d39; uncommitted combat and unrelated .import edits preserved. Steam two-account verification and one-hour soak remain unavailable.
## Authorized isolated attempt outcome
Run14b04f39095e410ab16a6d5d57899ae2 failed the new strict gate. Original shader baking still ran and logged Jolt softbody errors; combat never began. This does not reproduce or disprove the prior Intel driver crash. Deferred two-frame setup was insufficient; next fixture repair should seed device state at SaveFileManager.ready before parent Main._ready. No further run under this consumed allowance.

## 2026-10-25: early-profile attempt failed
- Run work/build-logs/0fa99aa1a7c143c4b4428ad232e17b20 initialized Forward+/Vulkan. Observer filtered exact recovered SaveFileManager/ShaderLoader .gd resource paths; no seed/isolation/combat markers appeared. Original shader baking completed. Runtime then exceeded180seconds; launcher killed and waited for the exact owned process, exited1 and cleaned disposable runtime.
- PowerShell syntax and diff whitespace checks passed; these did not validate runtime callbacks. Packed .gdc remapping or lifecycle mismatch remains a hypothesis. No isolated rendering result or screenshot; no crash-equivalence claim.
- Failed approach: matching recovered script paths without first observing actual packed identities. Next diagnostic should record exact node/script identities and fail early when seeding is absent, before spending another rendered cycle. No further run under consumed allowance. Production source/assets, user saves and .import edits preserved; no installation or release.
## 2026-10-25: startup and shutdown are separate findings
- Diagnostic caff57dd1ff74fac8011780ae5a7f205 proved actual SaveFileManager/ShaderLoader .gd identities and ready ordering. Installing in _enter_tree plus snapshot resolved the missed setup callbacks; .gdc remapping was not the cause for these observed nodes.
- Full combat on exact shipped runtime3887012779a94d989849360065f9fb81 completes55/0 and both original actor25/25 renders, then fails strict shutdown errors77resources/Jolt3. Shader-isolated mod startup control e899c40a684c4b1db0ffb778c6c3238a reproduces77/Jolt3 without combat.
- Original shipped-runtime control eed084e7eb6a47048eb59aebd8ebd99c physically loads only the observer PCK, no co-op pack/overrides. It bypasses mod checks, ItemMap cache release and keyboard cleanup; seeds only the disposable device shader profile. It completes skip/isolation/control/OK0 and exits0, then reports509 resources/Jolt19 and renderer/font/page errors. This establishes shutdown error categories without co-op code. It is NOT untouched gameplay/cold shader baking, and differing counts do not prove the exact ownership cause.
- Independent review mapped leaked physics shapes to retained resource scenes, not surviving Gel/Heart Nodes. Godot4.6 docs warn about static script retention and ineffective @static_unload: https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/gdscript_basics.html#static-unload-annotation . The small static-lifetime fixture exited cleanly; no causal engine fix is established.

### Verification decision boundary (not applied)
The current strict gate remains unchanged: any ERROR or missing completion/result marker fails. No current rendered artifact qualifies. Continuing to certify the complete build requires either a source-supported remediation of the inherited shutdown failure, or an explicit decision to adopt a separate baseline-comparison contract. The latter would require documented original-runtime error categories, rejection of every pre-shutdown error/new category/incomplete marker/nonzero exit, and repeated-workload/soak evidence before interpreting stable exit-only resource retention. No such exception, whitelist or relaxed gate has been implemented or approved. Do not repeat the55-check rendered run unchanged to rediscover this block.
