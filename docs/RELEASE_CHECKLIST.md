# Release checklist for `0.1.0-alpha.1`

State on 2026-10-30: the version is `0.1.0-alpha.1`, the addon-only package was tested in an empty project, and the release steps at the bottom are done in the order listed there. Items that were not performed stay unticked and say why.

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
- [~] Plugin unloaded with a modified document (disable then enable): a recovery copy was written, with its warning in the Output panel, and it loaded with the two groups, two regions and the picture. Not performed: closing Godot (the quit dialog): the permission layer of the session refused a click on the editor's close button as interference with the user's running work, and that was respected. This item needs a human.
- [~] Dock resized by dragging the splitter to about 590 px and about 375 px, in perspective mode: see "Narrow dock" in the results. Second pass: the Window button opened the floating illustration window and its close button gave the canvas back to the dock. Not performed: undocking the dock itself.
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

## Third pass (2026-10-30): what was not repeated and why

The owner was using the machine (Windows MCP `ControlStatus` read `user`), so no window was clicked in this pass. The items still marked `[~]` or `[ ]` above stay as they are:

- Closing Godot with a modified document, and undocking the dock itself, need a person (the first was refused by the permission layer, the second was not tried).
- A zone touching half an edge, changing the field of view, and a zone above the horizon at export are covered by headless tests (`test_walkable_connections`, `test_perspective_*`, `test_export_warnings`, `test_fit_report`), not by hand.
- Arrow keys while editing and the speed presets during a walk were not tried by hand. The presets during a walk are covered headless (`test_preview_walk`).

## Remaining limits (accepted for an alpha)

- A picture occludes at one depth (its ground point).
- A doorway narrower than the character is reported at export but cannot be crossed.
- Pictures are positioned by typing; there is no region lock button or properties block.
- The preview is small in a dock narrower than about 400 px.
- Closing Godot with a modified document was never driven by hand.
- Region types, explicit connections, structural clean-up (M6, M11) and triggers are not in this release.

## Checked without a mouse

Done in this work and reproducible, but not a substitute for the list above:

- 302 headless GdUnit4 tests, including dock operations driven through the same signals the canvas emits.
- `tests/editor_selftest/run.ps1`: the dock and the test walk inside the real Godot editor runtime (headless editor).
- `tests/render_check/run.ps1`: a real GPU render of the village stage. The character is hidden behind the foreground fountain (1 matching pixel) and shown in front of it (2,725 pixels).
- A real render of the dock itself in a window, read by eye: the two tabs, the foldable sections, the layer panel, the speed controls. No click was made.

These were the only checks available before M12, when the Godot MCP and Windows MCP tools were not yet reachable from the session. M12 above is the first real-editor interaction.

## Preparation (M13)

- [x] `version` in `addons/illustrated_walkmesh_editor/plugin.cfg` is `0.1.0-alpha.1`; the changelog's entries are under that version and date.
- [x] Addon-only ZIP built with `git archive` (the addon folder, 38 files, and the licence). `tests/release_check/run.ps1` unpacks it into an empty project with nothing else, enables the plugin in the real editor (headless), then imports a picture, draws two regions, adds a layer picture, saves, reopens and exports 2D, 3D and perspective scenes: no editor error, 0 failures. This found one source of noisy errors (a reimport of a file the editor had not listed), fixed.
- [x] `examples/village/`: a finished document (four zones, two cutouts, two height references, the fountain on the foreground layer) with its pictures, a README and the script that rebuilds it. A test (`test_village_example`) opens it. It is not inside the addon ZIP, which holds only the addon.
- [~] Every shipped image is one of the three in `assets/img/` (copied into `examples/village/assets/`), recorded in `assets/README.md` as generated with AI tools by the author and free to use. That is the author's own statement; the wording does not name a licence, so the owner may want to state one. No image is inside the addon ZIP.
- [ ] New README screenshots were not made: a rendering of the two dock tabs was started and not run (the command was declined). The README keeps `assets/screenshots/perspective_demo.png`.
- [~] README status, known limits and install text were rewritten against the checklist; stale lines of `ROADMAP.md` and `DATA_FORMAT.md` fixed. The user guide was read through the workflow section and matched; it was not re-read line by line.
- [x] CI green on the branch before the merge (headless suite, 302 tests).

## Release

- [ ] Merge pull request 1 into `develop`, its target branch. `main` is not touched by this.
- [ ] Tag `v0.1.0-alpha.1` on the merge commit and publish a GitHub pre-release with `illustrated_walkmesh_editor-0.1.0-alpha.1.zip`. The repository has no other publication target (no Asset Library entry, no release workflow).
