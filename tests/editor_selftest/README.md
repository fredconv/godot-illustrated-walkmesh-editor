# Editor self-test

The GdUnit4 suite runs without the editor. This self-test runs the dock and the test walk inside the
real Godot editor (headless editor mode), where `Engine.is_editor_hint()` is true and the preview
character is a tool script. It checks what the headless suite cannot: that the navigation settles in
the editor, that the character walks, that the speed presets scale the walking time, and that pause
holds it still.

```powershell
pwsh tests/editor_selftest/run.ps1 -Godot "C:\path\to\Godot_v4.7-stable_win64_console.exe"
```

Expected lines: `editor_hint=true`, `nav_settled=true`, a walk at multiplier 1.0 that takes about ten
times more frames than at 10.0, `paused_moved=0.00000`, and `reset_distance_from_start=0.0000`.

It uses no mouse or keyboard. Clicking in the real editor window is still a manual check.
