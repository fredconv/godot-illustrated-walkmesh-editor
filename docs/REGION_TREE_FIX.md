# Region tree crash: technical report

Status: fixed in commit `ba15c30` on `feature/region-editing`. Verified headless (local and GitHub Actions). Written as a reference for a later architecture review. It does not propose further refactoring.

## 1. Cause

Selecting a **cutout** in the region tree crashed the engine with:

```
ERROR: FATAL: Index p_index = 0 is out of bounds (((Vector<T> *)(this))->_cowdata.size() = 0).
```

The chain of calls, all on the same stack:

1. `TreeItem.select(0)` on a cutout item emits `Tree.item_selected`.
2. `IWEDock._region_item_selected` (connected to `item_selected`) runs.
3. It calls `_sync_selection(region_id)`, which calls `_refresh_regions(region_id)`.
4. `_refresh_regions` calls `IWERegionList.refresh(...)`, which calls `clear()` and rebuilds every item.
5. `clear()` frees the `TreeItem` that is still executing `select()`. Its cell storage is gone, so the engine reads an index from an empty array and aborts.

Any selection change caused this, not only cutouts. Cutouts failed because the test (and sometimes the user) selects the item the rebuild destroys first.

**Reproduction.** On the code before the fix, the new test suite crashed in 3 of 3 runs, always in `test_selecting_a_cutout_selects_that_cutout` at the line `cutout.select(0)`. The region test in the same suite passed, which matches the cause: a region item has no child cell to index.

## 2. Functions and signals involved

| Element | Role in the crash |
|---|---|
| `Tree.item_selected` | Emitted synchronously from `TreeItem.select()`. Connected to `_region_item_selected`. |
| `Tree.item_activated` | Same pattern (double click). Connected to `_tree_item_activated`. |
| `IWEDock._region_item_selected` | Reads the selection, then calls `_sync_selection`. |
| `IWEDock._sync_selection` | Calls `_refresh_regions`, then updates buttons. |
| `IWEDock._refresh_regions` | Calls `IWERegionList.refresh` on every selection. |
| `IWERegionList.refresh` | Calls `clear()`, which frees the items during the callback. |

## 3. Solution retained

Two changes, applied together:

1. **Selection does not rebuild the tree.** `IWERegionList` keeps a signature of its structure: group ids and names, region ids, group, names, visibility, and cutout names. `refresh` compares it with the previous one. If it is unchanged, it only moves the selection to the matching item (`_select_matching`, `_find_item`). Only a structural change rebuilds the tree, and that is what the code did before.
2. **Interaction signals are deferred.** `item_selected` and `item_activated` are connected with `CONNECT_DEFERRED`. Any handler that does rebuild runs after the callback has returned, not inside it.

Behaviour is unchanged for the user: the same item is selected, the same cutout index is kept, and the same region stays selected when a cutout no longer exists.

### Alternatives considered

| Option | Why it was not chosen alone |
|---|---|
| Deferred connection only | Prevents this crash, but every selection still destroys and recreates every item. It is slower, causes visible flicker on long lists, and leaves the tree dependent on the timing of every future callback. |
| Never rebuild on selection, without a signature | Equivalent in effect, but nothing detects when a rebuild is really needed, so a stale tree could appear after a structural change. The signature makes that check explicit. |
| Block signals in the dock during refresh | Does not help. The problem is the callback running while its own items are freed, not the signal being emitted during the refresh. |
| Reuse `TreeItem`s instead of `clear()` | Correct, but a larger change to the list than this fix needs. Kept as a possible later refactor. |

## 4. Regression tests

File: `tests/test_region_tree_selection.gd` (6 cases).

