# Release checklist for `0.1.0-alpha.1`

Nothing here has been done as a release step. The version is still `0.1.0-dev`, no tag exists and nothing is published. This list is what remains, in order.

## Before the release (owner decisions)

- [x] Scope decided by the owner on 2026-10-29: layers and foreground occlusion are part of the first release.
- [x] UI direction decided by the owner on 2026-10-29: two tabs, Creation and Test, with foldable sections.
- [ ] Final validation and the owner's explicit approval before any release step.

## Manual QA with a mouse (M12)

None of these can be run by the headless suite or by the editor self-test (`tests/editor_selftest/`). Record the date and the result of each in `DEVELOPMENT.md` once done.

What was checked without a mouse is listed separately in the "Checked without a mouse" section below. Nothing in this list has been performed by hand.

- [ ] Draw, edit and delete polygons with the mouse; drag vertices; step through undo and redo; check spin box arrows and merged undo steps.
- [ ] Draw a cutout, a zone overlapping another zone, and a zone touching half of another zone's edge.
- [ ] Save into a real project folder, move the folder, reopen. The picture shows and the regions are intact.
- [ ] Save As into a second folder. The second folder has its own `assets/` copy.
- [ ] Replace the picture with one of another size and read the confirmation dialog.
- [ ] Open the perspective panel: fit the camera, read the residual and horizon lines, change the field of view.
- [ ] Turn on `Test walk`, click the preview, try x1, x2, x5, x10 during a walk, pause, resume, reset. Check that arrow keys do not move the character while editing.
- [ ] Export 2D, 3D and perspective scenes into the project (the picture should be referenced, not embedded: the file is small), open each and run it with F5. Check the Output panel warnings for a zone above the horizon.
- [ ] Close Godot with a modified document and check the quit dialog and the recovery copy.
- [ ] Resize and detach the dock in perspective mode.
- [ ] Open a file saved with a newer `schema_version` and read the message.
- [ ] Regions: merge two touching regions with `Merge with…`, undo, redo; try a merge that must be refused.
- [ ] Layers: add an image on the Foreground layer, set its ground point, switch it to behind, in front and by depth, hide and lock the layer, undo each step.
- [ ] Layers: change the position and scale fields with the spin box arrows and with typing; check that a run of arrow clicks undoes in one step.
- [ ] Test tab: walk the character behind the foreground fountain and in front of it with the mouse, in the editor preview and in the exported scene run with F5.
- [ ] Dock tabs: fold and unfold each section; switch between Creation and Test with the mouse; resize and detach the dock.
- [ ] Check that every control is reachable and not cut off at a narrow dock width (about 380 px).

## Checked without a mouse

Done in this work and reproducible, but not a substitute for the list above:

- 292 headless GdUnit4 tests, including dock operations driven through the same signals the canvas emits.
- `tests/editor_selftest/run.ps1`: the dock and the test walk inside the real Godot editor runtime (headless editor).
- `tests/render_check/run.ps1`: a real GPU render of the village stage. The character is hidden behind the foreground fountain (1 matching pixel) and shown in front of it (2,725 pixels).
- A real render of the dock itself in a window, read by eye: the two tabs, the foldable sections, the layer panel, the speed controls. No click was made.

Not possible with the tools of that session: the Godot MCP and Windows desktop automation tools were not available, so no click, drag or key press was sent to a real editor window.

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
