# Release checklist for `0.1.0-alpha.1`

Nothing here has been done as a release step. The version is still `0.1.0-dev`, no tag exists and nothing is published. This list is what remains, in order.

## Before the release (owner decisions)

- [x] Scope decided by the owner on 2026-10-29: layers and foreground occlusion are part of the first release.
- [x] UI direction decided by the owner on 2026-10-29: two tabs, Creation and Test, with foldable sections.
- [ ] Final validation and the owner's explicit approval before any release step.

## Manual QA with a mouse (M12)

Run on 2026-10-30 in the real Godot 4.7.1 editor, with real mouse and keyboard events sent by Windows MCP (clicks, drags, typing in the real file dialogs) and the editor state read back through Godot MCP. An item is ticked only when that interaction was actually performed; the evidence is in "M12 results" below. Items left open were not performed. Legend: `[x]` performed, `[~]` partly performed (the sentence says what was not), `[ ]` not performed.

- [x] Draw polygons with the mouse (two regions, a cutout); drag a vertex; undo with the Undo button. Spin box arrows: three clicks on the position arrow, then one Undo gave back the starting value (merged undo steps confirmed). Not performed: deleting a polygon or a vertex with the mouse.
- [~] Done with the mouse: a cutout, and two zones sharing a full edge. Not performed: a zone overlapping another, a zone touching half an edge (covered headless).
- [~] Save into a project folder and reopen with New then Open: regions, cutout, templates, the picture and the layer picture came back, document clean. Not performed: moving the folder (covered headless).
- [x] Save As into two new folders. The first run found a bug (pictures of layers were not copied), fixed; the second run copied both the illustration and the layer picture.
- [ ] Replace the picture with one of another size and read the confirmation dialog.
- [~] Fit camera clicked: residuals shown (-82.6% / -38.1% before the fit, -9.1% / +9.1% after, with the warning), status line updated. Not performed: changing the field of view, reading the horizon line (it is above the picture in this scene).
- [~] Test walk on; click-to-move in the preview (two destinations); x10 button; Pause (the character stayed put, the button read Resume), Resume (it walked on), Reset position (back at its start). Not performed: x1, x2, x5 buttons during a walk, arrow keys while editing.
- [~] Perspective export from the real dialog, twice. First run: 14.8 MB with the pictures embedded (bug, fixed). After the fix: 115 KB, both pictures referenced, no warning. The exported scene with a player was run from the editor, and click-to-move was sent into the running game. Not performed: 2D and 3D exports, a zone above the horizon.
- [~] Plugin unloaded with a modified document (disable then enable): a recovery copy was written, with its warning in the Output panel, and it loaded with the two groups, two regions and the picture. Not performed: closing Godot (the quit dialog).
- [~] Dock resized by dragging the splitter to about 590 px and about 375 px, in perspective mode: see "Narrow dock" in the results. Not performed: detaching the dock.
- [ ] Open a file saved with a newer `schema_version` and read the message.
- [~] Merge with… menu clicked, "Region 1" chosen: merged into one polygon, then Undo gave both regions back. Not performed: redo, a refused merge.
- [~] Add image… with the real file dialog (foreground_template.png), ground point typed (815, 590), layer hidden then shown, layer opacity 0.4 then 1, layer locked (the picture fields were disabled and a typed position was refused). Not performed: the Drawn selector (behind, in front), undoing each layer step with the mouse.
- [ ] Layers: change the position and scale fields with the spin box arrows and with typing; check that a run of arrow clicks undoes in one step.
- [x] In the editor preview: click-to-move behind the fountain, the character disappeared (depth 14.9 against 9.3 for the picture). In the exported scene running from the editor: a click behind the fountain hid the character (depth 13.8 against 9.3), a click in front showed it in front of the fountain ring.
- [~] Tabs switched with the mouse several times; the Layers section folded and unfolded with its header. Not performed: the other sections, detaching the dock.
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
| 8 | Template placement: with a template selected, a click in "Place / move height template" mode moves it instead of placing a new one, and the height field edits the selected template. | Existing behaviour (the user guide says to set the height after placing). Confusing; not changed. |

Evidence kept out of the repository (large screenshots of the dock and of the running game): they show the dock tabs, the folded section, the narrow layout, the fountain hiding and showing the character. No unrelated window was recorded, except that one Windows MCP window list taken at the start of the session also listed the titles and content of other applications; none of it is kept.

## Checked without a mouse

Done in this work and reproducible, but not a substitute for the list above:

- 297 headless GdUnit4 tests, including dock operations driven through the same signals the canvas emits.
- `tests/editor_selftest/run.ps1`: the dock and the test walk inside the real Godot editor runtime (headless editor).
- `tests/render_check/run.ps1`: a real GPU render of the village stage. The character is hidden behind the foreground fountain (1 matching pixel) and shown in front of it (2,725 pixels).
- A real render of the dock itself in a window, read by eye: the two tabs, the foldable sections, the layer panel, the speed controls. No click was made.

These were the only checks available before M12, when the Godot MCP and Windows MCP tools were not yet reachable from the session. M12 above is the first real-editor interaction.

## Preparation (M13)

- [ ] Bump `version` in `addons/illustrated_walkmesh_editor/plugin.cfg` to `0.1.0-alpha.1`; move the changelog's `Unreleased` entries under that version and date.
- [ ] Build an addon-only ZIP (`addons/illustrated_walkmesh_editor/` and the license). Open a new empty project with only that folder and enable the plugin.
- [ ] Add the village scene (`tests/e2e/village_scenario.gd` and its assets) as a second example, or document why not.
- [ ] Check the provenance and licence of every image in `assets/` and `examples/` that ships.
- [ ] Take screenshots for the README.
- [ ] Read the README and the user guide against the behaviour: every claim is covered by a test or marked experimental.
- [ ] CI green on the release commit.

## Release (owner only)

- [ ] Merge the pull request into the protected branches.
- [ ] Tag `v0.1.0-alpha.1` and publish the release with the ZIP.
