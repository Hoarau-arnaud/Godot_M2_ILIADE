# Simulation SMA spatiale — milestone 11

Projet pédagogique **Godot 4.7.2 / GDScript**, avec quatre agents : **BlueShip, PatrolDrone, Interceptor et Capital Artillery Ship**. M11 ajoute une **démonstration guidée de 100 secondes** au mode **Simulation libre** existant, un voisinage planétaire stylisé et des projectiles plus lisibles. Les astéroïdes restent l'environnement ; les missiles sont des objets de combat. Aucun cinquième agent, asset externe, bombe ou PowerPoint n'est ajouté.

## M11 — Simulation libre et démonstration guidée

Le lancement reste en **Simulation libre (FREE)** : AUTO, dix BlueShip, vitesse 1,7×, mouvement 1,2, réglages runtime et Mode spectacle disponibles. La caméra Libre commandée par F est un **mode de caméra**, distinct du mode de simulation FREE.

**D** démarre la démo depuis FREE et l'arrête depuis GUIDED. Le panneau comporte **Simulation libre**, **Démo guidée** et **Recommencer démo**. D étant réservé au scénario, le déplacement caméra à droite utilise la flèche droite ; W/Z/S/A/Q et les autres commandes restent disponibles. TAB permet de réafficher le panneau pendant la démo, H l'aide et F11/Alt+Entrée le plein écran.

Le séquenceur `GuidedDemonstration`, qui n'est pas un agent, utilise `DemoMode.FREE/GUIDED`. Les entités libres restent dans leurs parents, cachées, avec traitement et collisions suspendus et groupes de perception retirés. Cela conserve leurs identités, cibles, mémoires, HP et timers. Les réglages, compteurs, RNG, streaming et caméra sont sauvegardés puis restaurés. La démo se termine automatiquement en FREE ; on peut aussi l'arrêter ou la recommencer à tout moment. Fermer directement en GUIDED libère les deux ensembles avec la scène.

Chaque phase repart avec **15 BlueShip neufs et 3 HP**, autour du centre courant. Ce reset retire les précédents sans mort ni score ; seules les collisions et les dégâts réels incrémentent le compteur de la démo. Les projectiles et ennemis de la phase précédente sont supprimés. Les acteurs de la simulation libre restent préservés. Les collisions des BlueShip de démonstration sont toujours actives.

| Phase | Durée réelle | Présentation et populations |
|---|---:|---|
| 1 — Champ d'astéroïdes | 15 s | `DEMO_SLALOM_TUNNEL` : 130 rochers statiques, cinq rangées à passages gauche/haut/droite/bas/gauche ; cinq LINEAR à angles différents ; aucun ennemi |
| 2 — Astéroïdes dynamiques | 15 s | 16 rochers : quatre DIAGONAL, quatre VERTICAL_SWEEP, quatre orbites inclinées CIRCULAR et quatre ARC ; aucun ennemi |
| 3 — Drones de patrouille | 15 s | Quatre PatrolDrone, routes A/B/C/D puis nouvelle route, marqueurs verts sans collision, pulses verts ; trois rochers de décor |
| 4 — Intercepteurs | 15 s | Quatre Interceptor placés près du groupe : acquisition rapide, poursuite, rafales, désengagement ; trois rochers de décor |
| 5 — Artillerie capitale | 20 s | Un Capital à environ 230 m ; FSM active, ordre pédagogique Heavy → Spread → Arc → Cross → Seeker ; aucun autre ennemi ou rocher |
| 6 — Confrontation finale | 20 s | Champ normal difficile/mobile, cinq PatrolDrone, quatre Interceptor, un Capital ; tous les tirs, vitesse 1,7×, mouvement 1,3, espacement 1,05 |

Deux chasseurs commencent la finale plus écartés, à portée de récupération locale de 50 m. Aucune force ni route commune n'est imposée : les règles existantes produisent leur retour. Les cinq dernières secondes offrent une respiration : les ennemis arrêtent les nouveaux tirs, tandis que leurs mouvements, les obstacles, les tirs déjà lancés et le combat bleu continuent.

Les durées sont exportées en **secondes réelles** : `demo_phase_duration=15`, `capital_phase_duration=20`, `finale_phase_duration=20`, `finale_relief_duration=5`. Elles restent indépendantes du rythme de simulation. La seed de scénario vaut `20261012` ; le restart reproduit les conditions initiales et l'ordre des attaques. En dehors de GUIDED, le Capital retrouve son choix et son rythme M10 habituels.

Un titre discret **PHASE X — NOM** apparaît sous les étoiles pendant GUIDED, puis disparaît en FREE. Le titre fait un fade de 0,7 s réelles ; les cadrages interpolent sur 0,8 s. CINEMATIC est automatique : CHASE/HIGH, SIDE/WIDE, SIDE/CHASE, CHASE, WIDE, puis cycle complet. Le groupe bleu reste prioritaire et la dispersion peut demander un plan plus large. Aide et panneau sont masqués au départ ; les réglages du scénario et la caméra sont verrouillés, les boutons de sortie/restart restent accessibles via TAB. Le HUD n'ajoute ni chrono, ni HP, ni compte de missiles.

### Planète et projectiles

Le groupe vole dans un **champ orbital stylisé près d'une grande planète**, avec une courbure bleu/cyan occupant une partie du fond, une surface procédurale et une sphère atmosphérique légèrement plus grande. **360 débris distants dans une seule MultiMesh** suggèrent un anneau. Planète, halo et débris n'ont aucune collision ni perception d'agent. Le ciel utilise un [ProceduralSkyMaterial](https://docs.godotengine.org/en/stable/classes/class_proceduralskymaterial.html), avec des nuances très sombres de bleu, cyan et violet/magenta. Il s'agit d'un décor, sans modèle gravitationnel ou orbital astrophysique.

| Visuel | Avant M11 | M11 |
|---|---:|---:|
| BlueLaser — largeur du bolt | 0,12 m | **0,24 m** |
| EnemyLaser — bolt orange | 0,24 m | **0,48 m** |
| EnemyLaser — spear orange | 0,11 m | **0,22 m** |
| EnemyLaser — diamètre pulse | 0,40 m | **0,80 m** |
| Pulse Patrol — nouveau tir de démo | — | **diamètre 1,28 m**, trail largeur 0,48 m, 26 m/s, 1 HP, lifetime 6 s, intervalle 2,2 s |
| Heavy — largeur de traînée | 0,20 m | **0,40 m**, noyau de 3,6 m inchangé |
| Autres artilleries — traînée | 0,12 m | **0,24 m**, collisions inchangées |

Les raycasts BlueLaser/EnemyLaser et les sphères physiques d'artillerie restent inchangés. Le pulse de patrouille est activé en phases 3 et 6 ; le PatrolDrone libre conserve son comportement historique, avec un export optionnel `patrol_fire_enabled` désactivé par défaut.

### Validation M11

`tests/validate_guided_demonstration.gd` teste D/boutons/restart, pause et reprise des mêmes agents avec leur poursuite, réglages/RNG/compteurs/caméra, fermeture directe, largeur des tirs, passages physiques du tunnel, cinq directions LINEAR, collisions actives, six phases, routes, rafales, ordre réel des salves, récupération, budgets et retour automatique. Les sept suites historiques M1–M10 restent en FREE par défaut.

```powershell
$godotExe = 'C:\Users\Sora\Desktop\Godot_v4.7.2-stable_win64.exe'
Start-Process -FilePath $godotExe -ArgumentList '--headless','--path','.','--fixed-fps','60','--script','res://tests/validate_guided_demonstration.gd','--log-file','.godot/validate_guided_demonstration_m11_final.log' -WindowStyle Hidden -Wait
```

Pour la vidéo, retirer `--headless` et `--fixed-fps`, puis ajouter `-- --native-video`. Ce test met la fenêtre en plein écran et fixe **le rendu interne à 1920×1080** via le viewport du test, indépendamment du moniteur. Le projet conserve ses paramètres `canvas_items/expand` et le rendu natif responsive M9. Les captures sont de vrais pixels 1080p du moteur, sans redimensionnement après capture. `-- --capture` avec rendu et pas fixe produit aussi des vues rapides des six phases et du panneau FREE ; ce mode ne mesure pas des FPS réels.

Validation finale **Godot 4.7.2, seed 20261012, Intel Arc Graphics, Compatibility OpenGL et MSAA 4×** : huit suites M1–M11 passent, sans erreur ni warning dans les journaux finaux. Le parcours headless suit **100,01 s de scénario** avec un coût moyen de **1,06 ms/tick** (simulation et instrumentation, pas des FPS). Les nœuds reviennent de **412 à 412** après restitution du mode libre ; les mêmes agents, leurs cibles, timers, réglages, caméra, RNG et compteurs sont conservés.

Le rendu complet prend **101,05 s réelles**, pour **100,04 s de phases**, à **98,10 FPS moyens**, minimum sur une fenêtre d'une seconde **76,04 FPS**. Le test est réellement en plein écran sur une surface **4096×2304**, avec un rendu interne vérifié de **1920×1080**. Ce choix appartient au test vidéo ; le projet conserve son viewport natif responsive. Six captures PNG 1080p sont incluses dans la mesure, sans redimensionnement après capture. L'objectif >60 FPS est atteint sur cette machine.

| Phase, rendu réel | Blue vivants / morts | Ennemis verts / rouges / Capital | Astéroïdes max | Projectiles max | Esquives de projectiles | Regroupements locaux |
|---|---:|---:|---:|---:|---:|---:|
| 1 — CHAMP D'ASTÉROÏDES | 15 / 0 | 0 / 0 / 0 | 135 | 0 | 0 | 18 |
| 2 — ASTÉROÏDES DYNAMIQUES | 15 / 0 | 0 / 0 / 0 | 16 | 0 | 0 | 0 |
| 3 — DRONES DE PATROUILLE | 15 / 0 | 4 / 0 / 0 | 3 | 12 | 43 | 0 |
| 4 — INTERCEPTEURS | 15 / 0 | 0 / 4 / 0 | 3 | 24 | 45 | 0 |
| 5 — ARTILLERIE CAPITALE | 15 / 0 | 0 / 0 / 1 | 0 | 19 | 20 | 0 |
| 6 — CONFRONTATION FINALE | 14 / 1 | 4 / 4 / 1 | 72 | 43 | 84 | 2 |

Phase 1 : **130 statiques + cinq LINEAR**, cinq angles et passages physiquement ouverts, translations latérales individuelles jusqu'à **51,33 m**, **15/15 survivants**. Phase 2 : **quatre représentants de chacune des familles DIAGONAL, VERTICAL_SWEEP, CIRCULAR et ARC**, sans ennemi. Phase 3 : **4 routes A/B/C/D terminées**, **32 waypoints sélectionnés**, **45 pulses verts**, avec réaction bleue. Phase 4 : **12 poursuites**, **8 désengagements**, **92 tirs rouges**. Phase 5 : ordre réel vérifié **Heavy → Spread → Arc → Cross → Seeker**, une salve de chaque famille et **20 épisodes d'esquive**.

Finale réelle : **14 survivants, 1 mort(s)**, **10 tirs bleus / 155 tirs hostiles**, **2 activations du regroupement**, dispersion maximale **49,95 m**, finale **36,34 m**. Les nœuds culminent à **2704**, en comptant les entités libres suspendues et le chevauchement bref des suppressions différées. Les projectiles culminent à **43**, les astéroïdes actifs à **135** ; les **360 débris décoratifs** utilisent une seule MultiMesh sans collision.

Le headless termine la finale avec **14 survivants / 1 mort(s)**, tandis que le rendu réel donne les valeurs ci-dessus. Les resets de phase ne sont pas des morts ; ces chiffres ne désignent pas la survie d'un même banc pendant cent secondes continues. Les activations de regroupement et d'esquive décrivent les états des agents, sans prouver un impact certainement évité ni un regroupement complet.

Les six titres et transitions automatiques, l'ordre Capital, D, les boutons, le restart, la reprise d'une poursuite libre en cours et la fermeture directe en GUIDED sont vérifiés. Logs et captures : `.godot/validate_*_m11_final.log`, `.godot/m11_video_final.log`, `.godot/validation/m11_phase_*_video.png` ; ces fichiers restent ignorés par Git. Une seule graine et un parcours de cent secondes ne constituent pas une étude multi-graines ou de plusieurs heures.


Limites : le scénario est calibré sur une graine ; la survie et la dispersion peuvent varier entre rendu réel et headless. Les agents peuvent contourner les parois à l'extérieur des ouvertures, sans route forcée. Une récupération locale n'assure pas un regroupement complet. Le reset de phase sert la présentation et ne constitue pas une survie continue de cent secondes. Les nœuds libres suspendus et les suppressions différées restent inclus dans les comptes de nœuds ; le pic de transition est borné. La mesure FPS concerne le rendu interne 1080p, pas un rendu 4K natif.

La démonstration guidée servira de support au PowerPoint et à l'oral final. **Le PowerPoint n'est pas généré dans ce travail.** Les résultats M10 ci-dessous restent des références historiques du mode libre avant la présentation M11.

## M10 — Capital Artillery Ship

Le quatrième agent est un corps destructible, distinct des chasseurs et intercepteurs. Sa coque procédurale mesure **66 m**, avec un pont central, des plaques de blindage, deux bras latéraux, six batteries, deux lanceurs de salves et **quatre moteurs violets**. Les boîtes physiques couvrent coque, bras, pont et blindage arrière ; les flammes sont visuelles. Groupes : `capital_ships` et `hostile_agents`.

