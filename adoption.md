# Engine-layout adoption — 2026-10-24

Implementation paused at Tristan's request. Resume only after the user confirms adoption and explicitly authorizes resumption.

## Verified changes
- Project moved from GameDevelopment/lucid-blocks-coop-updated to GameDevelopment/Godot/Lucid Blocks, preserving its nested Git repository and feature branch. Do not recreate or reclone it.
- GameDevelopment is now a separate pipeline repository; game repositories are ignored by that parent. Keep game and pipeline commits separate.
- Engine-specific guide/playbook/kit folders replace _pipeline/engines. Shared templates/styles/design/metrics guidance now live under _shared.
- Start sessions from STATE.md, then current tasks and the engine guide. STATE is kept under about 60 lines; newest two playtest entries stay in full, older entries go to playtest-archive.md. metrics.md records supplied player metrics only.
- Current workflow validates that game_dir is directly inside the selected engine folder. Correct arguments: game_dir=C:/Work/Code/GameDevelopment/Godot/Lucid Blocks, engine=godot, mode=feature. Stages run directly in the current project.
- Keep project changes separate from shared workflow configuration.
- Public-fork exception is explicit in STATE.md. Do not create a new private repository or push main. Existing scoped authorization remains; PR/release needs separate authorization.

## Adoption decisions
- Keep the approved scope and global Sol/cost/progress preferences. New layout alone does not authorize restarting design, changing models, or adding features.
- Use relative paths and explicit project working directories. The old absolute project path is invalid. Historical ignored logs may retain it; preserve them as evidence rather than rewriting them.
- Scripts derive project locations from PSScriptRoot; source-path inspection found no old absolute path in current tracked Markdown/PowerShell entry points. The move has not yet been runtime-retested, because implementation is paused.
- Original commercial installation remains read-only. Keep original/recovered resources, tools, test profiles, logs and artifacts in ignored work; preserve the user's .import changes.
- Current headless pipeline is project-specific: Godot 4.6 double, original packed resources plus original DLLs, raw GDScript/remap PCK, and an unpublished startup probe. Generic guide commands do not replace this verified path.

## Handoff
Last pre-pause admission run passed 59 assertions plus 4 native guard assertions and 61 startup script checks. Evidence in STATE.md. Those code/tests are uncommitted; do not mark the overall mod complete. Remaining features include durable private saves, independent exploration/dimensions, Steam account checks, known-issue gameplay checks, personal storage, and soak/review.

No input is needed to repair paths or adopt these documents. User input is needed to confirm adoption and explicitly resume. Two authenticated Steam accounts will be needed later for genuine Steam invite/network verification; not needed for this documentation audit.
