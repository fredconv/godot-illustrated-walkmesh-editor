# Release checklist for `0.1.0-alpha.1` and `0.1.0-alpha.2`

State on 2026-10-30: `0.1.0-alpha.1` is published (tag `v0.1.0-alpha.1`, left as it is). A defect found afterwards changed the addon, so `0.1.0-alpha.2` is prepared in the follow-up pull request (see "Release `0.1.0-alpha.2`" at the bottom). The addon-only package was tested in an empty project for both. Items that were not performed stay unticked and say why.

## Before the release (owner decisions)

- [x] Scope decided by the owner on 2026-10-29: layers and foreground occlusion are part of the first release.
- [x] UI direction decided by the owner on 2026-10-29: two tabs, Creation and Test, with foldable sections.
- [x] On 2026-10-30 the owner replaced the earlier restrictions with an instruction to finish, merge the pull request into its target branch and publish what the project plans to publish (the release with the addon ZIP). The owner is the one who accepts the limits listed in "Remaining limits" below.

## Manual QA with a mouse (M12)

Run on 2026-10-30 in the real Godot 4.7.1 editor, with real mouse and keyboard events sent by Windows MCP (clicks, drags, typing in the real file dialogs) and the editor state read back through Godot MCP. An item is ticked only when that interaction was actually performed; the evidence is in "M12 results" below. Items left open were not performed. Legend: `[x]` performed, `[~]` partly performed (the sentence says what was not), `[ ]` not performed.

- [x] Draw polygons with the mouse (two regions, a cutout); drag a vertex; undo with the Undo button. Spin box arrows: three clicks on the position arrow, then one Undo gave back the starting value (merged undo steps confirmed). Second pass (same day): a region deleted with the Delete button, a vertex selected with the mouse and removed with Remove selected point, each undone with Undo.
- [~] Done with the mouse: a cutout, two zones sharing a full edge, and a zone drawn over another zone (the overlap was detected). Not performed: a zone touching half an edge (covered headless).
- [~] Save into a project folder and reopen with New then Open: regions, cutout, templates, the picture and the layer picture came back, document clean. Not performed: moving the folder (covered headless).
- [x] Save As into two new folders. The first run found a bug (pictures of layers were not copied), fixed; the second run copied both the illustration and the layer picture.
- [x] Replace the picture: a file of another size (800x600) opened the confirmation dialog with both sizes; Cancel changed nothing; Replace swapped it; Undo restored 1672x941. A file of the same size is swapped without a question (by design).
- [~] Fit camera clicked: residuals shown (-82.6% / -38.1% before the fit, -9.1% / +9.1% after, with the warning), status line updated. Not performed: changing the field of view, reading the horizon line (it is above the picture in this scene).
- [~] Test walk on; click-to-move in the preview (two destinations); x10 button; Pause (the character stayed put, the button read Resume), Resume (it walked on), Reset position (back at its start). Second pass: the x2, x5 and x1 buttons (effective speed 4.5, 11.3 and then 4.0 after typing a base speed of 4) and the base speed field. Not performed: the presets during a walk, arrow keys while editing.
- [~] Perspective export from the real dialog, twice. First run: 14.8 MB with the pictures embedded (bug, fixed). After the fix: 115 KB, both pictures referenced, no warning. The exported scene with a player was run from the editor, and click-to-move was sent into the running game. Second pass: 2D export (3.2 KB, three navigation regions, the pictures node) and 3D export (7.7 KB, three navigation regions) from the real dialog; a path typed for a folder that did not exist yet exposed a defect (fixed). Not performed: a zone above the horizon.
- [~] Plugin unloaded with a modified document (disable then enable): a recovery copy was written, with its warning in the Output panel, and it loaded with the two groups, two regions and the picture. Third pass (below): the quit dialog was driven in a separate, isolated editor.
- [~] Dock resized by dragging the splitter to about 590 px and about 375 px, in perspective mode: see "Narrow dock" in the results. Second pass: the Window button opened the floating illustration window and its close button gave the canvas back to the dock. Third pass: the dock tab's context menu offers Make Floating, but it is disabled while the editor setting Single Window Mode is on (Godot's own message: "Multi-window support is not available because Interface > Editor > Single Window Mode is enabled in the editor settings"). The setting is global to the owner's editor, so it was not changed and the dock itself was not undocked.
- [x] Open a file saved with version 3: with unsaved changes the Save / Cancel / Discard Changes question came first (Discard chosen), then the status line said "saved with format version 3, but this plugin only understands up to version 2... The file was not changed"; the open document stayed as it was and the file's checksum was identical before and after.
- [~] Merge with… menu clicked, "Region 1" chosen: merged into one polygon, then Undo gave both regions back. Second pass: a merge of two regions that do not touch was refused with its message, a real merge was done, then Undo and Redo through the toolbar buttons.
- [~] Add image… with the real file dialog (foreground_template.png), ground point typed (815, 590), layer hidden then shown, layer opacity 0.4 then 1, layer locked (the picture fields were disabled and a typed position was refused). Second pass: the Drawn selector (Behind, then In front; two Undo clicks returned to By depth).
- [ ] Layers: change the position and scale fields with the spin box arrows and with typing; check that a run of arrow clicks undoes in one step.
- [x] In the editor preview: click-to-move behind the fountain, the character disappeared (depth 14.9 against 9.3 for the picture). In the exported scene running from the editor: a click behind the fountain hid the character (depth 13.8 against 9.3), a click in front showed it in front of the fountain ring.
- [~] Tabs switched with the mouse several times; the Layers section folded and unfolded with its header. Second pass: Layers and pictures folded with its header while the rest of the dock re-flowed. Not performed: the other sections, undocking the dock.
- [x] At about 375 px in perspective mode every control was reachable: the toolbar wraps on three rows, the tabs and sections are complete, the preview shrinks to fit. The first run found the preview forcing the dock to 1152 px (bug, fixed). The preview is small at this width (about 110 px).

