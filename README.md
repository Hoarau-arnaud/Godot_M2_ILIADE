# Simulation SMA spatiale — version finale M16 et démo soutenance M17

Projet Godot **4.7.2 / GDScript** : quatre types d’agents autonomes, BlueShip, PatrolDrone, Interceptor et Capital Ship. Les projectiles, grilles, astéroïdes et décors ne sont pas des agents. Aucun cinquième agent ni nouvelle famille d’armes dans M16.

## Lancer et présenter

Importer `project.godot` dans Godot 4.7.2 puis lancer le projet. GUIDED démarre automatiquement, avec réglages/aide masqués. FREE reste accessible via le panneau. Les commandes ci-dessous concernent la fenêtre de jeu ; F5 dans l’éditeur conserve sa fonction Godot habituelle.

| Commande | Fonction |
|---|---|
| D | Basculer FREE/GUIDED ; retour FREE en PRESENTATION |
| F7 | Démo soutenance : écran READY, combat figé |
| ESPACE | Démarrer PRESENTATION / passer immédiatement à la phase suivante |
| R | Recommencer PRESENTATION depuis READY, pertes remises à zéro |
| Échap | Retour FREE depuis PRESENTATION |
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

## Démo soutenance

F7 ou « Démo soutenance » ouvre READY. ESPACE lance **cinq phases de 30 secondes**, séparées par quatre transitions de 0,5 seconde : **152 secondes (~2 min 32)**, hors pause et sauts. Le titre de phase disparaît après trois secondes. P fige agents, projectiles, caméra et horloge ; ESPACE passe à la phase suivante. R recommence avec les deux compteurs à zéro ; D/Échap restaure FREE. F1–F6 restent les raccourcis scientifiques GUIDED M16.

| Phase | BlueShip visés | Patrol visés | Interceptor visés | Capital visés |
|---|---:|---:|---:|---:|
| 1 — Évitement collectif | 15 | 0 | 0 | 0 |
| 2 — Patrouille autonome | 15 | 15 | 0 | 0 |
| 3 — Interception | 15 | 0 | 15 | 0 |
| 4 — Artillerie capitale | 15 | 0 | 0 | 6 |
| 5 — Assaut final | 15 | 15 | 15 | 6 |

Les ennemis sont remplacés avec un RNG déterministe : **0,8–1,4 s réelles** pour Patrol/Interceptor, **2–4 s** pour Capital. Les destructions environnementales provoquent aussi un remplacement ; le compteur **Ennemis abattus** ne compte que le combat. Nettoyage, changement de phase, skip, retraits manuels et retour FREE ne donnent aucun kill. Les BlueShip attaquent en P2–P5, avec leurs perceptions, cône de tir, portée, ligne de vue et priorité à la sécurité. Certains Capital approchent à 70–76 m pour 5–6 s, puis repartent ; les BlueShip continuent leur navigation autonome. Le HUD conserve les pertes Blue et les kills ennemis sur toute la présentation.

À l'entrée de P5, le **LABORATOIRE DE BATAILLE** s'affiche à gauche. Après ses 30 s automatiques, la simulation continue dans **FINAL_SANDBOX** sans limite de durée. ESPACE ou TERMINER ouvre FIN ; R recommence, D/Échap retourne à FREE. RESET restaure les réglages de bataille sans effacer les compteurs.

| Réglage | Bornes | RESET | CHAOS |
|---|---|---:|---:|
| Drones verts | 0–30 | 15 | 25 |
| Intercepteurs | 0–30 | 15 | 25 |
| Vaisseaux capitaux | 0–10 | 6 | 8 |
| Fréquence tirs ennemis | 0,5–4× | 2× | 3× |
| Largeur projectiles | 0,5–3× | 1× | 1,7× |
| Épaisseur grilles | 0,5–3× | 1× | 1,8× |
| Vitesse projectiles | 0,5–2× | 1× | 1,3× |
| Dégâts ennemis | 1–3 | 1 | 2 |
| Densité astéroïdes | 0–2,5× | 1× | 1,6× |
| Mega / Colossal | 0–3 | 1, normal | 3, élevé |
| Agressivité | 0,5–3× | 1× | 2× |

Les ajouts sont progressifs et les retraits administratifs. Largeur, collision et `avoidance_radius` varient ensemble ; les animations gardent l'épaisseur choisie. La vitesse entre dans la prédiction des nouveaux tirs. Les BlueLaser gardent leurs paramètres. La fréquence Patrol de P2 et la fréquence Interceptor de P3 sont doublées par rapport au commit `3929024`. L'agressivité modifie la détection/poursuite et le cône de recherche, indépendamment de la cadence.

P4 et P5 programment **six lancements de Gate/Grid en 30 s**, soit trois fois les deux lancements des phases précédentes ; les budgets peuvent différer un lancement. Au maximum deux grandes grilles coexistent. Les formes rouges/orange sont RECTANGULAR, DIAGONAL_X, DIAMOND, OFFSET_CROSS, HEXAGONAL, RADIAL et ASYMMETRIC. Elles disposent d'au moins trois ouvertures intérieures sûres, de contournements et de rotations déterministes. Le plafond partagé reste **35 unités dangereuses**, beams compris ; les astéroïdes physiques sont limités à 80.

Seed de présentation : **20261012**. Validation : `--headless --path . --fixed-fps 60 --script res://tests/validate_presentation_demo.gd` pour les commandes ; `-- --complete` pour les cinq phases, 30 s de réglages sandbox et 30 s de CHAOS. Sans `--headless` ni `--fixed-fps`, `-- --native` mesure ces parcours à 1920×1080. `-- --capture` produit les captures UI. `tests/validate_battle_lab.gd` vérifie les cinq kills contrôlés, les délais, les retraits, les sept géométries, les collisions de largeur et un kill Capital par BlueLaser à 24 PV. Les tests historiques restent dans `tests/run_validation.ps1`. PRESENTATION regroupe les silhouettes statiques en meshes mis en cache, réduit le décor proche, répartit la génération des météores et annule les approches Capital devant une grosse masse. Les formes physiques sont conservées ; FREE/GUIDED gardent leurs réglages et leurs visuels. Les mesures scientifiques M16 ci-dessous sont conservées.

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