Il observe toutes les **0,25 s** le centre approximatif, la vitesse moyenne, la dispersion et le nombre de survivants. Son RNG personnel découle de `simulation_seed` ; un cycle mélangé comporte les cinq attaques, l'éventail étant privilégié si la dispersion dépasse 40 m. Le choix est fait **une seule fois à OBSERVE → PREPARE**. Il ignore les règles internes des chasseurs.

**ENTRY → OBSERVE → PREPARE → FIRE → COOLDOWN → REPOSITION → OBSERVE**. ENTRY dure 2 s, OBSERVE au moins 1 s, PREPARE **0,8–1,8 s**, FIRE au moins 0,5 s (jusqu'à 1,4 s pour les six tirs croisés), COOLDOWN **3–6 s**. Les lanceurs pulsent et se chargent avant le départ. Une correction locale anticipe les rochers à six secondes ; un obstacle critique à moins de deux secondes fait passer ENTRY/REPOSITION en **AVOIDING**, puis reprend l'état et son timer après 0,6 s de zone sûre. Les balayages physiques empêchent de simplement traverser une roche.

Le Capital accompagne le groupe vers −Z : cible normale **190 m devant**, dérive X/Y lente (3 m/s hors évitement), accélération 4 m/s², correction Z bornée à ±6 m/s autour de la vitesse collective. Il n'est pas téléporté. Après chaque troisième salve, REPOSITION vise **65 m devant**, tient la proximité pendant 10 s, puis retourne vers sa distance normale ; délai de sortie de sécurité 38 s si les obstacles empêchent l'approche. Les distances 120–250 m et 50–90 m sont des zones visées, pas des contraintes imposées par téléportation.

**24 HP**, laser BlueShip **−1 HP**. Le blindage arrière est un point visable du même corps, situé 32 m derrière son centre : au rapprochement, il entre naturellement dans les **44 m** de portée bleue. La portée, le cône de tir et la navigation BlueShip restent inchangés ; aucune poursuite du Capital. À zéro HP : arrêt des attaques, moteurs éteints, six petites explosions, une finale à 2,5 s, disparition à **3,4 s**, compteur ennemi incrémenté une seule fois. Les tirs existants poursuivent leur vol. Remplacement sûr après **25 s de simulation** ; un volume encombré reporte l'apparition.

| Attaque | Nombre / vitesse | Identité et comportement | Dégâts / rayon d'esquive |
|---|---|---|---|
| HEAVY_SHOT | 1 / **27 m/s** | Masse violette, noyau orange, traînée 12 m ; collision sphérique rayon 1,8 m | **2 HP / 10 m** |
| SPREAD | **5 / 30 m/s** | Bolts jaunes/orange ; centre + quatre offsets de 12–24 m autour du groupe | 1 HP / 4 m |
| ARC_SALVO | **4 / 30 m/s** sur la corde | Magenta ; bosse latérale/verticale `24 × sin²(πt/T)`, fin dans la zone prévue | 1 HP / 4 m |
| CROSS_FIRE | **6 / 30 m/s** | Deux lanceurs séparés de 46 m, directions convergentes, traits orange 7 m | 1 HP / 4 m |
| SEEKER_SALVO | **3 / 30 m/s** | Missile rouge avec moteur ; cible choisie au lancement, correction **≤6°/s**, dernière direction si cible perdue | 1 HP / 5 m |

Les projectiles partagent `scripts/artillery_projectile.gd` et les groupes `hostile_projectiles` / `artillery_projectiles`. Ils exposent `velocity`, `damage`, `avoidance_radius`, ont une durée de vie maximale de **14 s**, et balayent leur volume avec [move_and_collide](https://docs.godotengine.org/en/stable/classes/class_physicsbody3d.html#class-physicsbody3d-method-move-and-collide). Ils touchent uniquement les BlueShip et les astéroïdes, qui absorbent aussi les salves. Les tirs courbes ont une vitesse instantanée supérieure à 30 m/s pendant la déviation ; 30 m/s désigne leur progression sur la corde.

Le plafond partagé est **50 projectiles d'artillerie actifs**. Une nouvelle salve est refusée si elle ne tient pas entièrement dans le budget ; il n'existe pas de file de salves infinie. Les historiques de diagnostic du Capital sont bornés à 64 entrées. Les BlueShip lisent le rayon du projectile sans distinction par classe, avec la priorité **collision/obstacle → projectile → séparation critique → flocking/récupération → tir**. Un tir est interdit pendant une esquive critique.

| Niveau | BlueShip au lancement | PatrolDrone | Interceptor | Capital |
|---|---:|---:|---:|---:|
| 1 ★☆☆ | 10 | 1 | 0 | **0** |
| 2 ★★☆ | 10 | 2 | 1 | **0** |
| 3 ★★★ | 10 | 3 | 2 | **1** |
| Mode spectacle | **15** | **5** | **4** | **1** |

Le panneau affiche `Capital Ship [−] 0/1 [+]`. Reset agents efface l'override et reprend la cible du niveau. Le HUD vidéo demeure uniquement le compteur de pertes et les étoiles. La caméra conserve le groupe bleu : lorsqu'un Heavy est préparé et que le Capital est déjà visible avec assez de marge, la cible de cadrage se décale progressivement de **4 m maximum**. Les Heavy/Seeker proches, grosses salves et explosions contribuent modérément à `action_intensity`, au FOV et au roulis borné ; aucun cut ni caméra dédiée.

### Validation M10

`tests/validate_capital_artillery.gd` vérifie les états et leur reprise, seed, cinq salves, arc réellement courbe et endpoint, pas 60/120 Hz sous time_scale 1/2, guidage borné et cible supprimée, esquive Heavy et Seeker, collisions et dégâts des cinq objets, absorption par rocher, lifetime, budget, laser → Capital, destruction unique, délai de remplacement, populations, panneau et spectacle. Les suites M1–M9 restent séparées avec `capital_ships_enabled=false` dans les fixtures anciennes. Le test de preset historique tient compte de la nouvelle consigne de 15 BlueShip.

```powershell
$godotExe = 'C:\Users\Sora\Desktop\Godot_v4.7.2-stable_win64.exe'
Start-Process -FilePath $godotExe -ArgumentList '--headless','--path','.','--fixed-fps','60','--script','res://tests/validate_capital_artillery.gd','--log-file','.godot/validate_capital_artillery_m10_final.log' -WindowStyle Hidden -Wait
```

Pour les essais avec rendu, enlever `--headless` **et `--fixed-fps`**, puis ajouter `-- --native` (spectacle 60 s réelles) ou `-- --long-native` (difficile 180 s réelles). `-- --capture-design`, avec rendu, produit les vues contrôlées du modèle et du panneau. Les journaux, JSON et captures restent dans `.godot/`, ignorés par Git. Les parcours fixes headless comptent des ticks équivalant à 90/60/180 s au rythme physique ; leur exécution est accélérée. Le coût est un temps moyen d'exécution par tick incluant simulation et instrumentation, pas un profiler de CPU isolé ni des FPS.

Résultats **Godot 4.7.2, seed 20261012**, vitesse 1,7×. Difficile démarre directement en MANUEL 3 avec les valeurs par défaut ; spectacle ajoute progressivement les chasseurs manquants. Ordre des salves **H / S / A / C / K = Heavy / Spread / Arc / Cross / Seeker**. Les esquives comptent des épisodes de réaction à tous les projectiles hostiles, sans prouver qu'un impact aurait eu lieu.

| Parcours | Blue vivants / morts | Capital actif / détruit | Salves H/S/A/C/K (total) | Impacts artillerie Blue / rocher | Esquives | Dispersion max → finale (m) |
|---|---:|---:|---|---:|---:|---:|
| Difficile 90 s, headless | 9 / 1 | 1 / 0 | 2/1/1/1/2 (7) | 0 / 2 | 72 | 35,84 → 19,21 |
| Spectacle 60 s, headless | 14 / 1 | 1 / 0 | 1/1/1/1/1 (5) | 0 / 5 | 64 | 66,08 → 37,31 |
| Difficile 180 s, headless | 9 / 1 | 1 / 0 | 3/3/3/2/3 (14) | 0 / 4 | 122 | 58,55 → 52,70 |
| Spectacle 60 s réelles, rendu | 13 / 2 | 1 / 0 | 1/1/1/1/1 (5) | 1 / 2 | 44 | 64,17 → 41,07 |
| Difficile 180 s réelles, rendu | 10 / 0 | 1 / 0 | 3/3/3/2/3 (14) | 1 / 3 | 116 | 42,02 → 21,83 |

| Parcours | Projectiles total max / fin | Artillerie max (plafond 50) | Nœuds max / fin | Coût headless (ms/tick) | FPS moyen / minimum sur 1 s |
|---|---:|---:|---:|---:|---:|
| Difficile 90 s, headless | 19 / 1 | 9 | 1309 / 929 | 1,12 | — |
| Spectacle 60 s, headless | 22 / 7 | 6 | 1493 / 1408 | 1,69 | — |
| Difficile 180 s, headless | 19 / 7 | 9 | 1309 / 1134 | 1,13 | — |
| Spectacle 60 s réelles, rendu | 21 / 8 | 6 | 1456 / 1366 | — | 98,52 / 81,22 |
| Difficile 180 s réelles, rendu | 17 / 4 | 11 | 1424 / 1110 | — | 99,47 / 90,31 |

Le spectacle avec rendu dure **60,08 s réelles**, avec **5 PatrolDrone, 4 Interceptor et 1 Capital** à la fin. Le parcours long dure **180,01 s réelles**, avec **3 drones, 1 intercepteur, 1 Capital**, et **306,09 s de simulation**. Rendu natif **1920×1080, Intel Arc Graphics, Compatibility OpenGL, MSAA 4×, VSync**, sans `--fixed-fps`. Les captures à 20/40/60 s sont incluses dans le coût du spectacle. L'objectif moyen >60 FPS est atteint.

Les nœuds sont échantillonnés toutes les 0,5 s en headless et environ chaque seconde avec rendu ; les projectiles sont suivis à chaque tick. Le parcours long garde un budget stable et des projectiles supprimés, sans erreur, warning ou référence invalide dans les journaux finaux. Aucun Capital n'est détruit dans ces parcours naturels : le test contrôlé valide séparément destruction unique, explosions et respawn 25 s. Une destruction naturelle n'est pas promise.

Le test de vulnérabilité atteint **66,42 m**, avec un pas maximal de **0,174 m**, puis un tir bleu naturel sans poursuite. Le contrôle Heavy prouve l'esquive avec perception et l'impact **−2 HP** sans perception. La dispersion diminue après les perturbations dans plusieurs parcours, mais le spectacle réel termine avec **1 chasseur isolé** et le long avec **0** : le regroupement local ne garantit pas que tous les survivants reviennent.

Les six suites historiques et la suite M10 passent. Journaux finaux : `.godot/validate_*_m10_final.log`, `.godot/m10_native_final.log`, `.godot/m10_native_long_final.log`. Les FPS et les pertes peuvent varier entre rendu et headless ; les résultats ne couvrent pas plusieurs graines ni plusieurs heures.


Limites : anticipation locale à vitesse instantanée pour arcs et guidage ; salves stoppées par les rochers ; faible taux de dégâts possible selon la graine. Le Capital peut manquer son créneau de vulnérabilité si le champ est encombré, et sa destruction n'est pas garantie pendant un parcours normal. Les populations sont des cibles, avec délai après destruction. La récupération bleue reste locale (50 m), donc certaines dispersions ne se résorbent pas. Une seule graine et cette machine ne démontrent pas un équilibrage général ni la performance d'une session de plusieurs heures.

## Lancement

Importer `project.godot` dans **Godot 4.7.2**, puis appuyer sur **F5**. La scène principale est `res://scenes/main.tscn`. Le rendu Compatibility et le MSAA 4× assurent des contours lisibles. Aucun raccourci clavier ne crée de danger. Arrêter avec F8 dans l'éditeur, puis F5 pour recommencer. `config/features` avait déjà été mis à jour en `4.7` par l'éditeur : cette déclaration est conservée, sans migration supplémentaire.

## Caméra et commandes

### Fenêtre et viewport responsive

La taille initiale reste 1280×720, mais **`window/stretch/mode="canvas_items"` et `window/stretch/aspect="expand"`** permettent au rendu 3D de remplir la surface native et au canvas logique de s'étendre quand le ratio change. Les anchors du HUD, des étoiles et des panneaux suivent ces nouveaux bords. Le diagnostic M8 montrait un aspect `keep` : fenêtre 1600×1000, texture 3D seulement 1600×900 ; fenêtre carrée 900×900, texture seulement 900×506. Les quatre tailles 16:9 masquaient ce défaut.

Après correction, la texture rendue a exactement la taille de la fenêtre. `get_visible_rect().size` décrit les **unités logiques de l'UI**, pas les pixels de cette texture : 1280×720 dans les quatre formats 16:9, 1280×800 à 1600×1000, 1280×1280 à 900×900 et 1728×720 à 1920×800. Le ratio caméra suit la surface étendue sans bandes. F11/Alt+Entrée et la maximisation Windows utilisent également toute la surface. La taille et la position précédentes sont restaurées à la sortie du plein écran, y compris le mode maximisé. Cette distinction suit la [documentation multi-résolutions Godot](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html). Dans la fenêtre de jeu intégrée à l'éditeur, utiliser son option **Stretch to Fit** pour laisser aussi le panneau hôte transmettre sa taille.

La caméra démarre en **Suivi** : elle suit le barycentre des survivants et s'éloigne doucement quand le groupe s'étale. **F** passe en **Libre**, une vue orbitale avec un point d'observation déplaçable. La vue reste alors à l'endroit choisi pendant que les agents continuent leur vol. **G** ou **Home / Début** recentre sur le groupe actuel. **C** active **Cinématique** ; un second C revient au Suivi. F permet aussi de reprendre la caméra Libre depuis Cinématique. La souris contrôle seulement le mode Libre.

| Commande | Effet |
|---|---|
| Clic droit maintenu + souris | Orbite autour du point d'observation |
| Molette haut / bas | Zoom avant / arrière, distance limitée à 6–220 m |
| Flèches haut / bas, ou W / Z et S | Pan avant / arrière sur le plan horizontal de la vue |
| Flèches gauche / droite, A / Q pour la gauche | Pan gauche / droite ; D est réservé à la démo |
| PageUp ou E | Monter |
| PageDown | Descendre en Libre |
| G ou Home | Recentrer sur le groupe |
| F | Alterner Suivi / Libre |
| C | Activer Cinématique / revenir au Suivi |
| F11 ou Alt+Entrée | Basculer Fenêtré / Plein écran |
| TAB | Afficher / masquer le panneau de contrôles |
| H | Afficher / masquer l'aide caméra en bas à gauche |
| D | Démarrer / arrêter la démonstration guidée |

Les touches sont définies par des **Input Actions dans `project.godot`**. C est réservé à Cinématique ; Q sert au déplacement à gauche. Le pan vaut 24 m/s en temps réel, indépendamment de la vitesse de simulation. L'aide est visible au lancement. **H puis TAB** laissent uniquement le compteur de pertes et les étoiles pour enregistrer une vidéo. Le plein écran utilise [DisplayServer](https://docs.godotengine.org/en/stable/classes/class_displayserver.html) et restaure le mode, la taille et la position de la fenêtre ; celle-ci reste redimensionnable.

### Caméra cinématique

Les six cadrages sont **CHASE, SIDE_LEFT, SIDE_RIGHT, HIGH, LOW_CLOSE et WIDE**. La séquence alterne arrière, gauche, haut, droite, bas et large, toutes les **6–12 secondes de démonstration**, avec des durées déterministes issues de `simulation_seed`. Les offsets changent par une interpolation douce de **2 s**, complétée par le lissage de la position, de l'orientation (slerp) et du FOV. G/Home reprend CHASE par une transition. Une légère oscillation et un très faible roulis évitent la vue rigide sans orbite permanente.

Le cadrage tient compte des positions bleues et du format du viewport ; WIDE prend le relais au-delà de 45 m de dispersion. `action_intensity` résume tirs, esquives, explosions et hostiles proches pour élargir légèrement le FOV. Une correction d'enveloppe et un raycast sur le déplacement de la caméra limitent l'entrée dans les astéroïdes. Le micro-shake est exporté, **désactivé par défaut**. La caméra n'est pas un agent et ne transmet aucune consigne de trajectoire aux chasseurs.

M9 ajoute une réaction douce à la vitesse moyenne X/Y du groupe : décalage latéral, petite avance/retard de 3,5 m, cible légèrement anticipée et roulis borné à **±4°**. La vitesse de démonstration, l'activité des tirs et le mouvement latéral élargissent progressivement le FOV, plafonné à **68°**. La progression physique reste vers −Z et aucun virage n'est imposé aux agents.

## Contrôles de démonstration M7–M8

Le panneau **Contrôles**, visible au lancement, est placé à droite : largeur **264 px**, marge **18 px**, fond spatial bleu sombre transparent et accent cyan. Il utilise uniquement les nœuds Control Godot standards. **TAB** le masque et le réaffiche. Les étoiles restent visibles dans les deux cas.

| Contrôle | Bornes | Valeur initiale / effet |
|---|---|---|
| Vitesse | 0,5–2,5×, pas 0,1 | **1,7×** ; changement immédiat |
| BlueShip −/+ | 5–20 | 10 ; ajoute ou retire des chasseurs |
| PatrolDrone −/+ | 0–8 | Cible du niveau, puis override explicite |
| Interceptor −/+ | 0–8 | Cible du niveau, puis override explicite |
| Capital Ship −/+ | 0–1 | 0 en niveaux 1/2, 1 en niveau 3 ; override explicite |
| Mouvement | 0,5–2,0, pas 0,1 | **1,2** ; amplitude du wander X/Y/Z |
| Espacement | 0,8–1,4, pas 0,1 | 1,0 ; distances de séparation, seuil critique et confort de cohésion |
| Reset agents | Bouton | Efface les trois overrides ennemis |
| Plein écran | Toggle | Même bascule que F11 |
| Caméra cinématique | Toggle | Synchronisé avec C et F |
| Mode spectacle | Bouton | Manuel 3, vitesse 1,7×, mouvement 1,3, BlueShip 15, verts 5, rouges 4, Capital 1, espacement 1,0 et Cinématique |
| Normal | Bouton | Vitesse 1,7×, mouvement 1,2, populations du niveau courant, espacement 1,0 et Suivi |

Les presets réutilisent les réglages runtime. Ils ne recréent pas la scène et conservent les morts, la distance et le champ. Spectacle demande 15 BlueShip, avec les ajouts progressifs habituels ; Normal conserve ensuite les chasseurs présents. Normal conserve la difficulté courante. HUD, panneau et aide sont ancrés dans le canvas responsive, avec 1280×720 comme référence de taille.

Les étoiles **★☆☆ / ★★☆ / ★★★** représentent toujours `difficulty_level` effectif, avec les étoiles pleines jaunes et les vides gris. Elles changent immédiatement avec les touches 0/1/2/3 et avec les seuils AUTO. Aucun texte « Niveau », « AUTO » ou « MANUEL » ne les accompagne.

### Vitesse et caméra

`simulation_speed_multiplier` utilise **Engine.time_scale** : agents, lasers, délais de poursuite/rafale/remplacement et explosions suivent la même horloge. Les vitesses physiques de base M6 sont conservées. Le taux physique monte par multiples de 60 : **60 Hz jusqu'à 1×, 120 Hz jusqu'à 2×, 180 Hz au-delà**, ce qui conserve un pas de simulation au plus égal à 1/60 s. Les paramètres Engine précédents sont restaurés à la fermeture de la scène. Cette méthode suit les recommandations de la [documentation Engine](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-time-scale).

Le suivi utilise le temps de simulation pour rester fluide ; le pan libre utilise le delta divisé par `time_scale`. Orbite et zoom réagissent directement à la souris. Le panneau consomme ses événements : cliquer un slider/bouton ne déclenche ni orbite ni zoom ; relâcher le clic droit au-dessus du panneau termine aussi une orbite commencée dans l'espace. Les contrôles n'accaparent pas le focus clavier. Aucun paramètre de combat n'est exposé.

### Populations et réglages

Les comptes ennemis affichés sont des **cibles**, pas des statistiques de destruction. `manual_drone_count_override`, `manual_interceptor_count_override` et `manual_capital_count_override` valent **−1** par défaut : utiliser la difficulté. Une valeur **0–8** (ou **0–1** pour le Capital) maintient la population choisie, même après un changement de niveau. **Reset agents** restaure −1 : les populations reprennent les nombres du niveau courant. Les morts, la distance, l'environnement, les BlueShip et les autres sliders restent inchangés.

Les ajouts runtime sont espacés de **0,4 s de simulation**. Les ennemis réutilisent leurs apparitions sûres ; les nouveaux BlueShip apparaissent autour/derrière le groupe, avec contrôle des autres corps et du rayon des rochers. Chaque chasseur reçoit une seed unique, les groupes et les connexions de combat, puis rejoint les règles locales. Une position encombrée retarde l'ajout et provoque une nouvelle tentative.

Une réduction BlueShip retire les excédents **sans explosion ni mort**. Les pertes réelles diminuent le compte restant : elles ne sont **jamais remplacées automatiquement**. `ship_spawn_count` et `ship_retired_count` permettent le bilan **vivants + morts + retraits = créations**. Le nombre initial et toutes les métriques M6 sont conservés.

Mouvement et Espacement sont interpolés sur les chasseurs existants ; les futurs chasseurs reçoivent les valeurs courantes. Mouvement multiplie seulement le wander naturel, sans modifier séparation, cohésion ou collisions. Espacement multiplie les trois distances indiquées, avec des bornes limitées ; il ne change pas les poids des forces ou les hitboxes. Ces contrôles sont des paramètres extérieurs d'expérimentation, pas des perceptions supplémentaires des agents.

Exemple de démonstration : **3**, Interceptor **5**, PatrolDrone **6**, BlueShip **15**, Vitesse **1,8×**, Mouvement **1,5**, puis **H** et **TAB** pour observer la scène.

## Agents et obstacles actuels

- **Type 1 — BlueShip** : `CharacterBody3D`, chasseur spatial original. Le fuselage et les nacelles utilisent chacun un petit **ArrayMesh créé avec SurfaceTool : dix points, seize triangles**, avec un nez effilé en hauteur et en largeur, un dos et un ventre. Les prismes seuls donnaient encore une pointe verticale trop épaisse de profil. Cockpit sombre/cyan surélevé, ailes balayées, pylônes épais et moteurs restent des primitives Godot. Les flammes cyan varient avec la vitesse. Les deux boîtes physiques du M7 restent identiques.
- **Type 2 — PatrolDrone** : `CharacterBody3D`, drone vert avec un corps hexagonal court, un capteur lumineux vert-cyan, de petites ailes, une dérive et deux propulseurs. Il conserve sa patrouille par waypoints et son évitement local. Il devient le premier **agent hostile destructible**, avec **4 HP**, sans poursuite ni tirs ennemis.
- **Type 3 — Interceptor** : chasseur rouge pointu, cockpit sombre, ailes courtes et moteurs orange. Il détecte localement un BlueShip, le poursuit temporairement et tire par rafales, puis se désengage. **4 HP**, primitives Godot uniquement.
- **Obstacle environnemental — SpaceAsteroid** : `AnimatableBody3D` indépendant, avec les mêmes volumes low-poly et formes convexes. Petits : 1–2 m ; moyens : 2–4 m ; grands : 4–7 m de diamètre nominal. La racine physique n'est pas mise à l'échelle. Rotation et trajectoire sont appliquées au pas physique par une seule écriture de transform. Certains restent sans translation. **Les astéroïdes sont des obstacles, pas des agents**, même lorsqu'ils bougent.

### Orientation visuelle du BlueShip

Le nez garde −Z comme direction dominante. Pitch **±8°**, yaw **±10°**, roll **±30°** : le pitch réagit plus lentement, le roll plus vite, puis revient progressivement à plat. La vitesse physique X/Y peut rester importante sans relever le nez de 30°. Ces angles concernent seulement `Visuals` ; ils ne modifient ni les forces SMA ni les collisions. Le marqueur de tir suit le nouveau nez à **Z = −4,55 m**.

## Comportement des chasseurs

Chaque chasseur évalue uniquement les voisins dans son rayon de perception. Les groupes Godot fournissent les candidats ; le filtrage par distance précède tout calcul comportemental. Aucun agent ne reçoit le centre global de l'essaim ou une position assignée.

1. **Wander** : plusieurs sinusoïdes de fréquences différentes font varier X, Y et la vitesse en Z. Le wander longitudinal est renforcé : les chasseurs prennent progressivement de l'avance ou du retard relativement au groupe. Phase, amplitude, fréquence et vitesse de base varient par individu, sans tirage aléatoire à chaque frame.
2. **Séparation** : répulsion douce sous 11 m, renforcée progressivement sous 7 m avec un terme quadratique. Pendant une esquive de projectile, elle cède devant les dangers prioritaires. Une superposition exacte reçoit aussi une correction.
3. **Cohésion** : aucune attraction quand le centre local des voisins est à moins de 12 m ; au-delà, une petite correction limitée ramène vers la même zone. Ce rayon de confort évite de compacter le banc.
4. **Alignement** : correction douce vers leur vitesse moyenne.
5. **Évitement** : anticipation jusqu'à 44 m. La trajectoire actuelle et le couloir avant sont comparés au rayon englobant des rochers perçus. Seules les **trois menaces les plus proches au maximum** contribuent au contournement, avec une priorité décroissante. Les rochers éloignés ou déjà derrière sont ignorés, sauf la mémoire d'une manœuvre en cours jusqu'au dépassement.
6. **Récupération locale** : avec moins de deux voisins dans le rayon normal de 32 m, le chasseur peut attirer doucement sa trajectoire vers le voisin le plus proche visible entre 32 et 50 m. Cette correction aide aussi un duo séparé à retrouver le groupe. Elle n'attire pas davantage son compagnon déjà proche, et cède la priorité à l'évitement.

```gdscript
local_motion = wander \
    + separation * separation_weight \
    + cohesion * cohesion_weight \
    + alignment * alignment_weight \
    + recovery * recovery_weight

avoidance = obstacle_avoidance * avoidance_weight \
    + mobile_avoidance * mobile_avoidance_weight
steering = local_motion * (1.0 - 0.75 * avoidance_priority) + avoidance
# La séparation critique est renforcée, sauf pendant l'esquive prioritaire d'un tir.
```

Ce mélange définit une vitesse souhaitée ; l'accélération limite les changements. La priorité d'évitement varie progressivement avec son intensité, entre 0 et 1. La variation longitudinale est limitée à ±3 m/s autour de la vitesse propre de base (10,5 m/s ±3 %). La composante avant reste toujours négative. X/Y partagent une limite de vitesse latérale. L'orientation et le roulis suivent doucement le mouvement visuel, sans simulation aérodynamique.

L'enum `behavior_state` décrit **NAVIGATION**, **AVOIDANCE** (évitement), **REGROUPING** (regroupement) ou **DESTROYED**. L'évitement prend la priorité descriptive sur le regroupement. Ces états reflètent les forces calculées en continu ; ils ne fixent aucune destination ou place dans une formation. Main utilise le centre du groupe pour l'observation, les statistiques et le placement de l'environnement ; il ne le transmet jamais aux chasseurs comme force de déplacement.

La direction de contournement dans le plan X/Y dépend de la position future du chasseur par rapport au centre du rocher ; si l'obstacle est exactement dans l'axe, une préférence individuelle prend le relais. Huit directions simples sont comparées une seule fois au début de la manœuvre pour favoriser un côté moins encombré par les autres menaces sélectionnées. Une direction par obstacle est **mémorisée jusqu'au dépassement**, ce qui évite les changements rapides gauche/droite. L'intensité dépend du déplacement latéral restant et du temps avant contact. La menace principale ne peut pas être complètement annulée par une correction secondaire opposée. Le rayon englobant, calculé sur les points réels des primitives, sert uniquement à anticiper : la destruction dépend du contact physique.

Les hitboxes des chasseurs sont volontairement plus petites que leurs ailes : fuselage 0,78 × 0,5 × 3,15 m ; ailes centrales 2,8 × 0,16 × 1,25 m, pour une envergure visuelle de 5,6 m. Un effleurement de pointe n'est donc pas fatal ; un contact du corps ou de la partie centrale des ailes reste destructeur. Les collisions restent activées en scénario normal.

`move_and_collide(velocity * delta)` balaie le déplacement. Un contact physique avec un astéroïde **ou un hostile** reste immédiatement fatal. Le chasseur quitte `blue_ships`, émet `died` une seule fois, crée une explosion, puis disparaît. Main retire sa référence et met à jour les vivants/morts. Les tirs ennemis passent par les HP décrits ci-dessous.

### Danger mobile

Un hostile n'est jamais un voisin de flocking : il ne contribue ni à la cohésion, ni à l'alignement, ni à la récupération. BlueShip filtre **`hostile_agents`** dans une portée de **44 m**, puis estime leur approche la plus proche sur **3 s**, à partir des vitesses relatives. Si le passage prédit est trop proche, une correction X/Y de poids **7** commence avant le contact. Le côté choisi est mémorisé pendant la rencontre ; la référence est effacée quand l'hostile disparaît ou sort de portée. Cela couvre le drone vert et l'intercepteur rouge sans sélection de cible par classe.

### Santé et esquive des tirs

BlueShip commence à **3 HP**. Un EnemyLaser retire **1 HP** : 3→2→1→0. Un impact survivable produit un petit flash orange pendant **0,14 s** ; aucune barre ni texte n'est ajouté. À zéro, l'explosion et le compteur de morts bleues ne sont déclenchés qu'une fois.

La perception filtre seulement **`hostile_projectiles`**, dans **32 m**. Elle calcule le temps et la distance d'approche minimale avec la position et la vitesse relatives, sur **2 s**. Un tir entrant dont le passage prévu est à moins de **4 m** déclenche une correction X/Y, de poids **8**. Les tirs éloignés ou divergents sont ignorés. Une mémoire de **0,45 s** conserve le côté et l'état d'esquive brièvement à la frontière du danger ; l'accélération et la vitesse latérale restent limitées. Les références sont nettoyées à l'expiration ou à la suppression des bolts.

Priorité : **collision immédiate > projectile dangereux > séparation critique > flocking/récupération > tir**. La correction de projectile cède devant une correction de collision forte. Le tir bleu est suspendu pendant l'esquive, même si plusieurs directions se compensent. `projectile_avoidance_active`, `projectile_dodge_count` et `projectile_dodge_ticks` restent internes.

## Combat frontal des BlueShip

Le combat est parallèle au déplacement. L'enum `CombatState` contient **NO_TARGET**, **TARGET_VISIBLE** et **COOLDOWN** ; la machine de navigation reste NAVIGATION / AVOIDANCE / REGROUPING / DESTROYED. Aucun état SHOOTING, changement de vitesse, poursuite ou rotation pour viser n'est ajouté.

BlueShip recherche seulement les membres de **`hostile_agents`**, vivants et exposant `take_damage(amount)`. Il sélectionne le plus proche visible dans un cône frontal de **6° de demi-angle**, avec une perception de **60 m**. La portée de tir est limitée à **44 m depuis Muzzle** : une cible peut être visible mais encore trop loin pour tirer. Les astéroïdes et les BlueShip ne sont jamais des cibles.

Le tir est interdit en **AVOIDANCE**, pendant **`projectile_avoidance_active`** et dès qu'un voisin bleu est à moins de **7 m**, même si les forces de voisins symétriques s'annulent. Un raycast depuis le nez vérifie qu'aucun astéroïde ne masque la cible. Le plus proche hostile valide est choisi, vert ou rouge sans préférence spéciale.

Le `Marker3D` **Visuals/Muzzle**, placé à **Z = −4,55 m** devant le nouveau nez, donne le vrai départ du projectile. La direction initiale estime une seule fois le déplacement de la cible pendant le vol, à vitesse constante. Elle doit rester dans le même cône frontal. Le chasseur ne s'oriente pas vers la cible ; après son lancement, le projectile suit une droite sans correction ni guidage.

| Paramètre de combat | Valeur |
|---|---:|
| `combat_enabled` | true, également exporté par Main |
| `combat_detection_radius` | 60 m |
| `firing_range` | 44 m |
| `firing_cone_angle` | 6° de demi-angle, soit 12° au total |
| `fire_cooldown` | 0,7 s, multiplié par un facteur individuel de 0,85 à 1,15 |
| Cooldown effectif | 0,595–0,805 s |

Un générateur séparé, issu d'`individual_seed`, règle la cadence et le décalage initial. Il ne change pas les tirages du wander et ne tire aucun nombre aléatoire par frame.

### BlueLaser et dégâts

`BlueLaser` est un simple Node3D avec un bolt géométrique cyan/blanc emissive : **60 m/s**, **3 s de vie**, **1 dégât**. À chaque pas physique, un raycast balaie tout le déplacement. Le projectile ne traverse donc pas un petit corps entre deux positions successives. Il disparaît au premier impact ou à l'expiration ; il n'a ni guidage, ni particules lourdes.

M8 allonge le trait bleu à **3,8 m**, avec une section fine et une pointe cyan. Les tirs rouges alternent **BOLT** (court/épais), **PULSE** (noyau et traînée) et **SPEAR** (long/fin), selon le compteur de tirs de l'intercepteur. Ces trois variantes conservent les mêmes **45 m/s, 3,5 s de vie et 1 dégât**. Matériaux emissive uniquement, sans nouvelle lumière dynamique. HP, dégâts, portées et cadences restent ceux du M6/M7.

Le masque du raycast vaut **6** : astéroïdes, bit 2, et hostiles, bit 4. Les BlueShip, bit 1, sont ignorés. Un rocher absorbe le bolt **sans dégât ni score**. Un hostile vivant reçoit `take_damage(1)` ; le tir disparaît après un seul impact.

PatrolDrone commence avec `max_health = 4`. À zéro HP par dégâts, il passe en DESTROYED, quitte ses groupes, crée l'explosion existante de dix débris, émet `destroyed` une seule fois puis le signal de cycle de vie `died`, et disparaît. Main ajoute **un ennemi détruit** puis conserve le remplacement M4 après **5 s**. Un retrait hors champ, une réduction de population ou une collision du drone avec un rocher ne rapporte pas de score de tir.

Le contrat hostile reste léger : racine Node3D dans `hostile_agents`, propriété `alive`, méthode `take_damage(amount)` et corps physique sur la couche hostile. Interceptor le réutilise et partage avec PatrolDrone la gestion des dégâts, de l'explosion et des signaux de fin de vie.

## Agent 3 — Interceptor et EnemyLaser

L'intercepteur possède sa propre machine **PATROL → PURSUIT → DISENGAGE → PATROL**, avec **AVOIDING** temporaire et **DESTROYED** terminal. Il perçoit les BlueShip vivants proches, les astéroïdes à 44 m et les corps très proches. Il ne reçoit pas de force de flocking ni de cible globale. PATROL avance vers −Z avec une ondulation X/Y. PURSUIT corrige sa vitesse vers une estimation locale de la cible ; le nez visuel tourne progressivement vers elle, tandis que le corps continue sa translation.

| Paramètre | Valeur par défaut |
|---|---:|
| HP | 4 |
| Vitesse PATROL / latérale maximale / accélération | 9 m/s / 8 m/s / 12 m/s² |
| `target_detection_radius` | 80 m, vivant le plus proche |
| `target_prediction_time` | 0,35 s |
| `pursuit_distance` | 24 m, distance de combat souhaitée |
| `max_pursuit_duration` / `disengage_duration` | 8 s / 4 s |
| `firing_range` / `firing_cone_angle` | 52 m / demi-angle 10° |
| Rafale / intervalle / pause après dernier tir | 3 / 0,2 s / 1,6 s |
| Dispersion initiale des tirs | ±2° sur deux axes, seed individuelle |
| Remplacement / retrait derrière le dernier bleu | 8 s / 140 m |

La poursuite cesse à la limite de temps, à la mort de la cible ou quand elle sort de portée. DISENGAGE avance plus vite et s'écarte latéralement pendant quatre secondes. Un obstacle ou un corps trop proche donne AVOIDING ; la mission reprend quand le danger passe. Le temps de poursuite continue pendant l'évitement. Une petite séparation avec les autres hostiles complète l'évitement des astéroïdes et des BlueShip proches.

L'intercepteur tire **uniquement en PURSUIT**, dans le cône du vrai nez `Visuals/Muzzle`, à portée et avec une ligne de vue libre d'astéroïde. La dispersion est tirée à chaque lancement dans un flux déterministe distinct. Il vise approximativement la position courante ; il n'effectue pas de visée parfaite. Un danger peut interrompre la cadence nominale de la rafale.

**EnemyLaser** : bolt rouge/orange, Node3D, **45 m/s**, **3,5 s**, **1 dégât**, droite sans guidage. Son raycast balaie le déplacement avec le masque **3** : BlueShip et astéroïdes. Les verts et les rouges sont ignorés. Les rochers absorbent les deux couleurs de tir sans modification ni score.

| Niveau effectif | PatrolDrone | Interceptor |
|---|---:|---:|
| 1 — Facile | 1 | 0 |
| 2 — Intermédiaire | 2 | 1 |
| 3 — Difficile | 3 | 2 |

Main maintient les effectifs via les exports `easy_interceptor_count=0`, `intermediate_interceptor_count=1`, `hard_interceptor_count=2`. Une perte rouge attend huit secondes avant remplacement. Les apparitions sont à **115–155 m devant**, **18–38 m latéralement**, avec vérification des rochers, des autres hostiles et d'une distance minimale de **25 m aux BlueShip**. Une baisse de difficulté retire le surplus sans mort ni score. Les populations normales restent celles du M6/M7 ; Mode spectacle utilise des overrides explicites. La caméra suit uniquement les BlueShip.

## Paramètres par défaut

Les paramètres sont exportés dans l'Inspector du nœud racine de `blue_ship.tscn`. Modifier cette scène pour appliquer les réglages à tous les chasseurs créés au lancement.

| Paramètre | Valeur | Effet |
|---|---:|---|
| `forward_speed` | 10,5 m/s | Vitesse avant, variation individuelle ±3 % |
| `max_side_speed` | 9 m/s | Limite combinée en X/Y |
| `acceleration` | 12 m/s² | Lissage de la vitesse |
| `turn_speed` | 3,2 s⁻¹ | Lissage de l'orientation visuelle |
| `max_forward_variation` | 3 m/s | Limite de variation longitudinale |
| `wander_strength` | 2,8 | Oscillation horizontale |
| `vertical_wander_strength` | 2,4 | Oscillation verticale |
| `longitudinal_wander_strength` | 2,6 | Avance/retard relatif en Z |
| `wander_frequency` | 0,7 | Fréquence de base |
| `neighbor_radius` | 32 m | Portée des règles collectives |
| `separation_distance` | 11 m | Début de la séparation douce |
| `critical_separation_distance` | 7 m | Début de la répulsion renforcée |
| `critical_separation_multiplier` | 4 | Amplification quadratique en zone critique |
| `separation_weight` | 9 | Importance de la séparation |
| `cohesion_comfort_radius` | 12 m | Distance au centre local sans attraction |
| `cohesion_weight` | 0,16 | Importance de la cohésion |
| `alignment_weight` | 0,5 | Importance de l'alignement |
| `recovery_radius` | 50 m | Portée locale maximale de récupération |
| `recovery_weight` | 0,8 | Importance de l'attraction de récupération |
| `recovery_speed` | 5 m/s | Amplitude souhaitée avant pondération et limites de vitesse |
| `recovery_neighbor_threshold` | 2 | Récupération si moins de deux voisins normaux et un voisin éloigné visible |
| `obstacle_detection_radius` | 44 m | Portée d'anticipation |
| `obstacle_clearance` | 1,8 m | Marge supplémentaire autour du rocher |
| `avoidance_weight` | 6 | Importance du contournement |
| `max_avoidance_threats` | 3 | Maximum de menaces combinées |
| `mobile_detection_radius` | 44 m | Portée des drones dangereux |
| `mobile_prediction_time` | 3 s | Horizon d'approche relative |
| `mobile_avoidance_weight` | 7 | Importance de l'évitement des drones |

La marge géométrique d'anticipation du chasseur est de 2,5 m, en plus de `obstacle_clearance`. Dans Main : `ship_count = 10`, `initial_ship_spacing = 8,5 m`, `simulation_seed = 20261012`, `camera_follow_speed = 3`, `streaming_enabled = true` et `metrics_update_interval = 0,4 s`. Les positions initiales sont aléatoires avec un espacement minimal. La séparation à 11 m, la zone critique à 7 m et les poids du M2 restent inchangés.

## Agent 2 — Patrouille du drone

Chaque drone possède sa graine et une cible courante. Lorsqu'il atteint le waypoint à 7 m près, ou dépasse son plan Z après une déviation, il passe un tick en **CHANGING_WAYPOINT**, puis choisit une cible **55 m plus loin en Z négatif**. X/Y varient autour d'un couloir défini une seule fois lors de son apparition, avec des écarts de **±38 m et ±24 m**. Main ne déplace ensuite ni le drone ni son couloir. Il n'y a pas de poursuite des chasseurs.

En **PATROL**, il ajuste sa vitesse X/Y pour rejoindre la cible. En **AVOIDING**, il donne la priorité aux astéroïdes locaux, jusqu'à trois menaces, avec une anticipation de 4 s. Un BlueShip à moins de 10 m provoque une correction plus faible, de poids 1,2. Ces perceptions modifient réellement sa trajectoire ; ce n'est pas une animation prédéfinie. Une collision avec un rocher provoque l'état terminal **DESTROYED**, une petite explosion et sa suppression. Lors d'un contact avec un BlueShip, le drone reste robuste et le chasseur peut être détruit.

| Paramètre PatrolDrone | Valeur par défaut |
|---|---:|
| `forward_speed` | 9,2 m/s ; Main alterne 9,2 et 9,8 m/s |
| `forward_variation` | ±1 m/s, oscillation lente |
| `max_side_speed` / `acceleration` | 7 m/s / 10 m/s² |
| `segment_length` / `waypoint_reach_distance` | 55 m / 7 m |
| `patrol_width` / `patrol_height` | 38 m / 24 m |
| `obstacle_detection_radius` / `prediction_time` | 44 m / 4 s |
| `obstacle_clearance` / `avoidance_weight` | 2 m / 6 |
| `ship_safety_radius` / `ship_avoidance_weight` | 10 m / 1,2 |

Main exporte `drones_enabled = true`, `easy_drone_count = 1`, `intermediate_drone_count = 2`, `hard_drone_count = 3`, `drone_spawn_ahead_distance = 100 m`, `drone_replacement_delay = 5 s` et `drone_retire_distance = 120 m`. Une apparition se fait **100 à 145 m devant le chasseur le plus avancé**, avec des offsets X/Y de ±32 / ±18 m et une marge vérifiée vis-à-vis des rochers et des autres drones. Un drone détruit ou retiré à plus de 120 m derrière tous les chasseurs est remplacé après 5 s. Si aucune place sûre n'est trouvée, Main attend et réessaie. La population peut donc temporairement être inférieure à la cible. Les remplacements cessent après la disparition de tous les chasseurs.

Le nombre cible est **1 / 2 / 3** en facile / intermédiaire / difficile, y compris en AUTO. Une baisse de niveau retire les excédents sans score ; les remplacements suivants respectent le niveau actif. La vitesse de patrouille reste celle du M4. Les drones ne participent ni au centre caméra, ni aux mesures d'espacement et de dispersion du groupe bleu.

## Espace élargi

Les spreads du champ passent à **56 m en X et 36 m en Y**. Le centre du pattern utilise 45 % de ces spreads pour les configurations classiques et 25 % pour les nouveaux barrages, puis leurs offsets s'ajoutent. Les waypoints verts gardent ±38 / ±24 m et leurs apparitions restent à 100–145 m devant. Ce sont des distributions de placement, sans mur invisible ni limite imposée aux agents.

Le zoom libre monte à **220 m**. Le cadrage de suivi garde son adaptation à la dispersion et reste centré sur les seuls BlueShip ; un drone éloigné ne déplace pas la caméra.

## Champ continu et difficulté

### Trajectoires d'astéroïdes M9

| Type | Trajectoire |
|---|---|
| `STATIC` | Sans translation, rotation lente conservée |
| `LINEAR` | Segment rectiligne, horizontal ou vertical |
| `DIAGONAL` | Croisement combinant X/Y et un faible mouvement Z |
| `VERTICAL_SWEEP` | Passage dominant de bas en haut ou de haut en bas |
| `CIRCULAR` | Ellipse locale dans XY, XZ, YZ ou un plan incliné |
| `ARC` | Segment avec une courbure sinusoïdale verticale |

Les trajectoires et paramètres utilisent un générateur indépendant issu de `simulation_seed`. Les segments et arcs font des allers-retours bornés, de 12–16 s de simulation par sens ; les ellipses ont une période de 16–24 s. Un délai déclenche le premier passage à proximité de l'arrivée du groupe, plutôt que de traverser trop tôt pendant la préparation lointaine du champ. Il ne s'agit pas de mécanique orbitale réelle.

Proportions cibles : **5 % / 20 % / 42 %** en facile / intermédiaire / difficile. Un quota cumulatif par niveau se rapproche de ces proportions sans dépendre du nettoyage ou du budget vivant : la même graine et la même séquence de configurations conservent les mêmes types et paramètres. Un barrage entier partage son mouvement afin de conserver ses ouvertures ; cela peut créer des variations momentanées des proportions actives. `active_mobile_count` compte les trajectoires programmées, y compris avant leur démarrage ; les validations comptent aussi les rochers effectivement en translation.

[AnimatableBody3D](https://docs.godotengine.org/en/stable/classes/class_animatablebody3d.html) synchronise le déplacement manuel et ses collisions. Les obstacles sont mis à jour avant les agents. BlueShip, PatrolDrone et Interceptor utilisent leur **position et vitesse relatives**, avec une approximation d'approche minimale à court terme. Les huit détours locaux et la mémoire de côté sont conservés ; aucun pathfinder n'est ajouté. Le nettoyage tient compte de toute l'enveloppe de mouvement en Z, pour protéger un rocher susceptible de revenir près d'un retardataire. `moving_asteroids_enabled=false` permet aux fixtures historiques de forcer STATIC.

Ici, `sync_to_physics=false` : le code de mouvement s'exécute déjà dans `_physics_process`, avant les agents. Cela évite une seconde synchronisation qui restaurait une ancienne pose dans le graphe de scène alors que le serveur physique avait reçu la nouvelle. Perception et collision utilisent ainsi la même position. Les tests suivent chaque type pendant 30 s, avec des raycasts et un contrôle de pose à moins d'un millimètre.

Le nœud `Asteroids`, piloté par `scripts/obstacle_field.gd`, renouvelle le champ à chaque pas physique depuis Main. Il prépare des configurations jusqu'à **320 m devant le chasseur le plus avancé**. Leur position X/Y utilise le centre actuel des survivants, avec une variation aléatoire ; la caméra ne participe pas à la génération. La première configuration commence à **55 m** devant. Une configuration est supprimée seulement lorsque toute son enveloppe est à plus de **100 m derrière le dernier survivant**, y compris un retardataire. Les références de menaces et de directions mémorisées sont effacées lors de la sortie d'un obstacle de l'arbre.

Le budget est de **96 astéroïdes actifs maximum**, avec un à seize rochers par configuration et au plus douze nouvelles configurations par appel. Le nombre exact de rochers est réservé avant la création ; un tirage en attente reste conservé si le budget est plein. Les listes gardent uniquement les configurations actives et les collisions restent actives jusqu'à la suppression. Les paramètres du champ sont exportés sur `Main/Asteroids`, dont `horizontal_spread = 56 m`, `vertical_spread = 36 m` et `cinematic_patterns_enabled`. La profondeur des nouveaux barrages s'ajoute à l'espacement de génération pour éviter leur superposition.

| Pattern | Disposition |
|---|---|
| `SINGLE` | Un rocher isolé |
| `OFFSET_PAIR` | Deux rochers décalés en X/Y et en profondeur |
| `HORIZONTAL_PAIR` | Deux rochers côte à côte |
| `VERTICAL_PAIR` | Deux rochers superposés verticalement |
| `STAGGERED_CLUSTER` | Trois rochers répartis sur trois profondeurs |
| `LARGE_WITH_COMPANIONS` | Un gros rocher central et deux petits compagnons décalés |
| `ASTEROID_GATE` | Huit rochers entourent une ouverture centrale large |
| `OFFSET_GATE` | Même porte décalée de 18 m en X et 8 m en Y |
| `DIAGONAL_BARRAGE` | Sept rochers en diagonale, routes ouvertes au-dessus et dessous |
| `DOUBLE_CURTAIN` | Deux portes, gauche puis droite, séparées de 50 m en profondeur |
| `DIVE` | Dix rochers au centre/haut, passage bas ; version inversée alternée |
| `ASTEROID_CANYON` | Deux flancs de rochers à X ±26 m, sur deux profondeurs |

Les patterns occupent un volume limité, avec des côtés ouverts pour une route gauche, droite, haute ou basse. Ils ne forment pas de mur fermé. La géométrie et les collisions des rochers sont celles du M2.

Les nouveaux barrages sont absents en facile. En intermédiaire, seule la porte simple est disponible, avec une probabilité de **1/25**. En difficile, les six nouveaux barrages représentent ensemble **un tiers des tirages**, mélangés aux quatre patterns classiques. Les nouveaux rochers mesurent nominalement 3,5–4,8 m en intermédiaire et 4,8–6,2 m en difficile. Les ouvertures sont des possibilités géométriques : les agents choisissent leurs détours par perception locale, sans route prescrite.

| Niveau | Distance parcourue | Distance entre configurations | Échelle des écarts X/Y (`gap`) | Diamètres nominaux | Patterns autorisés |
|---|---|---:|---:|---|---|
| 1 — Facile | 0 à moins de 500 m | 56 m | 22 m | 1,2–3,7 m | Single, Offset pair |
| 2 — Intermédiaire | 500 à moins de 1 100 m | 44 m + profondeur du barrage | 18 m | 2–5,5 m | Offset pair, Horizontal pair, Vertical pair, Staggered cluster, Gate rare |
| 3 — Difficile | À partir de 1 100 m | 34 m + profondeur du barrage | 14 m | 4–6,5 m ; gros central 5,5–7 m et compagnons 1,2–2,2 m | Quatre classiques et six barrages M8 |

Les paramètres sont `intermediate_distance`, `hard_distance`, `easy_spacing`, `intermediate_spacing`, `hard_spacing`, `easy_gap`, `intermediate_gap` et `hard_gap`. `gap` est l'échelle du gabarit, pas une largeur libre entre surfaces. En AUTO, la difficulté d'une configuration dépend de sa distance en Z depuis l'origine du groupe : le champ plus difficile est préparé devant avant le franchissement du seuil. Le niveau reste une métrique interne.

Le nettoyage protège tous les BlueShip et les hostiles encore actifs, verts et rouges : un rocher ne disparaît pas près d'un agent retardataire.

### Choix de difficulté

| Touche | Mode | Input Action |
|---|---|---|
| **0** | AUTO : niveau selon la distance, seuils 500 / 1 100 m | `difficulty_auto` |
| **1** | MANUEL : Facile | `difficulty_easy` |
| **2** | MANUEL : Intermédiaire | `difficulty_medium` |
| **3** | MANUEL : Difficile | `difficulty_hard` |

Les bindings reconnaissent les chiffres et leur position physique sur la rangée supérieure, y compris en AZERTY. Le mode initial est AUTO (`manual_difficulty = 0`). En MANUEL, toutes les **nouvelles** configurations utilisent le niveau choisi, quelle que soit la distance. Les obstacles existants restent en place : le changement devient visible à mesure que le champ se renouvelle. **0** reprend immédiatement le niveau correspondant à la progression réelle, par exemple 2 à 800 m. La distance continue à s'accumuler en manuel.

La graine **20261012** initialise les chasseurs et un générateur indépendant pour le champ. À graine, paramètres et progression identiques, les patterns, positions, tailles et formes sont reproductibles. La progression mesurée est le déplacement en Z du centre des survivants, conservé sans recul si une mort déplace ce centre.

## HUD

Le HUD principal affiche **Vaisseaux détruits : X** à gauche et **trois étoiles seules** en haut-centre. Le panneau droit contient les six réglages, Reset agents et les outils de présentation M8. L'aide caméra est en bas à gauche. **H puis TAB** masquent les deux panneaux ; le compteur et les étoiles restent visibles. Aucun HP, score, distance ou statistique de combat n'est affiché.

## Architecture

```text
project.godot                 Scène principale, affichage, couches physiques
scenes/main.tscn              Environnement, lumières, caméra, conteneurs, HUD
scenes/demo_controls.tscn     Interface de démonstration, distincte du compteur de morts
scenes/blue_ship.tscn         Racine du chasseur et deux collisions stables
scenes/blue_ship_visuals.tscn Coques profilées et primitives du chasseur
scripts/wedge_hull.gd        Petit mesh fermé : nez, dos, ventre et largeur progressive
scenes/patrol_drone.tscn      Drone vert, primitives, matériaux et collision
scenes/interceptor.tscn       Chasseur rouge, primitives, moteurs orange et collision
scenes/enemy_laser.tscn       Bolt rouge/orange
scenes/blue_laser.tscn        Bolt cyan emissive, sans asset externe
scenes/asteroid.tscn          Obstacle environnemental SpaceAsteroid
scenes/explosion.tscn         Effet visuel temporaire
scripts/main.gd              Initialisation, statistiques, centre d'observation
scripts/demo_controls.gd     Étoiles, sliders, boutons et synchronisation de l'interface
scripts/blue_ship.gd          Perception, règles locales, anticipation, mort
scripts/patrol_drone.gd       Waypoints, perceptions, états et mort du drone
scripts/interceptor.gd        Machine de mission locale, poursuite, rafales et désengagement
scripts/enemy_laser.gd        Balayage, dégâts BlueShip, expiration
scripts/mobile_avoidance.gd   Estimation locale de l'approche relative
scripts/blue_laser.gd         Déplacement, balayage physique, dégâts et expiration
scripts/asteroid.gd           Géométrie procédurale et collisions des rochers
scripts/obstacle_field.gd     Patterns, difficulté, streaming et nettoyage borné
scripts/camera_controller.gd  Suivi, Libre, six plans cinématiques et cadrage
scripts/presentation_window.gd Plein écran et restauration de fenêtre
scripts/space_environment.gd  Trois couches d'étoiles, planètes et lune
scripts/explosion.gd          Animation des débris, puis suppression
materials/*.tres              Bleu, gris clair, cockpit, cyan des propulseurs
materials/nebula.gdshader     Nébuleuse transparente, sans texture externe
tests/validate_simulation.gd  Validation reproductible du milestone
tests/validate_combat.gd      Ciblage, sécurité, dégâts et parcours M5 de 90 s
tests/validate_interceptor.gd FSM, rafales, santé, esquive, populations, parcours M6
tests/validate_demo_controls.gd UI, overrides, spawns, temps, caméra et démonstrations M7
tests/historical_fixture.gd  Profil M1–M7 pour isoler les régressions SMA/combat
tests/validate_cinematic.gd  Caméra, barrages, presets, rendu et captures M8
tests/validate_dynamic_space.gd Viewport, orientation, mouvements, anticipation et spectacle M9
```

Les 650 étoiles restent distribuées en trois couches : lointaine (62 %), intermédiaire (30 %) et proche (8 %). Le lointain conserve sa parallaxe naturelle ; les deux couches proches dérivent aussi pour accentuer le défilement. **48 streaks fins en MultiMesh** s'allongent légèrement avec le rythme, sans effet hyperspace massif. Trois planètes, une lune, deux nébuleuses violette/cyan, une bande de galaxie, 120 étoiles d'amas et un soleil emissive forment un horizon lointain sans collision ni lumière dynamique supplémentaire. Cet horizon suit la progression Z pour rester lointain, avec une faible parallaxe X/Y. Aucun asset externe, aucune particule lourde. La caméra conserve son dernier centre après la dernière mort.

### Groupes, signaux et couches

- Groupes : `blue_ships`, `patrol_drones`, `interceptors`, `hostile_agents`, `asteroids`, `blue_lasers`, `hostile_projectiles` et `explosions` (effets temporaires). Seuls les verts appartiennent à `patrol_drones` ; verts et rouges appartiennent à `hostile_agents`.
- Signaux : morts bleues, dégâts/destructions hostiles, tirs et impacts des deux factions, début d'esquive. Main conserve les compteurs sans stocker de projectile supprimé.
- BlueShip : couche **1** (bit 1), masque **6** (astéroïdes et hostiles). PatrolDrone et Interceptor : couche **3** (bit 4), masque **2**. Astéroïdes : couche **2** (bit 2), masque **0**. BlueLaser raycast **6**, EnemyLaser raycast **3** ; les projectiles n'ont pas de corps physique.
- Les chasseurs se séparent localement sans collision physique entre eux. Leur balayage détecte les rochers et les drones. Le drone ne se bloque pas physiquement sur un BlueShip ; sa correction locale assure l'évitement réciproque, et un contact détecté par le chasseur reste fatal pour celui-ci.
- Le HUD conserve « Vaisseaux détruits : X » après la dernière mort bleue. La caméra conserve alors son centre.

## Validation

```powershell
& 'CHEMIN\Godot.exe' --headless --path . --editor --import
& 'CHEMIN\Godot.exe' --headless --path . --fixed-fps 60 --script res://tests/validate_simulation.gd
& 'CHEMIN\Godot.exe' --headless --path . --fixed-fps 60 --script res://tests/validate_combat.gd
& 'CHEMIN\Godot.exe' --headless --path . --fixed-fps 60 --script res://tests/validate_interceptor.gd
& 'CHEMIN\Godot.exe' --headless --path . --fixed-fps 60 --script res://tests/validate_demo_controls.gd
& 'CHEMIN\Godot.exe' --headless --path . --fixed-fps 60 --script res://tests/validate_cinematic.gd
& 'CHEMIN\Godot.exe' --headless --path . --fixed-fps 60 --script res://tests/validate_dynamic_space.gd
```

La première commande importe les scènes et vérifie le parsing avec les warnings GDScript traités comme erreurs. Les suites historiques utilisent `HistoricalFixture` : décor M1–M7 sans les barrages M8, spreads 38/26 m, plafond 72 et mouvement 1,0. Les trois premières forcent la vitesse 1,0 à 60 Hz ; M7 conserve son profil 1,5× et ses réglages runtime. Cela isole les régressions SMA/combat de la nouvelle mise en scène. La suite M8 exerce le nouveau décor et les nouvelles valeurs. `--fixed-fps 60` exécute ces tests aussi vite que possible ; il ne mesure pas les FPS graphiques.

Validation historique M5 avec **Godot 4.7.2 stable** le 12 octobre 2026, graine **20261012**, pas fixe de 1/60 s. Les résultats M6 ci-dessous ont été mesurés le 13 octobre : suites sans warning ni erreur, codes de sortie 0.

### Validation M9 — 13 octobre 2026

Les suites M1–M8 gardent leurs scénarios de référence, avec `moving_asteroids_enabled=false`. La suite M9 exerce les nouvelles trajectoires, y compris leurs retours et orbites sur **30 s par type**, avec **30 raycasts physiques** et une pose conforme à la trajectoire à moins d'un millimètre. Le double rideau conserve ses passages pendant 16 s de mouvement et se nettoie correctement. Un croisement convergent est anticipé à plus de 20 m et évité avec **7,13 m** de translation latérale ; sans perception, il produit une collision physique, une mort unique et un rocher intact.

Le pitch mesuré atteint **7,993°** pour une vitesse verticale imposée de 25 m/s. Un essai de navigation physique à wander vertical renforcé parcourt **18,75 m en 4 s**, atteint **9 m/s en Y** et reste sous 8° de pitch. Deux parcours de dix secondes avec orientation visuelle normale ou neutralisée donnent les mêmes positions et vitesses à **0,000000 m** près. Le modèle est capturé de dessus, de trois-quarts, de dessous et en montée.

Deux séries de mille tirages par niveau donnent les mêmes signatures ; les parts mobiles échantillonnées sont **4,8 % / 20,2 % / 43,5 %**. En production, **648 signatures** restent identiques malgré un nettoyage retardé et des blocages au budget. Le quota de génération conserve ainsi les types indépendamment du rythme de nettoyage. Les positions globales et dates de départ dépendent naturellement du parcours du groupe.

Avec rendu natif, les fenêtres **800×450, 1280×720, 1600×900 et 1920×1080** sont vérifiées, ainsi que 1600×1000, 900×900 et 1920×800. Les textures 3D remplissent exactement les fenêtres ; l'aspect de projection de la caméra correspond au ratio réel et les panneaux suivent les bords. Maximisation, F11 aller-retour, Alt+Entrée et retour au mode maximisé passent sur Windows. Les captures et mesures distinguent pixels de rendu et unités logiques du canvas.

Commandes supplémentaires, toujours avec `res://tests/validate_dynamic_space.gd` : `--headless --fixed-fps 60 -- --unit-only` pour les scénarios contrôlés ; **sans `--headless`**, `--fixed-fps 60 -- --capture-native` pour les résolutions et angles du modèle ; **sans `--headless` et sans `--fixed-fps`**, `-- --render-spectacle` pour **60 secondes réelles à 1920×1080**, depuis AUTO puis application du preset, H/TAB masqués. Le benchmark graphique comprend des captures à 20/40/60 s. Les FPS minimum sont des moyennes sur des fenêtres d'une seconde, pas le temps du pire frame. Les journaux, images et trois JSON `.godot/m9_metrics.json`, `m9_native.json` et `m9_graphics.json` restent ignorés par Git.

Graine `20261012`, collisions actives, vitesse 1,7×. Le parcours normal utilise Mouvement 1,2 et Manuel 3 dès l'initialisation ; Mode spectacle part d'AUTO puis applique le preset runtime sans reset :

| Mesure | Niveau 3 Cinématique, 90 s équivalentes headless | Spectacle, 60 s équivalentes headless | Spectacle, 60,078 s réelles avec rendu |
|---|---:|---:|---:|
| Temps simulé observé | 152,99 s | 101,99 s | 102,12 s |
| BlueShip vivants / morts | 10 / 0 | 10 / 0 | 10 / 0 |
| Verts / rouges actifs | 3 / 2 | 5 / 4 | 5 / 4 |
| Astéroïdes maximum / finaux | 89 / 63 | 77 / 70 | 77 / 70 |
| Trajectoires mobiles maximum / finales | 39 / 26 | 35 / 29 | 35 / 29 |
| Rochers effectivement en translation, maximum échantillonné | 29 | 22 | 22 |
| Activations d'anticipation mobile / ticks-agent | 61 / 13 393 | 31 / 7 667 | 36 / 8 510 |
| Tirs bleus / rouges | 14 / 157 | 7 / 96 | 6 / 137 |
| Esquives de projectiles activées | 47 | 31 | 58 |
| Projectiles simultanés maximum | 12 | 15 | 16 |
| Nœuds maximum échantillonnés | 1 337 | 1 261 | 1 291 |
| Dispersion maximale / finale | 44,93 / 41,70 m | 47,56 / 27,61 m | 50,01 / 38,78 m |
| Espacement final moyen | 14,77 m | 15,44 m | 14,44 m |
| Isolés à la fin | 0 | 0 | 1 |
| Épisodes de regroupement échantillonnés | 4 | 1 | 8 |
| Changements de plan programmés | 10 | 6 | 6 |
| Centres dans le cadre, échantillons | 99,94 % | 99,88 % | 99,90 % |
| Coût moyen headless par pas physique | 1,26 ms | 1,16 ms | — |
| FPS graphiques moyens / minimum sur 1 s | — | — | **99,27 / 92,95** |

Le parcours Suivi de 90 s donne les mêmes résultats physiques que Cinématique, avec 1,43 ms/pas sur son relevé CPU. Les six types apparaissent dans tous ces parcours. Les proportions mobiles programmées finales sont proches de 42 %, mais les départs différés expliquent la différence avec les rochers effectivement en translation. La dispersion peut encore augmenter pendant un barrage : le regroupement complet n'est pas garanti. Les tirs et réactions sont des compteurs de comportement, pas une preuve de collisions évitées.

Le rendu est mesuré en **OpenGL Compatibility, MSAA 4×, Intel Arc, VSync active**, avec les captures incluses dans les 60 s. L'objectif >60 FPS passe sur cet essai. Headless et rendu sont des mesures distinctes : cadence de rendu, démarrage de la scène et perturbations physiques peuvent modifier les trajectoires émergentes ; les types et paramètres générés restent reproductibles. Les cinq suites historiques complètes passent également, sans erreur ni warning GDScript.

### Référence historique M8 — 13 octobre 2026

Les cinq suites complètes passent sans erreur, avec leurs scénarios contrôlés et parcours longs. M8 vérifie C/F, H/TAB, presets sans reset, bindings F11/Alt+Entrée, variantes de lasers et budget du champ. Deux essais contrôlés de 90 s donnent la même séquence de plans ; les trajectoires des agents en Suivi et Cinématique ont un écart maximal de **0,000000 m**. Le streaming sur 8,4 km artificiels exerce les dix patterns difficiles, génère/supprime **223 / 210 configurations** et atteint au plus **90 astéroïdes**, sous le budget 96.

Seed `20261012`, niveau manuel 3, collisions actives, 120 pas physiques par seconde de démonstration, exécution accélérée headless :

| Mesure | Cinématique, 90 s | Mode spectacle, 60 s |
|---|---:|---:|
| Vitesse / Mouvement | 1,7× / 1,25 | 1,7× / 1,3 |
| Temps simulé | 153 s | 102 s |
| BlueShip vivants / morts | 10 / 0 | 10 / 0 |
| Verts / rouges actifs | 3 / 2 | 5 / 4 |
| Verts / rouges détruits par tir | 1 / 1 | 0 / 0 |
| Tirs bleus / impacts hostiles | 21 / 16 | 17 / 8 |
| Tirs rouges / impacts bleus | 127 / 1 | 102 / 0 |
| Activations d'esquive | 43 | 35 |
| Projectiles / astéroïdes maximum | 12 / 77 | 18 / 75 |
| Nœuds maximum échantillonnés | 1 207 | 1 232 |
| Dispersion maximale / finale | 39,16 / 37,01 m | 39,65 / 34,53 m |
| Espacement final moyen | 15,33 m | 13,39 m |
| Changements de plan | 10 | 6 |
| Centres bleus dans le cadre, échantillons | 100 % | 100 % |
| Déplacement caméra relatif maximum par frame | 1,095 m | 1,109 m |
| Marge minimale caméra / enveloppe d'astéroïde, échantillons | 0,80 m | 1,21 m |
| Coût headless moyen par pas | 0,91 ms | 1,07 ms |

Les marges de cadrage incluent une réserve autour des centres, mais le test ne prouve pas que tous les sommets du modèle sont toujours visibles. Le déplacement caméra relatif soustrait le déplacement du barycentre ; aucune téléportation n'est observée. Les coûts CPU incluent les vérifications de test et ne représentent pas les FPS de rendu.

Chaque barrage est également joué seul pendant **30 s de simulation**, avec dix chasseurs initialement étalés :

| Barrage | Vivants / morts | Directions de détour observées | Dispersion maximale / finale | Isolés finaux |
|---|---:|---:|---:|---:|
| ASTEROID_GATE | 10 / 0 | 3 | 28,53 / 18,36 m | 0 |
| OFFSET_GATE | 10 / 0 | 4 | 29,47 / 20,61 m | 0 |
| DIAGONAL_BARRAGE | 10 / 0 | 4 | 30,94 / 21,63 m | 0 |
| DOUBLE_CURTAIN | 10 / 0 | 4 | 24,92 / 21,75 m | 0 |
| DIVE | 9 / 1 | 4 | 34,92 / 21,37 m | 0 |
| ASTEROID_CANYON | 10 / 0 | 4 | 34,76 / 22,79 m | 0 |
| DIVE inversé | 10 / 0 | 4 | 28,67 / 18,50 m | 0 |

Les points de passage ont au moins **15,10 m** libres après soustraction de l'enveloppe du rocher et de la marge du chasseur. Les réactions d'évitement et la récupération locale sont observées ; les ouvertures ne garantissent pas la route choisie ni la survie. Les catégories de directions indiquent les signes X/Y des corrections, pas un nombre de trajectoires planifiées.

Avec rendu natif, **1280×720, 1920×1080 et 800×450**, F11 aller-retour, Alt+Entrée, bouton plein écran et H/TAB passent. Les captures montrent les deux panneaux, le HUD vidéo et le BlueShip en gros plan. La comparaison native de **12 s par vitesse**, à 1,7× puis 1,8×, conserve dix survivants et change de plan ; **1,7×** est retenu pour une lecture légèrement plus posée. Une série Mode spectacle de 60 s avec rendu vérifie aussi les six plans et les tirs.

Pour reproduire les captures, lancer `validate_cinematic.gd` **sans `--headless`**, avec `--fixed-fps 60 -- --capture-native`, `-- --capture-pace` ou `-- --capture-action`. Pour mesurer le rendu, lancer **sans `--headless` et sans `--fixed-fps`**, avec `-- --render-benchmark` : 3 s de chauffe puis 12 s de temps réel, résolution 1920×1080, Mode spectacle, H/TAB masqués, VSync active, OpenGL Compatibility sur Intel Arc. Images et métriques restent dans `.godot/validation/`, `.godot/m8_metrics.json` et `.godot/m8_graphics.json`, ignorés par Git.

Sur cette machine, cet échantillon graphique mesure **99,6 FPS moyens**, environ 100 FPS à la fin, avec dix survivants et 65 astéroïdes actifs. Il s'agit d'une fenêtre courte de rendu réel, pas d'une garantie sur toute la vidéo de 90 s ou sur une autre machine.

### Référence historique M7 — 13 octobre 2026

Les contrôles sont testés par leurs signaux et par des événements clavier/souris injectés dans le viewport. Le test UI a également été exécuté avec le vrai rendu OpenGL. Il couvre les étoiles 1/2/3, les transitions AUTO, TAB, les vitesses **0,5/1/1,5/2/2,5**, l'indépendance du pan, l'absence d'orbite/zoom sur l'UI, les ajouts **10→15**, retraits **15→8**, les overrides **verts 3→6 / rouges 2→5**, leurs bornes et leur reset. Les retraits n'ajoutent aucun décès, explosion ou score ; une mort réelle n'est pas remplacée. Les nouvelles créations reçoivent aussi les réglages Mouvement et Espacement courants.

Avec dix chasseurs et la difficulté 3 pendant 30 s, Mouvement **0,5** donne environ **1,07 m/s** de vitesse latérale moyenne, contre **4,15 m/s** à **2,0**, avec dix survivants dans les deux cas. Le slider est appliqué à l'essaim existant avec interpolation. Les seuils critiques changent effectivement avec Espacement **0,8 / 1,4**, sans modification des forces ou des collisions.

La comparaison rendue de **1,35× et 1,5×** sur douze secondes de démonstration parcourt respectivement **171,27 m et 190,37 m**. **1,5×** est retenu pour un rythme plus franc en conservant une vue lisible, le pan et les vitesses relatives M6.

Les durées suivantes sont des **secondes de démonstration équivalentes en temps réel**, exécutées aussi vite que possible en headless : 90 s à 1,5× correspondent à **135 s de simulation**, 60 s à 1,8× à **108 s**. La scène intense inclut l'arrivée progressive des agents. Seed `20261012`, 120 pas physiques par seconde de démonstration, panneaux visibles, collisions actives :

| Mesure | Difficile, défaut, 90 s | Démonstration intense, 60 s |
|---|---:|---:|
| Vitesse / Mouvement / Espacement | 1,5 / 1,0 / 1,0 | 1,8 / 1,5 / 1,0 |
| BlueShip vivants / morts | 10 / 0 | 15 / 0 |
| Verts actifs / rouges actifs | 3 / 2 | 6 / 5 |
| Verts / rouges détruits par tir | 1 / 2 | 3 / 1 |
| BlueShip / verts / rouges créés au total | 10 / 4 / 4 | 15 / 9 / 6 |
| Tirs bleus / impacts hostiles | 25 / 18 | 27 / 22 |
| Tirs rouges / impacts bleus | 81 / 0 | 166 / 0 |
| Activations d'esquive / ticks-agent | 34 / 1 705 | 57 / 2 440 |
| Distance | 1 426,96 m | 1 126,81 m |
| Voisin le plus proche, moyenne temporelle | 11,58 m | 13,85 m |
| Minimum ponctuel de paire | 6,00 m | 4,86 m |
| Dispersion maximale / finale | 29,45 / 19,06 m | 67,31 / 47,30 m |
| Astéroïdes actifs maximum | 38 | 43 |
| Projectiles simultanés maximum | 13 | 21 |
| Nœuds maximum échantillonnés | 720 | 954 |
| Coût headless moyen par pas physique | environ 0,67 ms | environ 1,18 ms |

Les coûts incluent la boucle de validation, dépendent de la machine et **ne représentent pas les FPS graphiques**. Les extrema de distances et de nœuds sont échantillonnés, et les activations d'esquive ne prouvent pas autant d'impacts évités. Aucun impact rouge n'est observé ici ; la scène intense s'étale davantage et la survie sur d'autres graines n'est pas garantie. Les trois suites historiques restent valides à vitesse 1,0, y compris leurs parcours de 90 et 300 s.

Pour les captures, lancer `validate_demo_controls.gd` avec rendu et `-- --capture-demo` ; ajouter `--speed-135` pour comparer 1,35×. Les images dans `.godot/validation/` montrent le panneau, le HUD après TAB et une fenêtre **800×450**. `-- --ui-only` exécute seulement les contrôles des étoiles, de vitesse et d'interaction souris/caméra. Les métriques JSON sont enregistrées dans `.godot/m7_metrics.json` ; logs et images restent ignorés par Git.

### Référence historique M6 — 13 octobre 2026

Godot 4.7.2, seed **20261012**, pas fixe 1/60 s, scène complète avec collisions actives. `validate_interceptor.gd` vérifie la FSM, la perte de cible, l'évitement/reprise, la rafale, le cône, la ligne de vue, les trois impacts rouges, le flash, l'esquive et la suspension/reprise des tirs bleus. Les scénarios contrôlés détruisent **un vert et un rouge par huit lasers bleus**, et tuent un BlueShip par **trois lasers rouges** : compteurs et signaux uniques, rochers intacts, factions sans friendly fire, expiration et références nettoyées. La difficulté 1/2/3, le remplacement à huit secondes et le retrait sans score passent. Les suites historiques navigation/caméra et combat passent également.

| Mesure | AUTO 90 s | MANUEL 3 90 s | MANUEL 3 300 s |
|---|---:|---:|---:|
| BlueShip vivants / morts | 10 / 0 | 10 / 0 | 10 / 0 |
| Distance / niveau final | 949,21 m / 2 | 949,97 m / 3 | 3 170,25 m / 3 |
| Verts actifs / détruits par tir | 2 / 1 | 3 / 0 | 3 / 0 |
| Rouges actifs / détruits par tir | 1 / 0 | 2 / 0 | 2 / 0 |
| Verts générés / retirés sans score | 3 / 0 | 3 / 0 | 5 / 2 |
| Rouges générés / retirés sans score | 1 / 0 | 2 / 0 | 2 / 0 |
| Tirs bleus / impacts hostiles | 4 / 4 | 6 / 5 | 9 / 8 |
| Tirs rouges / impacts bleus | 0 / 0 | 46 / 0 | 362 / 0 |
| Activations d'esquive / ticks-agent actifs | 0 / 0 | 17 / 628 | 85 / 3 047 |
| Poursuites / désengagements observés | 0 / 0 | 9 / 8 | 45 / 43 |
| Voisin le plus proche, moyenne temporelle | 10,96 m | 11,68 m | 11,81 m |
| Espacement final / minimum ponctuel de paire | 9,89 / 5,94 m | 11,27 / 5,24 m | 10,79 / 2,78 m |
| Dispersion maximale / finale | 23,92 / 17,47 m | 29,41 / 23,21 m | 31,05 / 19,67 m |
| Isolés à la fin | 0 | 0 | 0 |
| Astéroïdes maximum / finaux | 28 / 25 | 38 / 32 | 44 / 43 |
| Projectiles simultanés maximum | 1 | 12 | 12 |
| Nœuds maximum échantillonnés | 560 | 678 | 757 |
| Temps headless par tick, fenêtre 60–90 s | 0,572 ms | 0,768 ms | 0,759 ms |
| Temps headless par tick, dernière fenêtre de 30 s | 0,572 ms | 0,768 ms | 0,825 ms |

Les moyennes d'espacement sont échantillonnées à 5 Hz après la première seconde. Le minimum de paire et les nœuds sont également échantillonnés ; ils peuvent manquer un événement plus bref. Les activations d'esquive comptent des entrées dans le comportement, pouvant concerner plusieurs BlueShip ou plusieurs tirs d'une rafale : elles ne prouvent pas autant de collisions évitées. Les ticks-agent additionnent les pas physiques des chasseurs en esquive.

Le test long génère au total **10 BlueShip + 5 verts + 2 rouges**, avec **aucune mort** et deux retraits verts sans score. Aucun rouge ne touche un bleu sur ces parcours ; le réglage produit donc surtout une perturbation et des esquives sur cette graine. En AUTO 90 s, le premier rouge apparaît au niveau 2 mais ne rejoint pas encore la portée de poursuite. Les tests contrôlés confirment les impacts et destructions, sans les présenter comme des événements du parcours normal. Le rapprochement à **2,78 m** après cinq minutes montre que la séparation n'est pas une garantie géométrique.

Ces mesures CPU incluent la boucle de test et les traitements headless de cette machine ; **elles ne sont pas des FPS graphiques**. Aucun essai de plusieurs heures ni étude multi-seeds n'est réalisé. Les logs et les métriques JSON sont dans `.godot/`, ignoré par Git. Pour le rendu : lancer le script sans `--headless`, avec `-- --capture-m6` ; `.godot/validation/m6_preview.png` montre une fixture avec les trois agents, un bolt orange et un flash survivable, avec le seul compteur de morts bleues dans le HUD.

### Référence historique M5 — test principal MANUEL 3

Godot 4.7.2, seed **20261012**, pas fixe de 1/60 s. Les deux parcours gardent les paramètres de jeu par défaut, avec uniquement le mode de difficulté différent.

| Mesure, 90 s | MANUEL 3 | AUTO |
|---|---:|---:|
| BlueShip vivants / morts | 10 / 0 | 10 / 0 |
| Distance parcourue | 950,12 m | 949,21 m |
| Difficulté finale | 3 | 2 |
| Drones actifs / créés au total | 3 / 5 | 2 / 3 |
| Drones détruits par tirs | 2 | 1 |
| Tirs / impacts hostiles | 9 / 8 | 4 / 4 |
| Réussite approximative, impacts/tirs | 88,89 % | 100,00 % |
| Astéroïdes / lasers actifs maximum | 38 / 2 | 28 / 1 |
| Espacement temporel moyen | 11,66 m | 10,96 m |
| Espacement final | 9,77 m | 9,89 m |
| Minimum ponctuel entre deux voisins | 6,09 m | 5,85 m |
| Dispersion maximale / finale | 35,00 / 19,04 m | 23,92 / 17,47 m |
| Agents distincts isolés observés | 0 | 0 |

Ces taux portent sur peu de tirs et peuvent inclure un tir encore en vol à la fin du parcours. Ils ne garantissent pas la même précision pour d'autres graines ou des manœuvres plus brusques.

Les tests contrôlés valident le ciblage frontal, les portées 60 / 44 m, le refus des amis et des rochers, la priorité AVOIDANCE et séparation critique, la ligne de vue et le départ depuis Muzzle. **Quatre tirs font quatre impacts**, enlèvent les quatre HP, produisent une explosion, un seul signal, **score +1**, aucune référence invalide et le remplacement après 5 s. Le laser ignore un BlueShip, s'arrête sur un petit astéroïde sans le modifier, et expire proprement. Un stress à 600 m/s vérifie le balayage ; cette vitesse est réservée à la fixture.

Une comparaison contrôlée avec un wander doux et une cible à HP élevés produit **neuf tirs** et un écart de trajectoire **0,000000 m** entre combat activé et désactivé. Les fixtures isolent la décision de tir ; elles ne modifient pas les paramètres des parcours normaux de 90 s. Les cooldowns et la population 1/2/3, y compris après une baisse de difficulté pendant un remplacement, passent aussi.

Les tests de navigation, caméra, regroupement et streaming restent valides. Le parcours AUTO de **300 s** atteint **3 164,92 m**, avec **8 BlueShip vivants, 2 morts**, niveau 3, **3 drones actifs**, au plus **47 astéroïdes** et **684 nœuds**. La survie prolongée n'est pas garantie.

### Référence historique M4

| Mesure, 90 s | AUTO | MANUEL 3 dès le départ |
|---|---:|---:|
| BlueShip survivants / morts | 10 / 0 | 10 / 0 |
| Distance parcourue | 948,98 m | 947,74 m |
| Difficulté effective finale | 2 | 3 |
| Drones actifs / détruits | 2 / 0 | 2 / 0 |
| Astéroïdes actifs maximum | 29 | 38 |
| Ticks-agent avec anticipation mobile | 432 | 231 |

En AUTO : espacement temporel moyen **10,96 m**, minimum ponctuel **6,71 m**, dispersion maximale **23,96 m**, **aucun agent isolé**, configurations créées/supprimées **27 / 15**. En MANUEL 3 : espacement final **11,26 m**, minimum des moyennes échantillonnées **9,79 m**, dispersion finale **22,89 m**. Ces dernières mesures ne sont pas le minimum de toutes les paires ni la dispersion maximale du parcours.

La patrouille sans obstacle sélectionne **quatre waypoints en 20 s**, avec des excursions X/Y/Z de **13,30 / 16,81 / 184,10 m**. Deux parcours de même graine sont identiques ; une graine différente change la route. Les tests vérifient les états, les perceptions limitées, l'exclusion des drones du flocking et des statistiques, l'évitement d'un rocher (excursion **6,74 m**) et une réaction à un BlueShip proche.

Le croisement contrôlé est anticipé avant **1,5 s** : distance minimale **6,49 m**, excursion verticale **6,50 m**, chasseur vivant. Le stress sans perception mobile produit une collision réelle, **un BlueShip détruit**, un drone intact, un seul signal et un compteur mort correct. Le stress drone/astéroïde vérifie l'explosion et le remplacement après 5 s ; un drone très loin derrière est également retiré puis remplacé. Les événements clavier 1/2/3 puis 0 valident les nouveaux patterns, la conservation des obstacles existants et le HUD.

Le test AUTO de **300 s** atteint **3 168,16 m**, niveau 3, avec **9 BlueShip vivants, 1 mort** et **2 drones actifs**. Aucun drone n'est détruit ; **un est retiré**, et **trois sont créés au total**. Le champ génère **92 configurations**, en supprime **76**, compte **36 astéroïdes à la fin**, **46 au maximum** et **44 au maximum après 180 s**. Le maximum total atteint **688 nœuds**. Le coût moyen par tick headless reste autour de **0,54 ms** sur les deux fenêtres finales ; il ne mesure pas les FPS de rendu. Le lancement principal, le rendu OpenGL, le modèle vert en gros plan et le HUD sont vérifiés.

### Référence historique M3

Les résultats ci-dessous ont été mesurés avant l'ajout des drones, lors du M3.

| Mesure | Scénario normal M3, 90 s |
|---|---:|
| Survivants / morts | 10 / 0 |
| Distance parcourue / difficulté finale | 949,02 m / niveau 2 |
| Voisin le plus proche en moyenne | 11,04 m |
| Rapprochement minimal ponctuel | 6,71 m |
| Dispersion maximale observée | 23,96 m |
| Agents distincts isolés / durée maximale d'isolement | 0 / 0 s |
| Astéroïdes actifs maximum | 29 |
| Configurations générées / supprimées | 27 / 16 |

La moyenne porte sur les distances au voisin le plus proche, échantillonnées après la première seconde ; elle ne représente pas la moyenne de toutes les paires. Un agent est considéré isolé lorsqu'aucun autre survivant n'est dans son rayon normal de 32 m. Le test contrôle aussi que les chasseurs continuent d'avancer, sans blocage durable.

Le test de regroupement place volontairement dix agents dispersés, avec des voisins encore visibles à portée de récupération : en **30 s**, la dispersion passe de **49,00 à 19,92 m**, l'espacement final est de **10,82 m** et le minimum observé de **7,15 m**, sans observation sous le seuil critique de 7 m. La récupération est active à 42 m, absente à 70 m et n'ajoute pas d'attraction vers un compagnon déjà proche à 15 m.

Le test de streaming avance artificiellement de **6 000 m**, y compris avec une dérive X/Y : les **six patterns** apparaissent, **175 configurations** sont générées et **162 supprimées**, avec au plus **38 astéroïdes actifs**. Deux exécutions de même graine produisent exactement la même signature ; une autre graine produit un champ différent. Les seuils, l'augmentation de densité, le HUD, la protection d'un retardataire et l'effacement des références d'un obstacle supprimé passent.

Le parcours continu de **300 s** atteint **3 167,86 m**, en **difficulté 3**, avec **10 survivants, 0 mort**. Le champ continue à générer : **92 configurations créées, 79 supprimées**, **29 astéroïdes actifs à la fin**, **40 au maximum**, y compris après 180 s. Le maximum total mesuré est de **620 nœuds**. Le coût moyen par tick headless passe de **0,474 ms** sur 180–210 s à **0,486 ms** sur 270–300 s : pas de dérive notable sur ce parcours. Ce sont des mesures CPU de cette machine, pas des FPS de rendu.

Les dix chasseurs présentent un mouvement relatif en X/Y/Z durant 16 s sans rochers. Deux chasseurs forcés à 2 m se séparent à 10,46 m en 3 s. Les quatre directions de contournement passent avec un gros astéroïde dans l'axe, ainsi que deux gros rochers côte à côte. Le stress séparé à 35 m/s, portée de perception nulle, garde les collisions activées et confirme la destruction unique, les débris et les compteurs. Les commandes F, pan clavier/vertical, orbite souris, molette et G passent. Deux parcours de 10 s en modes Suivi/Libre produisent exactement les mêmes positions et vitesses (écart maximal mesuré : 0). Le rendu OpenGL Compatibility et le modèle en gros plan ont été lancés et vérifiés visuellement.

Pour produire une capture avec le moteur de rendu, exécuter le test sans `--headless` en ajoutant `-- --capture` ; l'image est enregistrée dans `.godot/validation/preview.png`. Ce mode attend trois secondes de simulation, enregistre l'aperçu, vérifie les transformations graphiques des étoiles après recyclage, puis se ferme. Le mode headless vérifie leurs positions logiques ; les transformations MultiMesh nécessitent le vrai moteur de rendu, car le pilote graphique factice renvoie des valeurs nulles.

Ajouter `--capture-drone` après `--capture` produit aussi `.godot/validation/patrol_drone.png`, une vue rapprochée obtenue avec la caméra libre. Ces captures et les logs restent ignorés par Git.

Le script `validate_combat.gd`, lancé avec rendu et `-- --capture-combat`, produit `.godot/validation/combat.png`. Il s'agit d'une scène contrôlée montrant un bolt et un hostile, pas d'une capture du parcours normal de 90 s. Le rendu OpenGL et la lisibilité du HUD sont vérifiés.

Sous Windows, si l'exécutable graphique Godot rend la main avant sa fin, utiliser `Start-Process -Wait -PassThru -WindowStyle Hidden` et lire le journal passé à `--log-file` pour confirmer le résultat. Les contrôles ci-dessus ont attendu la fin réelle des processus.

Références API : [PrismMesh](https://docs.godotengine.org/en/stable/classes/class_prismmesh.html), [PhysicsBody3D.move_and_collide](https://docs.godotengine.org/en/stable/classes/class_physicsbody3d.html#class-physicsbody3d-method-move-and-collide), [StaticBody3D](https://docs.godotengine.org/en/stable/classes/class_staticbody3d.html) et [InputEventMouseMotion](https://docs.godotengine.org/en/stable/classes/class_inputeventmousemotion.html).

## Limites connues

- Le champ se renouvelle continuellement mais son budget reste borné. Un groupe exceptionnellement étiré en Z ou des paramètres extrêmes peuvent remplir le budget et retarder la préparation devant. Le nettoyage continue de protéger le dernier survivant.
- Évitement réactif de trois astéroïdes proches au maximum, plus les hostiles locaux, sans planification complète. Les parcours M6 décrits gardent dix survivants ; les anciens parcours M5 comportaient deux morts à cinq minutes. La survie n'est pas garantie avec une autre graine ou sur une durée plus longue.
- L'approche mobile suppose une vitesse constante sur quelques secondes. Des changements brusques ou des dangers opposés peuvent faire échouer l'évitement. Les ticks de réaction ne constituent pas un décompte certain de collisions évitées.
- Les drones n'évitent pas encore les autres drones. Leur remplacement peut momentanément réduire la population ; leur route n'est pas recentrée continuellement sur le groupe bleu.
- La récupération ne peut réunir des groupes dont aucun membre ne voit l'autre à 50 m. Aucun rappel global invisible n'impose un regroupement.
- Les lasers restent droits ; l’artillerie ajoute arcs et guidage limité. Leur visée initiale est approximative. L'intercepteur poursuit pendant un temps limité ; les BlueShip ne poursuivent pas de cible. Aucun impact rouge n'est observé dans les trois parcours M6, et aucun hostile n'est détruit dans les deux parcours MANUEL 3 : l'équilibrage reste à étudier sur plusieurs graines.
- L'objectif de 9–14 m est un espacement moyen, pas une distance minimale imposée. Les manœuvres peuvent créer des rapprochements brefs ; le test normal M3 mesure 6,71 m au plus près.
- Les hitboxes simplifient et réduisent la silhouette des chasseurs ; les pointes des ailes, le bout du nez et les flammes ne sont pas intégralement couverts.
- Les tailles des astéroïdes sont nominales : la déformation et les lobes irréguliers modifient leurs dimensions exactes.
- L'émission cyan est visible en Compatibility, sans dépendre d'un halo de post-traitement.
- Le déplacement continu en Z ne recale pas l'origine du monde ; des parcours beaucoup plus longs peuvent perdre en précision numérique. Le test de cinq minutes ne mesure pas une session de plusieurs heures ni les FPS graphiques sur cette durée.
- Les réglages extrêmes peuvent disperser le groupe ; les apparitions restent sûres et peuvent être retardées. Les comptes ennemis sont des cibles : la destruction et les délais de remplacement réduisent temporairement les effectifs.
- Engine.time_scale et la fréquence physique sont globaux ; l'application est prévue pour une seule simulation active. Accélérer augmente le nombre de calculs physiques par seconde réelle. L'équilibrage n'a pas été étudié sur plusieurs graines.
- Le cadrage cinématique privilégie le groupe bleu ; des ennemis éloignés peuvent sortir du champ. La correction caméra utilise les enveloppes des rochers et ne constitue pas un solveur de collision complet. Le micro-shake est désactivé ; le test de cadrage porte sur les centres échantillonnés.
- L'anticipation des trajectoires courbes utilise leur vitesse instantanée sur un horizon court. Les extrémités des segments inversent la vitesse ; des cas difficiles ou une autre graine peuvent provoquer des pertes. Les proportions mobiles actives peuvent fluctuer quand un barrage entier entre ou sort du champ, et les trajectoires encore en attente ne sont pas en translation.
- L'horizon décoratif suit la progression : c'est un décor visuel sans mécanique orbitale. Les mesures de survie, dispersion et tirs peuvent différer entre le rendu réel et le headless ; les FPS sont mesurés uniquement avec rendu, le coût CPU uniquement en headless.

## Hors de ce milestone et perspectives

M1–M11 sont implémentés. La démo guidée prépare la présentation orale autour des quatre agents et du phénomène émergent. Le PowerPoint, une étude de plusieurs graines et les bombes BlueShip restent hors de ce travail.
