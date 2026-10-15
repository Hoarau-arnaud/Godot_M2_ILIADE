# Simulation SMA spatiale — version finale M16 et démo soutenance M17

Projet Godot **4.7.2 / GDScript** : quatre types d’agents autonomes, BlueShip, PatrolDrone, Interceptor et Capital Ship. Les projectiles, grilles, astéroïdes et décors ne sont pas des agents. Aucun cinquième agent ni nouvelle famille d’armes dans M16.

## Lancer et présenter

Importer `project.godot` dans Godot 4.7.2 puis lancer le projet. Play ouvre directement **DÉMO SOUTENANCE**, en attente sur READY, avec **ESPACE — Démarrer** et **ALLER À LA FINALE**. La simulation reste figée avant le choix. FREE reste accessible via le panneau. Les commandes ci-dessous concernent la fenêtre de jeu ; F5 dans l’éditeur conserve sa fonction Godot habituelle.

| Commande | Fonction |
|---|---|
| D / Échap | Retour à la simulation libre |
| F7 | Démo soutenance : écran READY, combat figé |
| ESPACE | Démarrer PRESENTATION / passer immédiatement à la phase suivante |
| R | Recommencer PRESENTATION depuis READY, pertes remises à zéro |
| F8 | ALLER À LA FINALE depuis READY ou une phase en cours |
| P ou Pause | Suspendre/reprendre agents, projectiles, caméra et timer |
| TAB / H | Afficher/masquer réglages / aide |
| F / C | Suivi-libre / cinématique en FREE |
| F11 / Alt+Entrée | Plein écran |
| 0 / 1 / 2 / 3 | Difficulté automatique / facile / moyenne / difficile en FREE |
| Clic droit, molette, flèches/WASD/ZQ, PageUp/E/PageDown | Orbite, zoom et déplacement en caméra libre |
| G / Home | Recentrer la caméra libre |

Le bouton **ALLER À LA FINALE** est présent sur READY et reste accessible en haut à droite pendant P1–P4. Il ouvre ASSAUT FINAL à t=0 avec Battle Lab immédiatement visible et les cibles 15 Patrol / 15 Interceptor / 6 Capital. Le saut conserve les pertes et kills réels d'une phase déjà jouée ; son nettoyage ne donne aucun score. Depuis READY, les compteurs restent à zéro. L'ancien scénario Guided est conservé comme infrastructure interne et pour les tests historiques, sans bouton ni raccourci utilisateur.

Le HUD affiche les pertes bleues et ennemis abattus ; le titre de phase et PAUSE sont temporaires. TAB/H ouvrent réglages/aide. Le panneau défile si nécessaire en 720p.

## Démo soutenance

READY est le premier écran au Play ; F7 ou « Démo soutenance » le prépare à nouveau. ESPACE lance **cinq phases de 30 secondes**, séparées par quatre transitions de 0,5 seconde : **152 secondes (~2 min 32)**, hors pause et sauts. Le titre de phase disparaît après trois secondes. P fige agents, projectiles, caméra et horloge ; ESPACE passe à la phase suivante. R recommence avec les deux compteurs à zéro ; D/Échap restaure FREE. F8 permet de passer directement à la finale.

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

Les ajouts sont progressifs et les retraits administratifs. Largeur, collision et `avoidance_radius` varient ensemble ; les animations gardent l'épaisseur choisie. La vitesse entre dans la prédiction des nouveaux tirs. Les BlueLaser cyan ont un corps de 0,48 m (anciennement 0,24 m), une pointe de rayon 0,52 m et un **rayon physique balayé de 0,7 m**, avec blocage par les astéroïdes et sans friendly fire. En Presentation, les tirs Interceptor partent d’une base **1,75×** et les pulses Patrol d’une base **1,5×** ; le slider multiplie ensuite cette base, collision et perception comprises. La fréquence Patrol de P2 et la fréquence Interceptor de P3 sont doublées par rapport au commit `3929024`. L'agressivité modifie la détection/poursuite et le cône de recherche, indépendamment de la cadence.

