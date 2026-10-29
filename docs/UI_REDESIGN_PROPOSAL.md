# UI redesign proposal (not implemented)

The repository holds no approved redesign target: `SPECIFICATION.md` 3.12 describes one, and the audit asks the owner whether it is the intended one (`PRE_RELEASE_AUDIT.md`, decision 3). This page is a proposal built from what the code and the new tests showed, so that a decision can be made quickly. Nothing below is built.

## What is true today

- One tall dock: a toolbar, a long sidebar (regions, groups, cutouts, templates, perspective panel), and the canvas or the 3D preview.
- The perspective panel now carries the calibration inputs, the fit button with its residual report, the test walk controls, and the export buttons. It is the longest part of the dock.
- Lock has a model and canvas support but no button. Region type and properties have no panel.
- Controls added in this work (test walk, fit report) are built in code, in the existing sidebar, and follow the existing style.

## Proposal

1. **Two workspaces**, switched by tabs above the canvas: *Author* (draw, edit, cutouts, templates) and *Test* (perspective, test walk, export). The Test workspace shows the preview large with the controls in a narrow column. This removes most of the scrolling.
2. **Contextual toolbar** under the tabs: only the tools of the current workspace, with the active tool highlighted and one line of help for it.
3. **Region properties** as a collapsible block under the region list: name, colour, visibility, lock, group. The lock button comes with it.
4. **Calibration** as three presets (Near, Middle, Far references) plus the fit report, with the raw camera numbers folded away by default.
5. **Narrow dock**: no control may be cut off at 380 px. Rows that do not fit wrap.
6. **First run**: when the document has no picture, the canvas shows three short steps (import a picture, draw a zone, place two references) instead of an empty area.

## Open choices for the owner

- Tabs or collapsible sections for the two workspaces.
- Whether the test walk speed multiplier should be remembered as an editor preference (the current build keeps it for the session only).
- Whether the alpha ships with the current dock.

## Checks once built

A 380 px dock shows every control; each workspace keeps its state when switched; nothing new is written to the document.
