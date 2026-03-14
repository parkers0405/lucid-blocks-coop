# Native Multi-Region Plan

Current DLL target:

- file: `libgdblocks.windows.template_release.double.x86_64.dll`
- sha256: `0cd2462526d7ba7eb99f218bf591747b7886131d7eba2fd97a792688ce78266d`
- GDExtension entry: `gdblocks_init`

Confirmed native loader chain:

- `LucidBlocksWorld._physics_process()` calls `set_loaded_region_center(...)` every physics tick.
- Native `World::set_loaded_region_center(Vector3)` snaps to one `center_chunk` and only then calls `update_loaded_region()`.
- Native `World::update_loaded_region()` assumes one center for:
  - decoration eviction
  - structure eviction
  - decoration initialization
  - structure initialization
  - chunk allocation / unload
  - `all_loaded`
  - water / fire simulation loops via `center_chunk`

Key field layout confirmed from owner-shared source and DLL:

- `center_chunk`: current `World` center chunk
- `all_loaded`: single-region completion flag
- `all_chunks`: pooled chunk node instances
- `is_chunk_loaded`: per-coordinate loading state
- `chunk_map`: coordinate -> chunk map
- `decoration_generated`, `structure_map`, `chunk_data`, `chunk_water_data`, `chunk_fire_data`
- `init_queue`, `init_queue_positions`, `task_id`, `has_task`

Observed binary anchors for this DLL hash:

- `World_set_loaded_region_center`: `0x18005c3b0`
- center/all_loaded update block inside it: around `0x18005d0e8`
- `World_update_loaded_region`: `0x18005e610`

Source-level rewrite target:

1. Replace single `center_chunk` logic with a collection of active center chunks.
2. Add helpers such as:
   - `set_loaded_region_centers(...)`
   - `is_chunk_in_any_radius(...)`
   - `is_chunk_in_radius_of(center, coordinate, radius)`
3. Build the desired loaded chunk set as the union of all player bubbles.
4. Only unload chunks that are outside every bubble.
5. Change decoration and structure eviction to keep anything near any bubble.
6. Change `all_loaded` to mean all required chunks across all active bubbles are ready.
7. Update `simulate_dynamic()` to process water/fire near any active bubble, not only `center_chunk`.
8. Increase or dynamically grow the `all_chunks` pool so disjoint bubbles do not run out of chunk instances.

Important native constraints from the shared source:

- `set_instance_radius()` clamps to `48..96`, so script-side attempts to push much larger radii are not a real long-term answer.
- `instantiate_chunks()` only preallocates a pool for a single `max_render_distance = 96` bubble.
- `is_chunk_in_radius()` is currently just distance from one `center_chunk`.

Current mod-side prep already added:

- `mod/overrides/main/world/world.gd` now checks for a future native `set_loaded_region_centers(...)` API and will call it when available.
- Until the native DLL changes, the game falls back to the existing single-center behavior.

Recommended next native patch shape:

- Preferred: source-level patch to `World` with a new `set_loaded_region_centers(...)` method and union-loader logic.
- Acceptable fallback: binary hook only if source rebuild is impossible.
- Avoid: frame-cycling one center across players; it will churn loading and tank frame pacing.
