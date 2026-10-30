# HANDOFF — état au 2026-10-30 (après la préparation de 0.1.0-alpha.3)

Fichier de reprise pour une nouvelle session. Il ne remplace pas `docs/`; il dit où on en est et quoi faire ensuite.

## Contexte
- Plugin Godot « Illustrated Walkmesh Editor » (`addons/illustrated_walkmesh_editor/`), Godot 4.7.1.
- Branche de travail `feature/stage-transitions` (partie de `develop`). Les pré-releases `v0.1.0-alpha.1` et `v0.1.0-alpha.2` sont publiées et ne doivent ni être remplacées ni supprimées. `main` n'est jamais touchée directement : tout passe par une branche et une PR vers `develop`. Pas de force-push.
- Le propriétaire a demandé de ne déclarer le plugin « stable » qu'une fois le périmètre de base implémenté, intégré, testé et documenté. Les images du dépôt sont les siennes, avec autorisation d'usage et de redistribution confirmée : ne pas les remplacer pour une raison de licence.
- Décision V1/V2 : en V1 les images de calque sont préparées en amont (même canevas que le fond) ; l'édition à la souris (déplacer, redimensionner) est V2.

## Fait dans cette session (alpha.3)
- **Zones d'action et points d'entrée** (format de document version 3, migration 1 et 2 en mémoire), édition dans le dock, export 2D, 3D plat et perspective, runtime sans autoload : `IWEStageTravel`, `IWEStageRuntime`, `IWETransitionZone(2D)`, `IWEEntryMarker(2D)`. Voir `docs/STAGE_TRANSITIONS.md`.
- **Personnage externe** : groupe `iwe_traveller`, `IWENavigationPath`, `examples/integration/` (deux niveaux reliés). Voir `docs/INTEGRATION.md`.
- **Vitesse** : touches PageUp / PageDown / Home dans le jeu (`debug_speed_keys`), boutons du dock pour l'aperçu seulement.
- **Interface** : le bouton `Window` détache toute l'interface ; infobulles, aide de la barre d'état, compteurs dans les titres de sections.
- 392 tests headless, contrôle de rendu GPU étendu, ZIP de l'addon testé en projet vierge, validation dans un éditeur et un jeu réels isolés (`docs/RELEASE_CHECKLIST.md`, section « Base scope for 0.1.0-alpha.3 »).

## Ne pas toucher
`project.godot` (modifié par l'utilisateur), le dossier `scenes/`, `addons/phantom_camera/`, `prototypes/occlusion/*.uid` : changements locaux de l'utilisateur. **Ne jamais** faire `git add addons` ni `git add -A` : ajouter les chemins explicitement (`addons/illustrated_walkmesh_editor`, `tests`, `docs`, `examples`, `assets`).

## Outils
- Tests headless : `Godot_v4.7-stable_win64_console.exe --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add "res://tests" --ignoreHeadlessMode` (binaire dans `C:\Users\fredc\Downloads\Godot_v4.7-stable_win64.exe\`). Lancer `--import` avant pour régénérer le cache des classes et les fichiers `.uid` (à commiter pour les nouveaux scripts).
- Contrôle de rendu GPU : `pwsh tests/render_check/run.ps1 -Godot <console.exe>` (ouvre une fenêtre, quelques minutes). Captures du README : `pwsh tests/render_check/readme_shots.ps1`.
- Test du ZIP : `pwsh tests/release_check/run.ps1 -Godot <console.exe> -Zip <fichier.zip>`.
- Reconstruire les exemples : `examples/village/build_village_example.gd`, `examples/integration/build_integration_example.gd` (voir leurs README).
- Validation dans l'éditeur réel : lancer un éditeur isolé sur une copie temporaire du projet, déplacer sa fenêtre sur un autre écran avec `SetWindowPos`, ne capturer que la région de cette fenêtre, vérifier `ControlStatus` avant chaque série de clics, ne jamais toucher l'éditeur de l'utilisateur. Le mode « fenêtre unique » de l'éditeur empêche l'onglet Game intégré et le détachement du dock lui-même.
- Éviter les heredocs Bash contenant des apostrophes : écrire les scripts avec l'outil Write.

## Reste à faire
1. Fusionner la PR de cette branche dans `develop` (CI verte), puis taguer `v0.1.0-alpha.3` et publier la pré-release avec `illustrated_walkmesh_editor-0.1.0-alpha.3.zip` (le ZIP se fabrique avec `git archive` de `origin/develop`, voir `docs/RELEASE_CHECKLIST.md`). La PR #3 (`codex/release-checklist-alpha2`, documentation) peut entrer en conflit sur `docs/RELEASE_CHECKLIST.md`.
2. Pas encore fait du périmètre : édition des sommets d'une zone, interactions avec bouton, conditions, personnage riggé et animé, vérification à toutes les largeurs du dock. Les limites sont décrites dans `README.md` et la checklist.
3. V2 : édition visuelle des images de calque (`docs/ROADMAP.md`, section V2).