En finale uniquement, tous les spawns légers (initiaux, remplacements, sliders) restent proches du barycentre Blue : Patrol X ±20–55 m, Y ±25 m, Z −80 à −35 m ; Interceptor X ±20–60 m, Y ±25 m, Z −80 à −35 m. Une recherche de clearance bornée reste dans X ±58 / Y ±32 / Z −85…−35 m ; sans place sûre, l'ajout est différé. Les Patrol bouclent sur quatre waypoints locaux : leur ancre 3D suit doucement le centre lorsque son déplacement dépasse 18 m. Ils ne poursuivent aucune cible, gardent un cône frontal de 43° et une portée de 70 m. Les Interceptor répartissent les cibles centrales selon distance, visibilité et charge de poursuite ; leur désengagement rejoint une position de mission locale. Les unités trop loin pendant 3 s sont recyclées lorsqu'elles passent hors champ : Patrol >115 m, Interceptor >145 m sans engagement. Aucun kill ni respawn de mort n'est ajouté. Les Capital restent lointains, avec leurs fenêtres de vulnérabilité.

P4/P5 disposent d'un scheduler dédié : **un lancement toutes les 1,667 s** au réglage nominal de cadence 2×, soit environ **18 grilles en 30 s**, trois fois les six du main précédent. Cadence 4× donne un intervalle de 0,833 s. Les formes RECTANGULAR, DIAGONAL_X, DIAMOND, OFFSET_CROSS, HEXAGONAL, RADIAL et ASYMMETRIC alternent sans répétition immédiate, avec décalages de position, angle et horaire. Chaque grille garde des ouvertures et contournements ; elle est retirée une fois passée derrière toute la flotte. Le plafond autorise quatre grandes grilles (la troisième/quatrième demandent au moins 75 FPS mesurés) et **48 unités dangereuses** beams compris. Les quotas de tirs verts/rouges réservent des occasions aux deux familles. Les rochers physiques restent plafonnés à 80.

Seed : **20261012**. `tests/validate_final_battle_flow.gd` vérifie Play/READY, boutons/F8, compteurs, largeur physique Blue, masque, blocage rocher, largeurs ennemies, distances et engagements pendant 30 s, sliders et lancements effectifs. Exécution : `--headless --path . --fixed-fps 60 --script res://tests/validate_final_battle_flow.gd` ; `-- --unit` limite aux fixtures. Sans `--headless`/`--fixed-fps`, `-- --native` mesure P4, P5, sliders puis CHAOS à 1920×1080. Les tests M17 et `validate_battle_lab.gd` restent disponibles ; les tests M1–M16 utilisent explicitement le helper interne via `tests/run_validation.ps1`. Les mesures scientifiques historiques ci-dessous sont conservées.

La Presentation utilise des meshes/matériaux partagés pour les tirs et explosions, un rejet de plan avant les contacts des grilles, des perceptions de proximité espacées de 0,06–0,08 s simulée, un pas physique de 90 Hz (0,0222 s simulée à 2×) et MSAA 2×. Les sweeps de projectiles et les collisions de déplacement restent actifs. Les réglages du viewport et de simulation libre sont restaurés à la sortie. Les comptes rendus 1080p précisent ces conditions.

Validation 1080p du correctif (seed 20261012, MSAA 2×, physique 90 Hz) : **P5 99,76 / 96,45 FPS**, **CHAOS 97,88 / 85,25 FPS** (moyenne / minimum sur une seconde). P4 et P5 : **18 lancements réels chacune**. P5 : 15/15 Patrol ont tiré, 15/15 Interceptor ont poursuivi/tiré ; 100,00 % / 98,52 % des mesures sont sous 100 m. Détails, médianes, maxima et sliders dans le rapport.

## Parcours scientifique historique M16

Phases 1–4 : 18 s réelles chacune ; Capital : 42 s pour laisser arriver Heavy → Seeker → Moving Gate → Bomb → Rotating Grid → Swarm → Arc ; finale continue à cible 15 Blue / 4 Patrol / 4 Interceptor / 3 Capital. Les survivants persistent pendant le parcours scientifique interne. Renforts après 1,0–1,6 s réelles, éventuellement retardés si aucun spawn n’est sûr.

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
