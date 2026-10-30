# Integration example: your own character in two connected levels

A small game made of two levels, played with a character that is **not** the plugin's. Open `level_village.tscn` and press F6 (Run current scene).

- Click the floor: the character walks there, round the fountain, with its own controller (`external_character.gd`).
- `PageUp` / `PageDown` change its speed (x1, x2, x5, x10), `Home` returns to x1.
- Walk onto the bridge, to the zone at its far end (the door): the game loads `level_cellar.tscn` and the character appears at the entry point `from_village`.
- In the cellar, walk into the stairs zone: the village loads again and the character appears at `from_cellar`, facing west.

| File | What it is |
|---|---|
| `external_character.gd`, `external_character.tscn` | A `CharacterBody3D` with its own controller and a lit capsule model (no rig, no animation). Its only link with the plugin is `add_to_group("iwe_traveller")` and the optional path helper `IWENavigationPath`. Read the comment at the top of the script: it lists what a game has to do. |
| `stage_village.tscn`, `stage_cellar.tscn` | Perspective stages exported by IWE (navigation, walls, camera, the door and stairs zones, the entry points, a `StageRuntime`). |
| `level_village.tscn`, `level_cellar.tscn` | The scene a game loads for one place: the exported stage, the character and some lighting (a stage has none). |
| `build_integration_example.gd` | Rebuilds all of the above from code with the helpers of the end-to-end scenario: `Godot --headless --path . -s examples/integration/build_integration_example.gd` |

The documents behind the stages are authored by the build script and not saved. The stages reference the pictures of `assets/img/`. This folder is not part of the addon ZIP.

See [docs/INTEGRATION.md](../../docs/INTEGRATION.md) and [docs/STAGE_TRANSITIONS.md](../../docs/STAGE_TRANSITIONS.md).