## M12 results (2026-10-30)

Method: Windows MCP for clicks, drags, scrolling and typing into the real dialogs (Windows `ControlStatus` was `ready` before each batch); Godot MCP `execute_editor_script` to read the dock state back (never to change the document; it only disabled and enabled the plugin and asked the editor to scan files); Godot MCP `play_scene`, `simulate_mouse_click`, `get_game_screenshot` and `execute_game_script` for the exported game.

| # | What happened | Result |
|---|---|---|
| 1 | The editor still showed the old dock (single sidebar): it had loaded the plugin before the latest changes. Scanning the filesystem then disabling and enabling the plugin loaded the current dock. | Plugin reload works. Note for users: restart or reload the plugin after updating it. |
| 2 | The name dialog (New group) ignored the Enter key; only OK confirmed. | **Bug, fixed**: Enter confirms. Verified again in the editor (group "Rivière" created with Enter). Regression test added. |
| 3 | The position field of a picture on a locked layer kept the rejected value (50) while the picture stayed at 0. | **Bug, fixed**: the panel is put back on the real values. Regression test added. |
| 4 | Turning Perspective on made the dock about 1152 px wide: the toolbar and the sidebar were pushed out of view, the preview was cropped (in a 590 px dock). | **Bug, fixed**: the preview sits in a plain holder that reports a small minimum size. Re-checked at 620 px and 375 px. Regression test added (it fails without the fix: 1604 px against 310 px). |
| 5 | The first perspective export was 14.8 MB: both pictures were embedded because the editor did not know the files the save had just copied. | **Bug, fixed**: the export asks for a scan and waits for it. Re-checked: 115 KB, two references. Regression test added for the Save As case below. |
| 6 | Save As into a new folder kept `assets/elements/...` as the picture path but did not copy the file, so the new folder had no picture (and the export warned "its picture could not be loaded"). | **Bug, fixed**. Re-checked with Save As and an export. Regression test added. |
| 7 | Plugin disabled with unsaved changes: a recovery copy was written in `user://iwe_recovery/`, with a warning, and it loaded completely. | Works as designed. The document is not restored automatically. |
| 9 | After deleting Region 1, the next new region was named Region 4 while Region 4 already existed. Same logic for templates, layers and groups. | **Bug, fixed**: the next free number is used. Regression test added. |
| 10 | An export typed into a folder that did not exist wrote nothing and the dock said nothing (the Output panel had the error). | **Bug, fixed**: the folder is created and a failure is shown in the dock status. Regression tests added. |
| 8 | Template placement: with a template selected, a click in "Place / move height template" mode moves it instead of placing a new one, and the height field edits the selected template. | Existing behaviour (the user guide says to set the height after placing). Confusing; not changed. |

