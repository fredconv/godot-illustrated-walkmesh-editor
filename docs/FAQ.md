# FAQ

## Do I need other addons?

No. IWE was verified by enabling it alone in an empty Godot 4.7.1 project: the editor starts without errors. UniBuilder and Godot MCP are development tools of the author and are not needed.

## Which Godot version is supported?

Godot 4.7.1 is the validated version. Other 4.x versions are untested.

## Does IWE rebuild the scene in 3D from my image?

No. The perspective stage projects your image onto one flat virtual floor, using a camera you calibrate with character references. It does not infer terrain height or hidden depth from a single image. Changing the calibration means exporting the stage again.

## Do my walkable zones have to be merged into one polygon?

No. Draw each zone separately. Two zones that share an edge form one walkable network: the character walks across the shared edge without a wall. Zones that only touch at a corner are not connected. Zones that overlap without sharing an exact edge are not connected yet either: make their borders meet on the same edge.

## Where is my work saved?

A saved IWE document is a `.tres` file. The illustration is copied into an `assets/` folder next to it, so the project folder can be moved as a whole. See [DATA_FORMAT.md](DATA_FORMAT.md).

## Can I undo my edits?

Yes, for polygon edits, cutouts, groups, templates, and calibration changes. Use the dock's `Undo` and `Redo` buttons, or `Ctrl+Z` and `Ctrl+Shift+Z` while the illustration has focus. The history belongs to the open document and is reset when you create or open another document.

## Why does my exported scene not match the editor after I changed the calibration?

Exports are generated files. Export again after changing regions, cutouts, templates, or calibration. If you regenerate the demo scene while it is open in the editor, read the warning in [DEVELOPMENT.md](DEVELOPMENT.md) first.

## Can I use IWE in a commercial project?

IWE is MIT-licensed. Check the licence of the assets you use with it; the demo images are illustrations created or modified by the project owner, who confirms permission to use and redistribute them in this plugin, its examples and its releases ([assets/README.md](../assets/README.md)).

## Is IWE production-ready?

No. It is a pre-release (`0.1.0-alpha.4`). The saved format may change before a stable version. Keep backups of your documents.

## Where do I report a bug or ask a question?

Open a GitHub Issue with the bug report template. For questions and ideas, use a feature request issue. Security problems should follow [SECURITY.md](../SECURITY.md).
