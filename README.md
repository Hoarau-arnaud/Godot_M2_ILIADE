# Simulation SMA spatiale — version finale M16

Projet Godot **4.7.2 / GDScript** : quatre types d’agents autonomes, BlueShip, PatrolDrone, Interceptor et Capital Ship. Les projectiles, grilles, astéroïdes et décors ne sont pas des agents. Aucun cinquième agent ni nouvelle famille d’armes dans M16.

## Lancer et présenter

Importer `project.godot` dans Godot 4.7.2 puis lancer le projet. GUIDED démarre automatiquement, avec réglages/aide masqués. FREE reste accessible via le panneau. Les commandes ci-dessous concernent la fenêtre de jeu ; F5 dans l’éditeur conserve sa fonction Godot habituelle.

| Commande | Fonction |
|---|---|
| D | Basculer FREE/GUIDED |
| F1 / F2 | Obstacles / astéroïdes dynamiques |
| F3 / F4 | Patrol / Interceptor |
| F5 / F6 | Capital-artillerie / assaut final |
| P ou Pause | Suspendre/reprendre agents, projectiles, caméra et timer |
| TAB / H | Afficher/masquer réglages / aide |
| F / C | Suivi-libre / cinématique en FREE |
| F11 / Alt+Entrée | Plein écran |
| 0 / 1 / 2 / 3 | Difficulté automatique / facile / moyenne / difficile en FREE |
| Clic droit, molette, flèches/WASD/ZQ, PageUp/E/PageDown | Orbite, zoom et déplacement en caméra libre |
| G / Home | Recentrer la caméra libre |

Le panneau propose aussi six boutons compacts P1–P6. Il défile verticalement si nécessaire en 720p. Un saut recrée seulement Guided, recentre la caméra et remet le timer de phase à zéro, sans compter le nettoyage comme mort. Les pertes cumulées sont conservées ; Replay seul/nouveau run les efface et remet phase 1 + seed initiale. Un saut pendant pause reste suspendu. Quitter Guided ou Replay reprend la simulation.

Le HUD permanent contient uniquement pertes bleues, étoiles et titre de phase. PAUSE est temporaire. Pour une capture propre, masquer les réglages et l’aide avec TAB/H si ces panneaux sont ouverts.

## Parcours

Phases 1–4 : 18 s réelles chacune ; Capital : 42 s pour laisser arriver Heavy → Seeker → Moving Gate → Bomb → Rotating Grid → Swarm → Arc ; finale continue à cible 15 Blue / 4 Patrol / 4 Interceptor / 3 Capital. Les survivants persistent pendant le parcours normal. Renforts après 1,0–1,6 s réelles, éventuellement retardés si aucun spawn n’est sûr.

Les dangers M15 sont conservés : Gate/Grid mobiles 110×80 m à 45 m/s, rotation 15/±25°/s, ouvertures mémorisées localement ; rares Colossal 96 m (plage nominale jusqu’à 160 m), boost doré sans collider, missiles volumétriques, planète/anneau et décor procédural original. Une grande grille et un Colossal au plus simultanément, plafonds de 64/48/64 rochers et 40 unités dangereuses. Aucune consigne de trajectoire globale normale aux BlueShip.

## Rapport et étude

[RAPPORT.md](RAPPORT.md) fournit les quatre rôles, perceptions/actions, machines à états Mermaid, interactions, étude des cinq paramètres, cinq seeds, exemple d’émergence, performances, terminaison et limites. Il est prêt à servir de base au PowerPoint ; aucun PowerPoint n’est créé ici.

Étude univariée : spacing 0,8/1,0/1,2/1,4 ; movement 0,7/1,0/1,3/1,6 ; densité 0,7/1,0/1,5/2,0 ; tirs 0,7/1,0/1,5/2,0 ; Interceptor 0/2/4/6. Finale contrôlée, lot nominal de 32 rochers, 60 s simulées, autres paramètres à 1,0 et quatre Interceptor. La densité du lot est plafonnée à 62 ; le parcours normal reste à son réglage M15. Cinq seeds 20261012–20261016 utilisent la même configuration. Pour l’étude seulement, le séquenceur suit le pas physique, avec deux frames initiales figées et un arrêt exact à 60 s simulées ; le timer du parcours normal reste au rendu. Les [données brutes](docs/experiments/m16_results.json) sont versionnées ; logs et captures restent ignorés.

## Validation reproductible

Depuis la racine du projet, PowerShell :

```powershell
$godotExe = 'C:\Users\Sora\Desktop\Godot_v4.7.2-stable_win64.exe'
./tests/run_validation.ps1 -GodotExe $godotExe
Start-Process -FilePath $godotExe -ArgumentList '--headless','--path','.','--fixed-fps','60','--script','res://tests/validate_final_study.gd','--log-file','.godot/m16_study.log','--','--study' -WindowStyle Hidden -Wait
```

Pour le benchmark graphique : lancer le même script sans `--headless`/`--fixed-fps`, avec `--native` à la place de `--study`. `--native --capture` constitue un essai séparé, exclu des FPS. `--ui-native` vérifie pause, sauts et 720p/1080p/maximisé/fullscreen. Les résultats sont écrits dans `.godot/m16_*.json`. Les treize suites contrôlent leurs profils historiques ; elles ne désactivent pas leurs assertions de collisions ou de survie.

## Limites

Modèle arcade, paramètres empiriques, prédictions/collisions approximatives, récupération locale parfois partielle. Un isolé est défini par l’absence de voisin local ; zéro isolé ne garantit pas un seul groupe compact. La seed, la cadence et les menaces concurrentes changent les résultats. Les FPS sont propres à la machine et mesurés sans compression PNG, après 2 s de chauffe, dans une fenêtre 1920×1080. Les chiffres et le résultat de l’assertion >60 FPS figurent dans le rapport ; ils restent propres à cette machine et à ce protocole. Le plein écran de cet écran 3840×2400 a un coût supplémentaire ; sa validation UI ne garantit pas le même débit. L’[historique M1–M15](docs/HISTORIQUE_M1_M15.md) conserve les anciennes validations.