Evidence kept out of the repository (large screenshots of the dock and of the running game): they show the dock tabs, the folded section, the narrow layout, the fountain hiding and showing the character. No unrelated window was recorded, except that one Windows MCP window list taken at the start of the session also listed the titles and content of other applications; none of it is kept.

## Third pass (2026-10-30): isolated editor

The owner's own editor was never touched. A separate editor was started on a temporary copy of the project (the addon, the village example and its pictures), its window was moved to a third display with `SetWindowPos`, and Windows MCP clicks and typing went only into that window (`ControlStatus` was `ai` before each batch; when it read `user` the work waited). Screenshots were limited to that window's region, except one full-screen capture taken before the window was moved, which was discarded. The temporary project was deleted afterwards.

- **Real quit dialog, performed.** The village example was opened through the plugin's real `Open` file dialog (4 regions, 2 cutouts, the foreground picture, document clean). `Duplicate region` made it `village *`. A click on the editor window's close button showed Godot's dialog: "Please Confirm... IWE document "village" has unsaved changes." with `Save & Quit`, `Cancel` and `Don't Save`. `Cancel` kept the editor open, the document modified and the file untouched. A second close and `Save & Quit` wrote `village.tres` in place (it then contained "Region 3 Copy"; modification time changed) and the editor exited. `Don't Save` and the never-saved document (recovery copy) were not clicked in the GUI; the recovery path was observed when an editor ended with a modified document (a recovery copy was written for both a never-saved and a saved-with-changes document, and the saved file stayed untouched), and both paths are covered by `test_unsaved_changes`.
- **Deleting a region and undoing it, performed after a defect was found and fixed.** Reading the code showed that Undo of a deletion put the region back at the end of the list, which changes which zone keeps shared ground and the export order. Fixed (`_insert_region` at its old index) with `test_region_order` (it fails without the fix). In the real editor: `Region 1` deleted, Undo, `Region 1` first again; after Save & Quit the saved order was Region 1, 2, 3, 4, 3 Copy.
- **Undocking the dock: not possible in this configuration** (see the dock item above).
- **Not performed by hand** (covered headless only): a zone touching half an edge, changing the field of view, a zone above the horizon at export, arrow keys while editing, the speed presets during a walk, the other foldable sections.

## Base scope for `0.1.0-alpha.3` (2026-10-30): what was proven and how