| Case | What it checks |
|---|---|
| `test_selecting_a_region_updates_the_dock_without_freeing_the_item` | Selecting a region updates the canvas selection and the tree metadata. |
| `test_selecting_a_cutout_selects_that_cutout` | Selecting a cutout keeps its index in the dock state. This is the case that crashed. |
| `test_rapid_selection_changes_never_leave_a_dangling_item` | 120 selections in a row across regions and cutouts, with no wait between them, then a final check that the last selection is the one active. |
| `test_tree_is_rebuilt_when_regions_change` | A structural change rebuilds the tree, and the new region appears. |
| `test_no_dangling_references_after_a_region_is_removed` | After removing a region, no item or canvas selection refers to it, and the remaining regions can still be selected. |
| `test_selected_item_stays_consistent_after_a_structural_refresh` | Renaming a region (a structural change) keeps the selected cutout by its index. |

The existing `test_dock_requires_image_and_group_then_creates_polygon` also exercises cutout selection and still passes.

## 5. Verification

| Check | Result |
|---|---|
| New suite on the code before the fix | Crashed 3 of 3 runs (native abort) |
| New suite on the fixed code | Passed 10 of 10 consecutive runs |
| Full suite on the fixed code | 35 of 35, five consecutive headless runs, no fatal error |
| Plugin boot in the editor | No IWE script errors. The boot log still shows errors from the Phantom Camera icons and the scene UID in the local, uncommitted project settings. |
| GitHub Actions on `ba15c30` | Success, 35 of 35 |

**What these checks do not prove.** Ten runs and five runs show the crash does not reproduce on this machine and on the runner. They do not prove the absence of every possible re-entrance crash. The Godot engine is not formally verified, and the crash appeared intermittently before the regression test existed. The honest statement is: the known path is covered by a deterministic test, and the other callbacks listed in section 6 have not been tested under stress.

## 6. Remaining re-entrance risks

These paths follow the same pattern (a callback can rebuild UI that is still running) and were reviewed but not fixed:

- **`IWEDock._tree_item_activated(item)`** receives a `TreeItem` argument. It is deferred, so the item could be freed if a rebuild happened between the signal and the call. Selection events cannot change the structure, so this only happens if a rename or delete is queued in the same frame. Low risk, but not guaranteed.
- **`OptionButton` (group list)** calls `_group_selected` synchronously. It calls `_refresh_regions`, which rebuilds the tree, not the option list. Safe today, but a future change that rebuilds the option items inside this handler would reintroduce the same class of crash.
- **Canvas signals** (`region_selected`, `selection_changed`) run from the canvas input handler, not from the tree. They call `_refresh_regions`, which can rebuild the tree. That is safe because no tree callback is running, but it relies on the same invariant.
- **Undo and redo** call `_refresh_regions` from `EditorUndoRedoManager` callbacks. These are not tree callbacks, but they run while the tree may hold a selection. They were not stress-tested.

## 7. Points for an architecture review

- **Three sources of truth for the selection.** The canvas (`_selected_id`, `_selected_vertex`), the dock (`_selected_cutout_region_id`, `_selected_cutout_index`, `_selected_group_id`), and the tree metadata. Each path writes to some of them, so a mismatch is possible. This report only guarantees they agree after the paths tested here.
- **`IWEDock` is about 1,400 lines** and owns UI, document mutation, export, calibration, and undo wiring. Re-entrance is hard to reason about in a class this size.
- **Callback discipline is manual.** The deferred connection works only because each handler is written to tolerate running later. Nothing enforces that for new handlers.
- **Tests use private members** (`_region_list`, `_canvas`, `_selected_cutout_index`, `_region_item_selected`). They are reliable for now, but they tie the tests to the internal structure. A public selection API would be a better boundary.
- **Full rebuild as the update strategy.** `refresh` clears and recreates the tree whenever the structure changes. This is simple and correct, but it is the reason any callback that triggers a structural change must be deferred.
- **Headless coverage of the editor is partial.** The tests drive the dock through its methods and signals. They do not cover real mouse input in the editor, which is the path most likely to expose a new re-entrance issue. A manual check after any change to the tree is still required.
