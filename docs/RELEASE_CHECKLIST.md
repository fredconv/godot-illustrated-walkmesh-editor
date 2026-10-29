# Release checklist for `0.1.0-alpha.1`

Nothing here has been done as a release step. The version is still `0.1.0-dev`, no tag exists and nothing is published. This list is what remains, in order.

## Before the release (owner decisions)

- [ ] Decide whether the first release is the authoring and perspective core, or also includes layers and occlusion (`PRE_RELEASE_AUDIT.md`, decision 1). This list assumes the core only.
- [ ] Decide the UI target (`UI_REDESIGN_PROPOSAL.md`) or accept the current dock for an alpha.

## Manual QA with a mouse (M12)

None of these can be run by the headless suite or by the editor self-test (`tests/editor_selftest/`). Record the date and the result of each in `DEVELOPMENT.md` once done.

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