The owner asked for the base scope to be implemented, integrated, tested and documented before any stable release: scene transitions with entry points, an external character, the whole-interface window, a clearer interface, speed checks. `[x]` means performed, `[~]` partly, `[ ]` not performed. The evidence column says which kind of check it is: **real editor** (mouse and keyboard sent with Windows MCP into a separate, isolated Godot editor window on a temporary project, moved to another display, never the owner's editor), **real game** (the game window of that editor), **real GPU** (`tests/render_check`), **headless** (GdUnit4 or the editor runtime without a window), **code read**.

| | Item | Evidence |
|---|---|---|
| [x] | Draw an action zone with the mouse (four corners, then the first corner), see it listed, selected and highlighted | **Real editor** |
| [x] | Set its scene and entry point by typing; the list line reads `Zone 1: level_cellar.tscn at from_village` | **Real editor** |
| [x] | Place an entry point with a click; the first one is the default; name, default and direction fields appear | **Real editor** |
| [x] | The section title shows counts that stay visible when folded (`0 zones, 0 entries`, then `1 zone, 0 entries`); the status line explains the active tool; tooltips on the controls | **Real editor** and headless (every control of the dock is checked for a tooltip) |
| [x] | The `Window` button detaches the whole interface into a window titled `IWE - Illustrated Walkmesh Editor`; the Open dialog opened from it appears in that window; the document opened there | **Real editor** |
| [x] | `Dock` brings it back with the same state: `village *`, Undo enabled, zoom 83%, same tab and scroll, same lists, the entry-point tool still active | **Real editor** (and headless, field by field, in `test_interface_window`) |
| [x] | Save writes format version 3 with the zone, its scene and the entry point; New then Open brings them back, the document clean | **Real editor**, then the file read from disk |
| [x] | The village example (format version 2, published with alpha.2) opens in this version | **Real editor** |
| [x] | Run the integration example (`level_village.tscn`, F6), click in the game window with the external character, `PageUp` three times (x10): the character walks into the door zone, the cellar loads, the character appears at its entry point | **Real game** |
| [x] | Click the stairs zone in the cellar: the village loads again and the character is in front of the house door at `from_cellar` | **Real game** |
| [x] | The same trip with real `change_scene_to_file` between the two level files, the external character walking by its own controller | Headless (`test_external_character_integration`) |
| [x] | An external character is hidden behind the fountain at three depths (0 pixels) and shown in front of it at three depths (18,495 pixels) | **Real GPU** (`tests/render_check`) |
| [x] | Apparent size at the near and far references and in between, and depth order at four spots behind and four in front, for a character that is not the plugin's | Headless |
| [x] | Navigation by an external controller: across zones, round the fountain, an unreachable target ends on the nearest walkable point, the walls hold | Headless, with real physics |
| [x] | Speed: `PageUp` / `PageDown` / `Home` on the exported test player, changed in the middle of a walk (x5 gives about five times the step); the multiplier is in no saved scene | Headless; the keys were also pressed in the **real game**, where the walk visibly sped up (the speed was not measured there) |
| [x] | Speed in the dock (x1, x2, x5, x10, pause, reset, base speed) acts on the editor preview only and applies while walking | Headless (`test_preview_walk`, `test_preview_speed`); presets were pressed in the **real editor** in the second M12 pass |
| [x] | Migration: a real version 1 file and the version 2 example published with alpha.2 open, keep every part, and are byte-identical on disk after being opened | Headless |
| [x] | Double trigger, refused travel, missing scene, broken scene file, missing entry point, no entry marker, warp, unknown action | Headless |
| [x] | The addon-only package (58 files) enables in an empty project and runs import, regions, a zone, an entry point, a layer picture, save, reopen and the three exports | **Real editor runtime** (headless editor), `tests/release_check` |
| [~] | Moving an action zone and an entry point by dragging, deleting them with Delete, undoing | Headless (events sent to the canvas); **not** performed by hand |
| [~] | Dock narrow width with the new section | Seen at about 390 px in the real editor (the section fits; the fields and the hints wrap); not checked at other widths |
| [ ] | Game embedded in the editor's Game tab | Not possible: Godot says "Game embedding not available in single window mode" |
| [ ] | Undocking the dock tab itself | Disabled by Godot's Single Window Mode (see above); the `Window` button is the supported way |
| [ ] | A rigged and animated character | Not available: the example is a lit capsule model. It proves size, depth and navigation, not skeletal animation |
| [ ] | Real-editor check of an unknown action, of `warp`, of the 2D export with zones | Covered headless only |

Two findings of this pass, both fixed: the example controller shuttled around a waypoint at x10 (steps longer than the distance left), and my first example put the door where the test scenario's bridge is, over the pond of the illustration; the door now stands at the house door.

## Remaining limits (accepted for an alpha)

- A picture occludes at one depth (its ground point).
- A doorway narrower than the character is reported at export but cannot be crossed.
- The shape of an action zone cannot be edited vertex by vertex. Interactions that need a button press and conditions are not built in (the action is an open string and the game can handle its own).
- A character with a body stalls on obstacle corners unless its path keeps clear of walls (`IWENavigationPath` does that) and it counts waypoints as reached within about its radius; a corridor narrower than the body cannot be crossed.
- An exported stage needs the plugin's `runtime/` scripts at run time.
- Layer pictures are prepared beforehand in V1 (same canvas as the background, transparent pixels around the object); moving and resizing them with the mouse is V2 by the owner's decision of 2026-10-30. The numeric fields remain. There is no region lock button or properties block.
- The preview is small in a dock narrower than about 400 px.
- Godot's Single Window Mode (an editor setting) disables Make Floating, so the dock cannot be undocked while it is on. The quit dialog was driven in the real editor (Cancel and Save & Quit); Don't Save and the never-saved document were not clicked.
- Region types, explicit connections, structural clean-up (M6, M11) and triggers are not in this release.

## Checked without a mouse

Done in this work and reproducible, but not a substitute for the list above:

- 392 headless GdUnit4 tests, including dock operations driven through the same signals the canvas emits.
- `tests/editor_selftest/run.ps1`: the dock and the test walk inside the real Godot editor runtime (headless editor).
- `tests/render_check/run.ps1`: a real GPU render of the village stage. The character is hidden behind the foreground fountain (1 matching pixel) and shown in front of it (2,725 pixels).
- A real render of the dock itself in a window, read by eye: the two tabs, the foldable sections, the layer panel, the speed controls. No click was made.

These were the only checks available before M12, when the Godot MCP and Windows MCP tools were not yet reachable from the session. M12 above is the first real-editor interaction.

## Preparation (M13)

- [x] `version` in `addons/illustrated_walkmesh_editor/plugin.cfg` is `0.1.0-alpha.1`; the changelog's entries are under that version and date.
- [x] Addon-only ZIP built with `git archive` (the addon folder, 38 files, and the licence). `tests/release_check/run.ps1` unpacks it into an empty project with nothing else, enables the plugin in the real editor (headless), then imports a picture, draws two regions, adds a layer picture, saves, reopens and exports 2D, 3D and perspective scenes: no editor error, 0 failures. This found one source of noisy errors (a reimport of a file the editor had not listed), fixed.
- [x] `examples/village/`: a finished document (four zones, two cutouts, two height references, the fountain on the foreground layer) with its pictures, a README and the script that rebuilds it. A test (`test_village_example`) opens it. It is not inside the addon ZIP, which holds only the addon.
- [x] Every shipped image is one of the three in `assets/img/` (copied into `examples/village/assets/`). `assets/README.md` records them as illustrations created or modified by the project owner, with permission to use and redistribute them confirmed by the owner on 2026-10-30. No image is inside the addon ZIP.
- [ ] New README screenshots were not made: a rendering of the two dock tabs was started and not run (the command was declined). The README keeps `assets/screenshots/perspective_demo.png`.
- [~] README status, known limits and install text were rewritten against the checklist; stale lines of `ROADMAP.md` and `DATA_FORMAT.md` fixed. The user guide was read through the workflow section and matched; it was not re-read line by line.
- [x] CI green on the branch before the merge (headless suite, 302 tests).

## Release

- [x] Pull request 1 merged into `develop` (merge commit `6b1331c`, 2026-10-30), CI green on `develop`. `main` is not touched by this.
- [x] Tag `v0.1.0-alpha.1` on the merge commit and GitHub pre-release published with `illustrated_walkmesh_editor-0.1.0-alpha.1.zip` (77,428 bytes). The repository has no other publication target (no Asset Library entry, no release workflow). The release and its tag are not replaced by later work: a corrected package gets a new alpha number.

## Release `0.1.0-alpha.2`

Why a new number: Undo of a region deletion put the region back at the end of the list (fixed in `iwe_dock.gd`), so the published addon changed. `v0.1.0-alpha.1` and its release are not replaced.

- [x] `plugin.cfg` version `0.1.0-alpha.2`; changelog entry under that version.
- [x] Follow-up branch `chore/post-alpha-finalization` and a pull request into `develop`; no direct push to a protected branch.
- [x] Full headless suite and the packaged-addon smoke test (`tests/release_check/run.ps1`) pass on the branch (numbers in the pull request).
- [x] CI green on the pull request before the merge.
- [ ] Merge, tag `v0.1.0-alpha.2`, GitHub pre-release with `illustrated_walkmesh_editor-0.1.0-alpha.2.zip` (see the final report for what was done).
