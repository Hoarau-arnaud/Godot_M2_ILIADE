# Simulation SMA spatiale — milestone 15

Projet pédagogique **Godot 4.7.2 / GDScript**, avec exactement quatre types d'agents : **BlueShip, PatrolDrone, Interceptor et Capital Artillery Ship**. Les projectiles, missiles, bombes, faisceaux et rochers sont des éléments de combat/environnement.

## M15 — Dangers géométriques et espace arcade original

Le parcours garde les plafonds M14 **64 / 48 / 64 rochers et 40 unités de combat**, les renforts et les pertes cumulées. Il ajoute des dangers plus imposants, des volumes de missiles et une animation dorée des boosts. Tous les maillages, matériaux et silhouettes sont procéduraux et originaux ; aucun modèle, niveau, texture ou asset de jeu commercial n’est repris. Il reste **exactement quatre types d’agents**. `MovingLaserGate`, `SpaceAsteroid`, missiles et `ArcadeBackdrop` sont des dangers/décors passifs.

### Grilles réellement mobiles

`MovingLaserGate` prolonge les zones de combat avec deux variantes : **LASER_GATE** (six barres, trois cellules larges) et **ROTATING_LASER_GRID** (huit barres, neuf cellules). Taille **110 × 80 m**, largeur des beams **1,6 m**, profondeur 3 m. Chaque barre possède un mesh, une Area3D et une BoxShape3D. Contact : **3 HP**, une fois par BlueShip et par grille. Un balayage relatif sur trois poses interpolées complète les colliders pour les translations/rotations entre deux ticks.

Le Capital lance la grille depuis sa batterie distante, vers une interception du centre et de la vitesse moyenne observée. La vitesse **45 m/s simulés** et la direction sont fixées au départ : aucune poursuite du groupe. L’arrivée prend plusieurs secondes ; la grille entière est visible depuis son lancement. Rotation autour de l’axe de progression : **15°/s**, **25°/s**, ou **−25°/s** ; inclinaisons initiales 0/20/35/45°. Une seule grande grille est admise à la fois ; ses six/huit beams participent au budget partagé de 40.

La grille expose **7 ou 13 points de passage**, comprenant les centres de cellules et quatre contournements extérieurs. Chaque BlueShip prédit le moment où le plan le croisera, projette les ouvertures avec la rotation future, puis choisit selon distance, vitesse actuelle, voisins et rochers. L’index choisi reste mémorisé au moins **1 s simulée**, puis conservé tant que le passage reste accessible et libre. L’agent corrige sa trajectoire vers le point tournant ; il ne reçoit aucune consigne collective. Un boost d’urgence exige une arrivée proche et une trajectoire prédite près d’une barre.

Les métriques distinguent **passage dans le cadre par une ouverture** et **contournement extérieur** ; elles ne comptent pas une mort comme traversée. Phénomène : **menace commune mobile → choix locaux d’ouvertures → sous-groupes temporaires → passage → récupération locale**.

L’arrivée d’un renfort est vérifiée contre les barres dans leur pose actuelle et à leur croisement prédit dans la seconde simulée suivante. La taille de la grille ne se réduit donc pas au rayon de l’ancienne zone statique ; une ouverture vraiment libre reste utilisable.

### Astéroïdes COLOSSAL

La plage de diamètre nominal atteint **160 m**. MEGA reste une catégorie distincte ; COLOSSAL couvre les volumes **60–120 m**, avec les tailles exceptionnelles 120–160 m configurables. Guided utilise **96 m** : un événement en phase 1, un en phase 2, puis un au plus simultanément en finale. Les événements sont espacés de 26 s réelles dans la finale. Les phases 1/2 présentent aussi un méga ; les autres trajectoires du champ restent actives.

Le Colossal coupe un corridor prédit **11 s simulées** à l’avance, décalé au-dessus et à droite pour laisser un détour. Sa translation reste fixée au départ. Huit lobes/volumes low-poly composent la silhouette, dont des fragments anguleux ; une seule enveloppe convexe assure la collision. Perception locale **150–250 m** (`clamp(110 + radius*2.4, 150, 250)`), horizon 12 s simulées, priorité au contournement progressif. La caméra privilégie un angle large/latéral ou sous le groupe pour montrer l’échelle.

### Boosts et missiles volumétriques

Les moteurs cyan réagissent à la vitesse réelle et au blend de boost : longueur de base **×2,8**, émission 1,5→7, largeur légèrement accrue. Une coque dorée transparente et deux anneaux réutilisés deviennent visibles pendant l’esquive ou l’arrivée d’un renfort, puis disparaissent progressivement. Aucun collider ni force de navigation n’est ajouté par ces animations ; leur nombre de nodes reste fixe. Trois boosts simultanés renforcent légèrement les streaks et le FOV M14 reste plafonné à +3°.

| Arme | Volume principal et détails | Collision / évitement |
|---|---|---|
| Heavy | Corps capsule 7,4 m, diamètre 2,5 m, nez conique, quatre ailettes, anneau, moteur et large traînée ; volume solide total ≈8,9 m | Capsule 8,5 m / rayon 1,25 m ; évitement 16 m |
| Seeker/Swarm | Corps 4,4 m, diamètre 1,2 m, nez conique, quatre ailettes, moteur et traînée cylindrique ; corps+nez ≈5,05 m ; léger roll visuel | Capsule 4,8 m / rayon 0,6 m ; évitement 7 m |
| Arc | Capsule magenta 4,4 m / diamètre 1,7 m, deux anneaux de 2,6 m animés | Capsule 4,4 m / rayon 0,85 m ; évitement 8 m |
| Bomb | Volume sphérique 5,6 m, anneau et pulsation | Sphère rayon 2,8 m ; vol sans dégâts de contact, zone explosive 13 m |
| Rapid | Noyau lumineux, enveloppe capsule et anneau, dimensions principales 3,4 m | Sphère balayée rayon 0,35 m ; évitement 4 m |

Les capsules physiques suivent la direction réelle du vol ; le roll Seeker et les anneaux Arc restent visuels. La géométrie fixe est fusionnée/cachée par signature, avec une variation de couleur par facette donnant du relief sous plusieurs angles. Deux anneaux Arc restent animables hors du mesh fusionné. Les traînées sont visuelles et ne définissent pas la longueur du collider. Les profils historiques conservent leurs anciennes signatures et hitboxes.

### Décor et parcours

La planète reçoit une palette bleu/cyan/turquoise, un relief de couleur procédural et une ombre de terminator ; son halo est conservé. Un large anneau translucide rejoint la bande existante de 360 fragments. Sept silhouettes de guerre très lointaines et quatorze flashes animés en MultiMesh donnent de la profondeur, sans collision, IA ni projectile dangereux. Étoiles, nébuleuses et masquage du décor dans l’axe BlueShip sont conservés.

Phases 1–4 : **18 s réelles** chacune. Phase 5 : **42 s**, avec trois Capitaux alternant Heavy → Seeker → Moving Gate → Bomb → Rotating Grid → Swarm → Arc sur un seul cycle, départs principaux espacés de **5,5 s réelles**. La fin de phase laisse arriver la dernière salve Arc avant le nettoyage. La finale conserve **15 BlueShip / 4 Patrol / 4 Interceptor / 3 Capital**, les renforts après 1,0–1,6 s réelles, les pertes cumulées et le Game Over normal désactivé. La caméra observe l’approche de la grille en Wide puis la traversée derrière le groupe.

En finale M15, les Patrol et Interceptor détruits sont remplacés avec une nouvelle seed, au plus une instance de chaque type par frame et sans dépasser la cible de quatre. Ils conservent leurs règles autonomes, signatures et budgets de tirs ; ils ne sont pas protégés des collisions. Ce maintien reste limité à ce profil Guided.

### Validation M15

`tests/validate_arcade_hazards.gd` vérifie translation, rotations dans les deux sens, ouvertures tournantes, mémoire stable, manœuvres individuelles, survie et récupération collective, collision barre/ouverture, Colossal 96 m, aura/moteurs/renfort, volumes et capsules, esquives Heavy/Seeker, sécurité des arrivées près d’une grille et remplacement des petits hostiles. Le rendu natif mesure les cinq phases puis **60 s réelles de finale**, vérifie les populations finales et le maximum simultané d’une grille/Colossal.

```powershell
$godotExe = 'C:\Users\Sora\Desktop\Godot_v4.7.2-stable_win64.exe'
Start-Process -FilePath $godotExe -ArgumentList '--headless','--path','.','--fixed-fps','60','--script','res://tests/validate_arcade_hazards.gd','--log-file','.godot/m15_validation.log','--','--unit-only' -WindowStyle Hidden -Wait
```

Pour le benchmark 1920×1080 : retirer `--headless`/`--fixed-fps`, remplacer `--unit-only` par `--native`. `--native --capture` est un essai graphique séparé, exclu des FPS d’acceptation. Les onze suites M1–M14 choisissent explicitement leurs profils historiques : `FlightTuning.m13_fixture`/`m14_fixture` désactivent `arcade_hazards_enabled`. Logs, JSON et captures restent dans `.godot/`, ignoré.

Limites : interception et passage supposent une vitesse instantanée sur un horizon court ; des menaces concurrentes ou une ouverture devenue occupée peuvent provoquer des pertes. Le balayage des grilles et la collision des rochers restent des approximations géométriques. Le regroupement repose sur les voisins locaux et n’est pas garanti pour des sous-groupes très éloignés. Aucune mortalité précise n’est imposée.

### Résultats d’acceptation M15

Godot **4.7.2**, seed **20261012**, Intel Arc Graphics, OpenGL Compatibility/MSAA 4×, rendu interne **1920×1080**, vitesse **2,0× / 120 Hz**. Les onze suites historiques M1–M14 et les fixtures M15 passent sans erreur/warning dans leurs journaux d’acceptation. Le benchmark natif final, sans écriture PNG, couvre les cinq phases puis **60,00 s réelles de finale** : **89,90 FPS moyens**, minimum sur une fenêtre d’une seconde **84,79 FPS**. Les captures sont produites dans un essai graphique distinct et exclues de ces FPS.

| Phase | Rochers max / Mega / Colossal émis | Gate / Grid émises | Passages intérieurs / contournements | Boosts | Pertes / renforts / Blue actifs | Dispersion max → finale |
|---|---:|---:|---:|---:|---:|---:|
| 1 — 18,00 s | 63 / 1 / 1 | 0 / 0 | 0 / 0 | 3 | 0 / 0 / 15 | 113,67 → 95,26 m |
| 2 — 18,00 s | 47 / 1 / 1 | 0 / 0 | 0 / 0 | 2 | 0 / 0 / 15 | 96,33 → 69,29 m |
| 3 — 18,01 s | 3 / 0 / 0 | 0 / 0 | 0 / 0 | 17 | 0 / 0 / 15 | 67,85 → 33,04 m |
| 4 — 18,00 s | 3 / 0 / 0 | 0 / 0 | 0 / 0 | 13 | 1 / 1 / 15 | 70,55 → 20,60 m |
| 5 — 42,01 s | 0 / 0 / 0 | 1 / 1 | 25 / 5 | 17 | 0 / 0 / 15 | 88,51 → 76,23 m |
| 6 — 60,00 s | 63 / 5 / 2 | 1 / 2 | 17 / 26 | 87 | 6 / 6 / 15 | 125,75 → 121,97 m |

Mega, Colossal et grilles sont des **émissions cumulées par phase** ; deux Colossal émis en finale ne signifient pas deux simultanés. Maximum observé : **une grille et un Colossal actifs**. Population finale : **15 Blue / 4 Patrol / 4 Interceptor / 3 Capital**. Le run compte 7 pertes bleues et 7 renforts cumulés, 139 boosts au total. La finale émet 10 missiles Swarm, 12 Seeker, 6 Heavy et 4 Arc. Un passage compte une paire Blue/grille ; le même agent peut traverser plusieurs grilles.

| Phase | Nœuds max | Unités dangereuses max, beams inclus | Projectiles physiques max |
|---|---:|---:|---:|
| 1 | 1 301 | 0 | 0 |
| 2 | 1 545 | 0 | 0 |
| 3 | 1 312 | 4 | 4 |
| 4 | 1 114 | 16 | 16 |
| 5 | 1 184 | 18 | 14 |
| 6 | 1 797 | 25 | 24 |

Phase 2 conserve les mouvements diagonal/vertical/circular/arc. La phase 5 émet 3 Heavy, 6 Seeker, 2 Bomb, 2 grilles, 10 Swarm et 4 Arc ; chaque famille provoque au moins une réaction Blue/danger. Les attaques restent espacées et les Capitals lointains.

Arc suit une courbe balistique fixée au départ : une salve peut passer à distance si les BlueShip ont changé de route entre-temps. La présence de cette signature est vérifiée dans Guided ; la fixture Arc ciblée vérifie directement la réaction locale, avec **31 ticks d’évitement**, un boost, **23,61 m** d’excursion et aucune perte.

| Fixture contrôlée, 15 Blue | Translation / rotation | Points sûrs / indices choisis | Manœuvres X/Y >5 m | Passages / contournements / survivants | Changements d’ouverture | Dispersion max → après récupération |
|---|---:|---:|---:|---:|---:|---:|
| Gate +15°/s | 246,75 m / 82,25° | 7 / 5 | 15 | 11 / 4 / 15 | 0 | 52,83 → 43,11 m |
| Grid +25°/s | 247,50 m / 137,50° | 13 / 7 | 14 | 15 / 0 / 15 | 0 | 45,20 → 40,97 m |
| Grid −25°/s | 247,50 m / −137,50° | 13 / 7 | 14 | 15 / 0 / 15 | 0 | 45,20 → 40,92 m |

Les grilles commencent à 220 m. Les ouvertures tournent ; chaque Blue fait un choix mémorisé et les trois fixtures finissent sans perte. La récupération est mesurée neuf secondes simulées après la traversée, sans repositionnement. Une fixture immobile dans une barre subit un événement de 3 HP et une mort ; dans l’ouverture centrale, zéro dégât/mort. Les arrivées dans une barre extérieure ou devant une barre imminente sont refusées, tandis qu’une ouverture libre est acceptée. Les remplacements Patrol/Interceptor passent le test de destruction et nouvelle identité.

Le Colossal **96 m** possède huit lobes et une enveloppe convexe unique, de rayon effectif **53,64 m**. Les quinze agents le détectent ; la portée configurée vaut **238,75 m**. La médiane de première réaction est proche de 238 m ; un agent qui n’était pas initialement menacé réagit plus tard, vers 104 m. Le centre du groupe parcourt **26,79 m en X/Y**, sans mort, avec dispersion **42,21 → 27,95 m** après 20 s simulées.

Le boost augmente l’échelle longitudinale mesurée du moteur à **4,28**, avec émission **7** ; le multiplicateur M15 est ×2,8 avant la modulation par la vitesse. Aura absente en vol normal, visible pendant boost et arrivée, puis disparition progressive ; **aucun collider ajouté**, deux anneaux réutilisés. Heavy et Seeker ciblées déclenchent chacune un boost sur 63 ticks à 60 Hz, sans mort, avec excursions respectives **56,72 et 54,27 m**. Les bornes de rendu incluent les traînées ; les longueurs solides et colliders sont données dans le tableau des armes.

Les captures 1080p vérifient le Colossal, les deux grilles, les moteurs/anneaux dorés, les volumes de missiles sous plusieurs angles et le décor. Les BlueShip restent identifiables et la planète occupe une large partie du fond sur les plans adaptés. La caméra peut laisser quelques agents très dispersés hors champ ; elle ne modifie pas leurs trajectoires. Le regroupement observé reste partiel et local.

## Référence historique M14 — Menaces lisibles et renforts

F5 lance toujours Guided automatiquement. Le sujet du plan reste l’escadron bleu : **menace importante → perception individuelle → contournement ou boost → dispersion → renfort éventuel → récupération locale**. Les quatre types d’agents sont inchangés. Les méga astéroïdes sont des `SpaceAsteroid`, les projectiles et zones restent des dangers passifs.

| Phase | Population et dangers M14 | Référence M13 |
|---|---|---|
| 1 — ÉVITEMENT D’OBSTACLES | 15 BlueShip, plafond 64 rochers, croisements majeurs espacés | 180 rochers |
| 2 — ASTÉROÏDES DYNAMIQUES | plafond 48, diagonal/vertical/circular/arc et méga | 84 rochers |
| 3 — DRONES DE PATROUILLE | 4 PatrolDrone, route A–B–C–D, pulses espacés | 4 PatrolDrone |
| 4 — INTERCEPTEURS | 4 Interceptor, rafales de 4, pause 1,8 s simulée | 5, rafales de 5 |
| 5 — FLOTTE D’ARTILLERIE | 3 Capital Ships à 390–515 m, attaques espacées | 5 Capitaux, plafond 90 dangers |
| 6 — ASSAUT FINAL continu | cible 15 Blue, 4 Patrol, 4 Interceptor, 3 Capital, plafond 64 rochers et 40 unités dangereuses | 15/5/5/4, 110 rochers, plafond 60 dangers |

### Méga astéroïdes et perception

La catégorie MEGA accepte **20–60 m nominaux** ; la démonstration emploie **28 et 40 m**, sans cas 50–60 m aléatoire susceptible de fermer le passage. MEGA_LINEAR, MEGA_DIAGONAL, MEGA_VERTICAL et MEGA_SLOW_CROSSING décrivent des translations fixées à l’apparition, avec un seul méga principal actif. Le croisement est préparé à `fleet_center + fleet_average_velocity * 6 s`, décalé de 12 m X / 4 m Y pour laisser un contournement. Aucun recalcul en poursuite et aucune direction commune n’est envoyée aux BlueShip.

Chaque BlueShip augmente sa portée à `clamp(44 + avoidance_radius * 3.8, 44, 140)` : environ 45–50 m pour les petites roches et 90–140 m pour les mégas. L’horizon méga passe à 7 s simulées et une marge supplémentaire prépare une grande courbe, avec une direction locale mémorisée. Le boost reste un secours critique. La taille nominale n’est pas le diamètre exact du maillage lobé.

### Tirs et chorégraphie

Les attaques simples Rapid/Swarm et les bolts parcourent un cycle déterministe **80 % TARGETED / 15 % NEAR_PASS / 5 % SUPPRESSION** ; Heavy et Seeker sont entièrement ciblés. TARGETED intercepte un Blue vivant avec une erreur ±1,3 m X/Y (bolts : spread ±0,75° par axe en plus) ; NEAR_PASS ajoute un décalage radial 5–12 m ; SUPPRESSION ajoute 22–35 m. Ces derniers restent des tirs physiques et peuvent toucher un autre agent. Bombes et faisceaux gardent leur catégorie ZONE et sont mesurés séparément. Les tirs admis sous budget peuvent donner un ratio différent du cycle nominal. `shots_targeted_per_ship` mesure les tirs effectivement émis, indexés par seed individuelle, y compris les renforts.

Les trois Capitaux se partagent Heavy/Seeker, Bomb/Swarm et Curtain/Grid. Heavy passe à 72 m/s et un rayon d’évitement de 16 m dans ce profil ; les bombes prédisent un petit amas de voisins vivants plutôt qu’un barycentre vide après dispersion. Un départ principal toutes les **4,5 s réelles** distingue Heavy (3), Seeker (6), Bomb (2), Curtain, Swarm (10), puis Rapid (10). Grid remplace occasionnellement Curtain ; une grille préparée ou active interdit une seconde grille. Les trajets déjà partis peuvent se croiser. Le plafond partagé 40 comprend les raycasts/corps et les lignes de faisceaux ; 6 places sont réservées aux zones, les autres armes s’arrêtent à 34. Les tracers deviennent secondaires : **14/s réelles**, durée 3 s simulées, près des batteries lointaines. Les débris décoratifs proches de la caméra, des BlueShip ou du corridor de visée sont masqués en Guided ; les rochers physiques restent visibles et collidables.

Une force de menace générique prolonge les boosts des missiles/torpilles jusqu’à 1,04 s simulée et augmente leur correction latérale. La direction reste stable pendant chaque boost. Les bombes sont évitées par leur zone annoncée. La caméra observe les mégas, missiles et explosions imminentes pour privilégier side/top/rear, puis wide lors d’une forte dispersion. Les cadrages sont tenus au moins 0,8 s. Pour garder les sujets identifiables malgré quelques isolés, la caméra cadre les douze BlueShip proches du noyau le plus dense ; les autres continuent leur vol normal et peuvent sortir du plan. Elle n’agit jamais sur la navigation.

Les bolts Interceptor du profil M14 infligent 2 HP, les pulses Patrol 1 HP et les Heavy 2 HP : la difficulté vient des tirs admis et des collisions réelles, sans destruction scriptée dans la démonstration. Le ratio de départ des bolts avance uniquement lorsqu’un tir est effectivement émis.

### Pertes cumulées et renforts

Le HUD affiche **Vaisseaux bleus détruits : X**. Seul le signal de destruction réelle d’un BlueShip incrémente ce compteur ; retraits, nettoyage, changement de mode/phase et morts ennemies n’y participent pas. Les survivants gardent leur identité et leurs HP entre les phases. Le profil Guided élargit uniquement les perceptions locales de voisinage/récupération à 48/100 m, avec cohésion 0,3 et récupération 7 m/s pour revenir après les grands détours. FREE conserve 32/50 m et ses poids d’origine. Les pertes restent cumulatives jusqu’à Rejouer/nouveau run ; quinze actifs peuvent coexister avec vingt-sept pertes.

Chaque perte planifie un remplacement après **1,0–1,6 s réelles**, indépendant d’Engine.time_scale. Les départs rapprochés sont espacés de 0,06 s réelle. Le spawn recherche un volume libre **30–50 m derrière le centre**, X ±22 / Y ±14, vérifié contre BlueShip, hostiles, rochers, projectiles et zones ; s’il est encombré, il est retardé. Après extinction, le dernier centre connu sert d’ancrage. Les moteurs brillent environ une seconde réelle, puis le renfort utilise exactement les règles SMA ordinaires, sans téléportation au centre.

Le parcours normal ne s’arrête plus lors d’une extinction temporaire : `guided_reinforcements_enabled=true`, `stop_on_squadron_extinction=false`. Les fixtures M13 emploient explicitement l’inverse et `threat_choreography_enabled=false`. FREE conserve son comportement et sa restitution d’état. Rejouer nettoie Guided, remet les pertes/renforts/métriques à zéro, restaure la seed et recommence à quinze en phase 1.

### Validation M14

`tests/validate_threat_choreography.gd` vérifie trois vraies morts par laser, explosions, délai, spawn, arrivée locale, retraits sans mort, identités entre phases, Replay, extinction simultanée, Game Over M13 optionnel, méga 40 m et cent tirs contrôlés. Il mesure ensuite les six phases et **60 secondes réelles** de finale.

```powershell
$godotExe = 'C:\Users\Sora\Desktop\Godot_v4.7.2-stable_win64.exe'
Start-Process -FilePath $godotExe -ArgumentList '--headless','--path','.','--fixed-fps','60','--script','res://tests/validate_threat_choreography.gd','--log-file','.godot/m14_validation.log','--','--unit-only' -WindowStyle Hidden -Wait
```

Pour le benchmark graphique : retirer `--headless`/`--fixed-fps`, remplacer `--unit-only` par `--native`. `--native --capture` est un essai distinct avec captures PNG, exclu des résultats FPS. Les suites M1–M13 choisissent leurs paramètres historiques, sans changer les règles physiques de leurs assertions. Les logs/JSON/captures restent ignorés dans `.godot/`.

Les réactions par famille comptent les paires Blue/danger ayant déclenché un évitement ou un boost ; le compteur de menaces critiques reste distinct ; elles ne prouvent pas une collision évitée. La récupération locale ne garantit pas la réunion de sous-groupes hors de portée. Le spawn peut attendre au-delà du délai nominal si tout le volume est occupé. Les performances et pertes ne sont pas garanties sur d’autres machines, graines ou plusieurs heures.

### Résultats d’acceptation M14

Godot **4.7.2**, seed **20261012**, Intel Arc Graphics, OpenGL Compatibility/MSAA 4×, rendu interne **1920×1080**, vitesse **2,0× / 120 Hz**. Les dix suites historiques M1–M13 et les fixtures M14 passent sans erreur/warning dans leurs journaux d’acceptation. Le benchmark sans PNG couvre les cinq phases puis **60.00 secondes réelles de finale** : **98.63 FPS moyens**, minimum d’une seconde **84.90 FPS**. Le coût de compression des captures est vérifié dans un essai séparé et exclu de ces valeurs.

| Phase | Rochers / mégas | TARGETED / NEAR_PASS / SUPPRESSION / ZONE | Boosts / impacts | Pertes / renforts / actifs | Dispersion max → finale |
|---|---:|---:|---:|---:|---:|
| 1 | 63 / 3 | 0 / 0 / 0 / 0 | 0 / 0 | 0 / 0 / 15 | 63.97 → 63.46 m |
| 2 | 47 / 3 | 0 / 0 / 0 / 0 | 1 / 0 | 0 / 0 / 15 | 81.12 → 78.83 m |
| 3 | 3 / 0 | 19 / 0 / 0 / 0 | 14 / 0 | 0 / 0 / 15 | 85.91 → 70.59 m |
| 4 | 3 / 0 | 33 / 6 / 2 / 0 | 13 / 0 | 0 / 0 / 15 | 90.01 → 69.52 m |
| 5 | 0 / 0 | 27 / 2 / 0 / 3 | 29 / 0 | 0 / 0 / 15 | 113.42 → 91.59 m |
| 6 | 63 / 5 | 157 / 21 / 7 / 6 | 73 / 2 | 1 / 1 / 15 | 139.92 → 112.33 m |

Phase 1 : excursion maximale du centre 22.63 m. Phase 2 : mouvements diagonal/vertical/circular/arc et 3 mégas. Phase 3 : 19 pulses. Phase 4 : 12 poursuites, 12 rafales commencées et 12 désengagements. Une rafale peut être interrompue avant ses quatre départs.

| Phase 5, famille | Tirs ou zones | Cibles individuelles distinctes | Réactions Blue/danger | Impacts |
|---|---:|---:|---:|---:|
| Heavy | 3 | 3 | 20 | 0 |
| Seeker | 6 | 6 | 9 | 0 |
| Bomb | 2 | 0 | 9 | 0 |
| Laser | 1 | 0 | 10 | 0 |
| Swarm | 10 | 9 | 13 | 0 |
| Rapid | 10 | 9 | 1 | 0 |

Bomb et Laser visent des **zones**, sans cible individuelle : zéro dans cette colonne ne signifie pas zéro BlueShip affecté. Les réactions regroupent évitement et boost, une fois par paire Blue/danger tant que le danger reste dans la mémoire locale ; elles ne sont pas des collisions évitées prouvées. Les impacts comptent les événements de dégâts, pas la quantité de HP retirée.

Finale : **15 actifs**, **1 perte pendant la finale**, **1 perte cumulée depuis la phase 1**, **1 renfort pendant la finale**. Budget observé : 34 projectiles physiques, 34 unités avec beams, 63 rochers, 5 mégas générés successivement, 1774 nœuds maximum ; maximum global 1774 nœuds. Les tirs simples admis en finale donnent 84.86 % ciblés ; zones séparées. Le nombre de morts provient des collisions réelles ; aucun objectif de mortalité n’est imposé.

Fixtures : trois destructions par laser donnent **3 pertes / 3 renforts / 15 actifs**, les trois retraits administratifs n’ajoutent aucune perte ; extinction simultanée → **15 pertes / 15 renforts / 15 actifs**, sans Game Over, avec apparition progressive. Le flag historique conserve Game Over et Replay dans les six phases. Les volumes occupés par rocher, missile, zone, voisin et grande coque Capital sont refusés.

Méga 40 m : portée effective **115.24 m**, 13 détections, **13/15 manœuvres X/Y >10 m**, excursion du centre 11.21 m, 0 boost, 0 collision mortelle, dispersion **53.98 → 27.91 m**. Le contournement est progressif. Cent tirs Rapid contrôlés donnent **80 / 15 / 5**, tous les 80 ciblés sont initialement menaçants si les BlueShip gardent leur vitesse, **15 cibles distinctes**, au plus 7 tirs ciblés pour une identité.

## Référence historique M13 — Menaces ciblées et boosts individuels

**F5 démarre automatiquement la Démo guidée**, après l'initialisation complète de Main (`auto_start_guided_demo=true`, appel différé). La caméra Cinématique et le titre de phase sont actifs sans entrée utilisateur. **D / Simulation libre** restitue les mêmes entités FREE suspendues, leurs HP, cibles, mémoires, réglages et RNG. TAB ouvre les commandes, H l'aide, F11/Alt+Entrée le plein écran. Recommencer démo/Rejouer repart du début.

Les phases 1–4 durent **18 secondes réelles** chacune ; la flotte Capital dure **28 s**. Chacune recrée 15 BlueShip à 3 HP ; ce retrait n'est pas une mort. **La phase 6 historique est continue, difficulté 3**, initialement 15 BlueShip, 5 PatrolDrone, 5 Interceptor, 4 Capitaux lointains et **110 météores en streaming** (budget réduit après benchmark), Mouvement 1,6 et Intensité tirs 1,2. Elle ne termine pas sur un timer et n'applique pas d'escalade automatique supplémentaire. Les pertes sont possibles.

**Zéro BlueShip dans n'importe quelle phase arrête immédiatement le combat guidé**, les vols/tirs existants, la génération d'ennemis et de rochers, ainsi que le timer de phase. L'écran centré **ESCADRON DÉTRUIT** propose un grand **REJOUER** et Simulation libre. Rejouer nettoie les entités guidées, restaure la seed 20261012, efface morts/impacts/menaces/boosts/passages proches, recrée 15 chasseurs à 3 HP, reprend la phase 1 et la caméra Cinématique, puis cache l'écran. UI et caméra restent réactives pendant Game Over.

### Vitesses physiques et rythme

| Paramètre | M12 | M13, secondes simulées |
|---|---:|---:|
| BlueShip, avance / latéral / accélération | 10,5 / 9 / 12 | **16 m/s / 15 m/s / 22 m/s²** |
| PatrolDrone, avance | 9,2 (9,8 pour certaines apparitions FREE) | **13 m/s** (13,6 pour certaines apparitions FREE) |
| Interceptor, patrouille / plafond poursuite | 9 / 18 | **15 / 23 m/s**, latéral 12, accélération 20 |
| BlueLaser | 60 | **100 m/s**, durée 3 s |
| Energy Bolt Interceptor | 45 | **85 m/s**, durée 2,5 s |
| Plasma Pulse Patrol | 26 | **58 m/s**, durée 3 s |
| Heavy / Rapid / Seeker-Swarm / Bomb / Arc | 27 ou vitesse liée au vol | **52 / 88 / 65 / 48 / 62 m/s** |
| Spread / Cross | 30 | **80 m/s** |

La variation personnelle Blue ±3 % et la variation longitudinale ±3 m/s subsistent. Le multiplicateur Guided retenu est **2,0× à 120 Hz** après comparaison **2,0 / 2,1 / 2,2×**. La préférence initiale de 2,1× a été écartée car des fenêtres d’une seconde restent sous 60 FPS. FREE conserve son slider **0,5–2,5×**, défaut 1,7×. L'horloge accélère tous les mouvements et délais physiques ; les durées des phases et de caméra restent réelles.

### Visée prédictive, TARGETED et SUPPRESSION

`CombatPrediction` résout l'interception à vitesse constante : `|target_position + target_velocity*t - origin| = projectile_speed*t`, en choisissant la plus petite racine positive. Le tir non guidé conserve ensuite sa direction. La visée d'un Capital est recalculée **au départ effectif de chaque projectile**, puis reçoit une erreur déterministe **±1,8 m X/Y**. Les grandes erreurs M12 ±35/24 m sont réservées aux anciennes fixtures. Les tirs SUPPRESSION visent le centre prédit du groupe avec ±14 m X / ±10 m Y ; ce sont de vrais projectiles, avec collisions.

Les cibles vivantes sont réparties par round-robin, décalé selon le rôle du Capital. **Rapid : 17/24 TARGETED (70,8 %) ; Swarm : 13/18 (72,2 %) réellement guidés vers une cible**, les autres suivent un point prédit fixe. Heavy et Seeker visent individuellement ; Arc vise 2/4, Spread 3/5 et Cross 4/6 individuellement, le reste contrôle la zone. Bombes et grilles sont des attaques de zone. Le budget peut refuser certains départs ; les compteurs TARGETED/SUPPRESSION portent sur les **projectiles effectivement émis**, excluent beams et tracers, et comptent une bombe physique comme SUPPRESSION. Une cible morte avant départ transforme le départ en SUPPRESSION. Seeker/Swarm tournent au maximum **12° par seconde simulée**, perdent proprement leur cible morte et restent esquivables.

L'Interceptor vise **sa cible de poursuite**, avec interception et spread **±0,75° par axe**. Le Patrol choisit un BlueShip dans un demi-cône **32° autour de sa vitesse**, prévoit sa position et ajoute ±1,5 m X/Y. Il continue sa route A–B–C–D et ne poursuit pas. Les tracers décoratifs passent de **90 à 30/s réelles**, environ 157 simultanés au lieu de 522 ; aucun dégât ni collision.

### EVASIVE_BOOST, perception et animation

Chaque BlueShip décide localement, sans chef ni ordre commun. La perception des tirs couvre **80 m**, horizon **4 s simulées**, avec lecture toutes les **0,06 s simulées en GUIDED**, soit environ 30 lectures/s réelles à 2,0×/120 Hz. Une menace doit converger et avoir une distance minimale prévue inférieure à son rayon de sécurité ; un tir passant à 30 m est ignoré. Le score combine manque de clearance, distance actuelle, vitesse relative, temps CPA et poids du type. Un projectile critique a un CPA dans **1 s**, score ≥1 ; une roche critique a une entrée prévue dans son enveloppe de sécurité dans **0,8 s**, score ≥0,8. Bombes/grilles imminentes sont évaluées dans leur zone télégraphiée.

Un boost dure **0,65 s simulée**, augmente l'avance **×1,35**, le latéral **×1,9** et l'accélération **×2,2**. Le cooldown dure **1,1 s simulée après sa fin** ; une nouvelle menace distincte passant à moins de 1,8 m dans 0,25 s peut l'interrompre. Huit directions X/Y sont évaluées : préférence perpendiculaire au tir, espace prévu face aux voisins, rochers et autres tirs. La direction est conservée pendant le boost ; un mélange décroissant rend progressivement le contrôle aux règles locales. **Aucun tir Blue durant EVASIVE_BOOST**, puis reprise si les autres conditions de tir sont sûres.

Les propulseurs cyan reçoivent un allongement ×2,2, une émission 1,5→5 et un streak cyan de 7 m. Le roll peut atteindre **±55°**, le pitch reste **±8°**. Plusieurs boosts élargissent doucement le FOV de **0 à +3°**, plafond 71°. Les streaks/parallax proches sont renforcés ×1,25 en GUIDED ; aucun blur lourd. Ces changements concernent le visuel, sans rotation des hitboxes ni consigne caméra aux agents.

| Arme | Signature |
|---|---|
| Patrol plasma | Sphère verte, halo circulaire, courte traînée |
| Interceptor energy | Trait rouge/orange 7–9 m, noyau clair blanc/orange, coque lumineuse translucide |
| Heavy torpedo | Capsule de 6 m, gros nez lumineux, quatre ailettes, moteur orange/violet, grosse traînée |
| Seeker/Swarm | Fuselage capsule, nez, quatre ailettes, moteur et trois segments de traînée |
| Arc | Capsule magenta, deux anneaux énergétiques, trajectoire physique courbe |
| Rapid | Petits traits d'énergie orange/jaune de 3 m |
| Bomb | Grosse sphère pulsante, warning, explosion et shockwave |
| Grid/Curtain | Faisceaux continus avec Area3D, warning et passage ouvert |

Les signatures d’artillerie sont fusionnées en **une surface et un appel de rendu par projectile**, avec géométrie/couleurs immuables mises en cache par famille et préparées au chargement, avant le combat. Les collisions balayées restent celles du body ; aucun pooling ne réutilise ses cibles ou son état de vol.

Les compteurs internes suivent boosts, paires Blue/menace critique, tirs ciblés/suppression, impacts et near misses, sans encombrer le HUD. Un passage proche est une approximation par segment relatif échantillonné, minimum < `avoidance_radius + 2 m` (enveloppe + marge pour les rochers), comptée une seule fois par paire après passage, puis nettoyée par références faibles et distance. Un même tir peut frôler plusieurs BlueShip. **Ce compteur ne prouve pas à lui seul qu'un boost a empêché un impact** ; le comparatif contrôlé avec/sans perception vérifie séparément l'amélioration de survie.

### Validation M13

`tests/validate_targeted_evasion.gd` contrôle 20 tirs identiques avec/sans esquive, durée/animation/direction/cooldown/exception létale et suspension/reprise du tir Blue, 20 tirs Interceptor, cône/route Patrol, 100 tirs Capital de plusieurs familles, autostart, Game Over et Replay dans chaque phase, restitution des mêmes entités FREE, séquence complète et finale de 60 s ou extinction. Les neuf suites M1–M12 choisissent explicitement leur ancien profil via `FlightTuning.legacy_actor`, désactivent l'autostart et conservent leurs assertions physiques/SMA ; M12 conserve aussi sa finale temporisée et ses anciens tirs.

```powershell
$godotExe = 'C:\Users\Sora\Desktop\Godot_v4.7.2-stable_win64.exe'
Start-Process -FilePath $godotExe -ArgumentList '--headless','--path','.','--fixed-fps','60','--script','res://tests/validate_targeted_evasion.gd','--log-file','.godot/m13_validation.log' -WindowStyle Hidden -Wait
```

`-- --unit-only` isole les tests contrôlés. Pour le rendu réel, retirer `--headless` et `--fixed-fps`, ajouter **`-- --native`**. `--finale` commence directement en phase 6 ; `--pace=2.0`, `2.1` ou `2.2` règle l'essai. **`--native --capture`** réalise séparément les captures des six phases et des écrans Game Over/Replay. Le benchmark FPS n'écrit aucune PNG pendant la mesure. JSON, logs et captures restent dans `.godot/`, ignoré.

Validation de référence **13 octobre 2026, Godot 4.7.2, seed 20261012, Intel Arc Graphics, OpenGL Compatibility, MSAA 4×, VSync**. Les neuf suites historiques complètes M1–M12 passent ; après l’optimisation du rendu, les contrôles M10/M12 et la suite M13 sont relancés. Les journaux d’acceptation ne contiennent ni erreur ni warning Godot. Les captures des six phases, des formes d’armes, du boost, de Game Over et de Replay sont contrôlées séparément.

La comparaison préliminaire, avec **150 rochers en finale avant les dernières optimisations**, donne : 2,0× **85,20 / 65,09 FPS** moyen/minimum d’une seconde ; 2,1× **80,42 / 60,58** ; 2,2× **79,45 / 46,82**. Le parcours complet révélait encore des baisses sous 60 à 2,1×, puis à 2,0× avec 150 rochers. Le réglage final conserve **2,0× / 120 Hz**, fusionne les signatures d’artillerie dans un mesh partagé par famille, prépare leur géométrie avant le combat et limite la finale à **110 rochers physiques**. Les vitesses, le ciblage, les dégâts et les quatre types d’agents sont conservés.

Le parcours complet final, phases 1–5 puis **60,00 secondes réelles de finale**, rend à **1920×1080**, sans PNG pendant la mesure : **96,83 FPS moyens**, minimum sur une seconde **71,98 FPS**. Le chronomètre mesure **159,87 s après l’initialisation**, pour environ 160 s de phases. La finale est encore GUIDED, difficulté 3, sans Game Over ni sortie automatique au terme de l’essai.

| Phase, rendu réel | Vivants / morts de la phase | TARGETED / SUPPRESSION | Menaces critiques | Boosts | Near misses tirs | Impacts de combat | Rochers max | Tirs physiques max / beams inclus |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 15 / 0 | 0 / 0 | 1 | 1 | 0 | 0 | 180 | 0 / 0 |
| 2 | 15 / 0 | 0 / 0 | 1 | 1 | 0 | 0 | 84 | 0 / 0 |
| 3 | 15 / 0 | 24 / 0 | 20 | 19 | 24 | 0 | 3 | 6 / 6 |
| 4 | 13 / 2 | 78 / 0 | 84 | 33 | 82 | 9 | 3 | 36 / 36 |
| 5 | 12 / 3 | 167 / 77 | 94 | 80 | 80 | 3 | 0 | 90 / 90 |
| 6 | 13 / 2 | 348 / 99 | 223 | 131 | 200 | 3 | 110 | 54 / 56 |

En finale seule : **348 ciblés / 99 suppression (77,85 % ciblés)**, **223 menaces critiques**, **131 boosts**, **200 passages proches de tirs**, **88 passages proches de rochers**, **3 événements de dégâts de combat**, **2 morts** et **13 survivants**. Configuration initiale : 15/5/5/4 agents ; fin : 13 BlueShip, 5 PatrolDrone, 5 Interceptor, 4 Capital. Maximum **2839 nœuds**, **54 tirs physiques**, **56 unités dangereuses beams inclus**, **110 rochers**. Excursion latérale maximale **203,10 m** ; regroupements locaux observés, dispersion maximale/finale **186,15/179,80 m**.

La phase 5 atteint **68,44 % TARGETED**, au-dessus des 65 % demandés, avec 5 Capitaux, 57 missiles, 11 explosions de bombes et 4 grilles. La phase 3 conserve ses routes avec **24 pulses ciblés, 19 boosts et aucun décès**. La phase 4 montre **17 poursuites, 15 désengagements, 78 tirs, 33 boosts et 2 décès** ; sa dispersion diminue de **63,75 à 39,09 m**, exemple de regroupement après esquives. Les phases 1/2 enregistrent chacune un boost critique, **135/66 passages proches de rochers** et **55,48/28,60 m d’excursion latérale** ; l’évitement ordinaire peut empêcher une situation de devenir assez critique pour déclencher le boost.

Sur le parcours complet : **617 TARGETED, 176 SUPPRESSION, 423 paires critiques, 265 boosts, 386 near misses de tirs, 289 de rochers, 15 impacts de combat et 7 morts cumulées**. Chaque nouvelle phase remet 15 BlueShip ; les morts cumulées ne se confondent donc pas avec les deux pertes de la finale. Le maximum global est **2839 nœuds, 180 rochers, 90 tirs dangereux**.

Les 20 tirs comparatifs sont tous initialement menaçants : **sans perception, 9 impacts/11 survivants ; avec perception, 0 impact/20 survivants, 19 boosts et 23,39 m XY maximum**. Le boost forcé mesure **0,63 s simulée**, environ **11,12 m XY**, avec exhaust allongé, direction tenue, absence de tir puis reprise, cooldown et exception létale vérifiés. Un gros rocher de 8 m provoque un boost réel : survie et **21,13 m XY**. Le missile corrige **6° en 0,5 s simulée**, puis abandonne la cible supprimée ; le choix du boost évite un voisin occupant une direction candidate. Les 20 tirs Interceptor sont menaçants, avec erreur angulaire maximale **0,87°** ; le Patrol anticipe dans son cône et refuse une cible derrière, sans modifier son waypoint.

Le test Capital de **100 projectiles**, avec HP élevés pour observer les réactions jusqu’au bout, donne **69 TARGETED / 31 SUPPRESSION**, **69 trajectoires ciblées initialement menaçantes**, **2 impacts directs / 98 sans impact direct**, **0 dégât de zone et 0 impact rocher**, **16 boosts, 63 épisodes d’évitement, 14 near misses** et **15 cibles distinctes**. Ce scénario contrôlé ne représente pas la survie naturelle à 3 HP.

Autostart, Game Over **dans chacune des six phases**, arrêt des tirs/streaming/timer, bouton Rejouer, retour à 15 chasseurs/0 mort/phase 1/Cinématique, répétition des mêmes configurations initiales et restitution des mêmes agents FREE passent. Les captures natives confirment l’écran centré et le compteur remis à zéro au Replay.

Limites : une seule machine et une graine de référence ; cadence de rendu et intégration peuvent changer les pertes/trajectoires. Les near misses sont des paires approximatives, pas une preuve causale de chaque impact évité. La prédiction suppose la vitesse instantanée, particulièrement imparfaite face aux arcs/guidages ; les rochers absorbent les tirs. Le regroupement reste local et certains survivants demeurent isolés. La finale est continue mais l’essai natif couvre 60 s ; aucune garantie d’équilibrage/performance sur plusieurs heures. Les captures PNG sont séparées du benchmark car leur lecture GPU/compression perturbe les FPS.


Les références suivantes décrivent les jalons précédents et leurs fixtures ; le comportement normal courant est celui de M15 ci-dessus.

## Référence historique M12 — Traversée d'une zone de guerre spatiale

**D** ou **Démo guidée** démarre le parcours. D ou **Simulation libre** le termine ; **Recommencer démo** reprend la phase 1. TAB réaffiche le panneau, H l'aide, F11/Alt+Entrée le plein écran. La caméra Libre (F) reste distincte de la simulation FREE.

Le séquenceur suspend les entités FREE dans leurs parents, avec leurs identités, HP, cibles, mémoires, timers, RNG, réglages et caméra. Il les restitue à la sortie automatique ou manuelle. Chaque phase repart avec **15 BlueShip à 3 HP** ; le reset retire les anciens sans compter de morts. Les collisions et dégâts restent réels. Les agents gardent leur navigation SMA locale, sans route commune ni force caméra.

| Phase | Durée réelle | Présentation |
|---|---:|---|
| 1 — TEMPÊTE DE MÉTÉORES | 18 s | 180 rochers physiques mobiles LINEAR, positions XYZ et directions continues, aucun ennemi |
| 2 — ASTÉROÏDES ORBITAUX | 18 s | 84 rochers physiques : diagonales, balayages verticaux, orbites inclinées et arcs |
| 3 — DRONES DE PATROUILLE | 18 s | 4 PatrolDrone, routes A → B → C → D, marqueurs, pulses verts ; trois rochers physiques |
| 4 — INTERCEPTEURS | 18 s | 5 Interceptor, rafales de cinq tirs, pauses plus courtes ; trois rochers physiques |
| 5 — FLOTTE D'ARTILLERIE | 28 s | 5 Capital Ships en formation irrégulière, à 350–650 m ; bombardement et dangers télégraphiés |
| 6 — ASSAUT FINAL | 30 s | 150 rochers physiques, 5 PatrolDrone, 5 Interceptor et 4 Capital Ships lointains |

Le scénario dure **130 secondes réelles**, à **1,9×**. Movement vaut **1,5 / 1,5 / 1,35 / 1,35 / 1,5 / 1,6**. Les cinq dernières secondes de finale arrêtent les nouveaux tirs ennemis ; les tirs en vol et les règles de mouvement continuent. Deux chasseurs écartés commencent dans la portée de récupération de 50 m.

### Meteor Storm et décor

`DEMO_METEOR_STORM` utilise un RNG personnel dérivé de `simulation_seed` (seed de démonstration par défaut **20261012**). Une même graine reproduit la tempête initiale ; une autre la change. Les rochers naissent dans un volume **X ±70 m, Y ±45 m, 30–280 m devant le groupe**. Rejection sampling : pas d'apparition sur un chasseur, pas de chevauchement initial des enveloppes, au plus quatre voisins dans 18 m, et corridor sinueux conservé pour les grosses masses. Les petits météores peuvent le traverser. Le streaming remplace les rochers qui quittent le volume ; le budget reste **180**, ou **84** en phase 2.

Distribution nominale : **55 % de 0,6–2 m, 28 % de 2–5 m, 14 % de 5–10 m, 3 % de 10–16 m**. Les rejets peuvent modifier les proportions réellement acceptées. Les rochers de tempête utilisent une enveloppe convexe unique et conservative autour de leurs lobes. Leurs lobes sont rendus par quatre MultiMesh avec les transforms physiques exacts. FREE conserve ses formes convexes par lobe ; le diamètre est nominal. Vitesses initiales : **4–8, 8–16, 16–28 m/s**, quelques petits météores à **30–45 m/s**. Directions XYZ continues avec biais vers le volume observable ; rotations et plans orbitaux personnels. Le mouvement LINEAR reste rectiligne pendant la phase. Les trajectoires orbitales ont une vitesse instantanée variable.

Les barrages FREE reçoivent aussi un jitter XYZ, conservateur près des anciens passages. FREE normal conserve son plafond de 96 rochers. Le décor ajoute **1 000 rochers MultiMesh** autour/derrière/au loin, en plus des **360 débris de l'anneau**. Ces deux MultiMesh décoratives n'ont aucune collision, perception ou dégâts ; elles sont distinctes du rendu instancié des rochers physiques. La grande planète, son halo et les nébuleuses sont conservés.

### Arsenal de la flotte

Les Capital Ships utilisent la même classe/FSM et restent lointains en GUIDED. Silhouettes, fenêtres, moteurs violets et flashes des batteries montrent l'origine des tirs. Les cinq attaques historiques restent disponibles.

| Nouvelle attaque | Fonctionnement |
|---|---|
| RAPID_BARRAGE | Salve de 24 bolts, intervalle 0,085 s simulée ; environ 22 tirs/s réelles durant une rafale admise, sous budget partagé |
| BOMB_CLUSTER | Trois bombes lumineuses visant des positions gelées autour du centre prédit ; zone 3D annoncée avant explosion |
| LASER_CURTAIN | Quatre faisceaux parallèles, espaces ouverts, avertissement avant activation |
| LASER_GRID | Quatre lignes verticales et deux horizontales ; grand passage central ouvert, warning rouge puis activation intense |
| MISSILE_SWARM | Salve nominale de 18 missiles, certains visent un BlueShip, guidage limité à 6°/s simulée et poursuite abandonnée si cible morte |

Visée gelée : `observed_center + observed_velocity * travel`. Les nouveaux vols prennent environ **10,5–14 s simulées**, soit **5,5–7,4 s réelles à 1,9×** ; la vitesse est calculée depuis la distance réelle du lanceur à la zone prédite. Les beams sont précédés d'un paquet lumineux traversant cette distance, puis d'un warning local **1 s réelle**. Ils sont dangereux pendant **0,68 s réelle**, puis supprimés. Chaque ligne utilise un mesh et une `Area3D/BoxShape3D`, pas un essaim de CharacterBody.

La bombe montre une sphère translucide et un anneau au point prévu pendant les **2,6 s réelles** finales. Explosion : sphère emissive croissante, anneau shockwave et 18 éclats MultiMesh. Rayon **13 m**, dégâts **3 / 2 / 1 HP** selon distance, zéro dehors. La grille inflige **3 HP** au contact actif, une fois par cible et attaque. Ces zones participent à la perception prioritaire des BlueShip pendant le warning. Les missiles et bolts gardent de vraies collisions ; les tracers ne font aucun dégât.

Le plafond partagé est **90 unités dangereuses** en phase 5 et **60 en finale** : tirs physiques/raycast et lignes laser préparées/actives. Six places sont réservées aux grilles en finale ; les tirs ordinaires s’arrêtent à 54 unités. FREE garde ses plafonds plus bas. Les salves dépassant le budget sont partiellement refusées, sans accumulation de tirs retardés ; une salve réellement émise peut donc être plus petite que sa taille nominale. Le budget et les temps de vol empêchent de maintenir 20–40 tirs dangereux/s indéfiniment. Le MultiMesh de tracers fournit **90 traits/s réelles**, avec un pool de **768 instances et un seul Node**, pour renforcer le bombardement sans autant de corps physiques.

### Projectiles, caméra et panneau

Patrol : noyau vert sphérique **1,8 m**, halo **2 m**, petite traînée cylindrique. Interceptor : streaks orange/rouge **7 ou 9 m**, épaisseurs **0,55 ou 0,45 m**, noyau blanc/orange **0,18 m** ; raycasts inchangés. Missiles : capsule de **3,4 m**, nez arrondi, moteur et trois segments de traînée colorée, sans lumières dynamiques.

Six plans supplémentaires : **FRONT_FLYBY, REAR_CLOSE, TOP_DOWN, UNDER_FLEET, WIDE_ARTILLERY, SIDE_FAST**. GUIDED change de cadrage toutes les **3,5–6 s réelles**, transition interpolée **0,8 s**, sans agir sur les agents. La perception des dangers en GUIDED est échantillonnée toutes les 0,05 s simulées (environ 30 Hz réelles avec le pas physique), avec steering conservé entre lectures ; les collisions restent au pas physique de 120 Hz. FREE garde ses lectures à chaque tick. FRONT_FLYBY est occasionnel ; le cadrage adapte sa distance à l'étendue du banc.

FREE ajoute exactement deux sliders : **Densité rochers 0,5–2,5**, défaut **1**, modifie l'espacement de streaming des configurations ; **Intensité tirs 0,5–3**, défaut **1**, modifie les intervalles ennemis et la préparation/cooldown Capital, jamais les dégâts. Les deux paramètres sont restaurés après GUIDED. Le panneau conserve les contrôles précédents, avec des espacements plus compacts pour tenir dans 720p.

### Validation M12

`tests/validate_hazard_spectacle.gd` vérifie les graines, distributions, spawn sûr, budgets, grille télégraphiée, collision directe létale et passage sûr, réaction autonome, bombe/AoE/nettoyage, cible gelée, salve de 18 missiles/guidage/cible morte, flotte visible/distances/continuité, les six phases et la restitution FREE. Les fixtures M1–M11 peuvent garder les anciennes géométries et le scénario M11 ; elles conservent leurs contrôles physiques et SMA. Les assertions de présentation M11 acceptent les projectiles encore épaissis.

```powershell
$godotExe = 'C:\Users\Sora\Desktop\Godot_v4.7.2-stable_win64.exe'
Start-Process -FilePath $godotExe -ArgumentList '--headless','--path','.','--fixed-fps','60','--script','res://tests/validate_hazard_spectacle.gd','--log-file','.godot/m12_final.log' -WindowStyle Hidden -Wait
# Pour le rendu réel, retirer --headless / --fixed-fps et ajouter -- --native.
```

Le pilote natif vérifie un rendu interne **1920×1080** en plein écran, sans redimensionner les captures. Le projet conserve son viewport `canvas_items/expand`. Les mesures headless sont distinctes des FPS graphiques. Le benchmark `-- --native` n’écrit aucune PNG pendant la mesure ; `-- --native --capture` produit séparément les captures et mesure aussi le coût de leur lecture GPU/compression/écriture. Les métriques/captures restent dans `.godot/`, ignoré par Git.

Validation de référence **Godot 4.7.2, Intel Arc Graphics, Compatibility OpenGL, MSAA 4×, VSync, seed 20261012** : les **neuf suites M1–M12 passent**, sans erreur/warning Godot dans les journaux d'acceptation. Le rendu complet mesure **97.06 FPS moyens**, minimum sur une seconde **70.12 FPS**, pendant **130.26 s réelles** pour **130.01 s de scénario**. Le rendu interne est vérifié à **1920×1080**, dans une fenêtre plein écran de (3840, 2400). La compression/écriture des PNG est séparée du benchmark ; les captures ont été contrôlées visuellement. L'écriture d'une capture durant une finale chargée peut faire chuter momentanément les FPS, sans représenter le coût du rendu normal.

| Phase, rendu réel | Blue vivants / morts | Verts / rouges / Capital à la fin | Rochers physiques max | Tirs dangereux max, hors beams | Budget total observé, beams inclus |
|---|---:|---:|---:|---:|---:|
| 1 — TEMPÊTE DE MÉTÉORES | 15 / 0 | 0 / 0 / 0 | 180 | 0 | 0 |
| 2 — ASTÉROÏDES ORBITAUX | 15 / 0 | 0 / 0 / 0 | 84 | 0 | 0 |
| 3 — DRONES DE PATROUILLE | 15 / 0 | 4 / 0 / 0 | 3 | 12 | 12 |
| 4 — INTERCEPTEURS | 15 / 0 | 0 / 5 / 0 | 3 | 50 | 50 |
| 5 — FLOTTE D'ARTILLERIE | 15 / 0 | 0 / 0 / 5 | 0 | 84 | 90 |
| 6 — ASSAUT FINAL | 15 / 0 | 4 / 5 / 4 | 150 | 54 | 58 |

Phase 1 : **180 mobiles simultanés**, **4.04–44.83 m/s** en vitesse initiale, quatre tranches de taille, directions continues, excursion XY individuelle maximale **26.08 m**. La tempête initiale de 180 rochers accepte **89 petits / 60 moyens / 28 grands / 3 très grands**, 180 directions distinctes, vitesse **4,06–41,31 m/s** ; le streaming élargit ensuite cette plage. Phase 2 : **84 simultanés**, quatre familles complexes représentées, excursion XY **30.72 m**, 15 survivants.

Phase 3 : **7 routes complètes**, **38 waypoints**, **61 pulses verts**. Phase 4 : **15 poursuites**, **15 désengagements**, **207 tirs rouges**. Phase 5 : les **5 Capital** sont tous observés dans le cadre et avec flash de batterie, entre **406.48 et 636.98 m** ; leur déplacement maximal entre deux frames observées vaut **0.79 m**. **163 tirs d'artillerie** atteignent la zone de 65 m autour du banc. Les cinq nouvelles familles sont exercées : **8 tentatives de Rapid Barrage**, **7 explosions de bombe**, **2 activations Curtain**, **3 Grid**, **38 missiles émis**. Les compteurs de salves indiquent des tentatives sous budget, pas la garantie d'une salve entière admise.

Finale de **30 s** : **15 survivants / 0 morts**, **150 rochers**, **54 tirs dangereux simultanés** et **58 unités avec beams**, **2 explosions**, **3 grilles actives**, **24 missiles**, **352 tirs ennemis / 10 tirs bleus**, **334 épisodes d'esquive**, **52 entrées en regroupement**. Dispersion maximale **62.93 m**, finale **60.13 m** : le regroupement local n'est pas toujours complet. Les **1 360 débris décoratifs**, les **90 tracers/s**, et le maximum de **522 tracers actifs** renforcent la densité sans dégâts supplémentaires.

Maximum global : **3224 nœuds**, **180 rochers physiques**, **84 tirs dangereux hors beams**, **90 unités beams inclus**. Restitution FREE : **421 → 421 nœuds**, mêmes entités, réglages, caméra, compteurs et RNG. Le parcours headless termine la finale avec **14 / 1**, **3 grilles**, et **3 explosions** ; il mesure **130.05 s de scénario**, ses FPS artificiels ne sont pas des FPS graphiques. Le stress de petit météore à **45 m/s** conserve une collision réelle unique ; la grille produit une mort à contact direct ; la bombe vérifie le gradient **3/2/1/0 HP**, les missiles une salve de 18, le virage limité et une cible morte sans référence invalide. Les sliders de densité produisent **4 contre 12 configurations initiales** dans le test contrôlé, et l'intensité conserve les dégâts.

Journaux d'acceptation : `.godot/validate_*_m12_final.log`, `.godot/m12_render_benchmark_verified.log`. Métriques : `.godot/m12_metrics.json`, `.godot/m12_native.json`, `.godot/m12_suite_results.json`. Captures : `.godot/validation/m12_phase_*.png`, `m12_streaks_verified.png`, `m12_free_panel.png`. Ces fichiers restent ignorés par Git.


Limites : un seul parcours de référence n'est pas une étude multi-graines. Les dégâts restent réels ; aucun taux de survie n'est garanti. Les épisodes d'esquive/regroupement ne prouvent pas une collision évitée ni un regroupement complet. Les phases réinitialisent le banc ; leur total de morts n'est pas la survie continue des mêmes quinze agents. Les objets libres suspendus et les suppressions différées restent inclus dans le maximum de nœuds. Un budget plein peut réduire les salves. La mesure 1080p n'est pas un benchmark 4K natif. Aucun PowerPoint, PR ou merge n'est créé dans M12.


### Fichiers M12

| État | Fichiers |
|---|---|
| Créés | `scripts/artillery_zone.gd`, `scripts/artillery_zone.gd.uid`, `scripts/battle_tracers.gd`, `scripts/battle_tracers.gd.uid`, `scripts/meteor_storm.gd`, `scripts/meteor_storm.gd.uid`, `scripts/storm_rock_visuals.gd`, `scripts/storm_rock_visuals.gd.uid`, `tests/validate_hazard_spectacle.gd`, `tests/validate_hazard_spectacle.gd.uid` |
| Modifiés | `RAPPORT.md`, `README.md`, `project.godot`, `scenes/enemy_laser.tscn`, `scripts/artillery_projectile.gd`, `scripts/asteroid.gd`, `scripts/blue_ship.gd`, `scripts/camera_controller.gd`, `scripts/capital_ship.gd`, `scripts/demo_controls.gd`, `scripts/enemy_laser.gd`, `scripts/guided_demonstration.gd`, `scripts/interceptor.gd`, `scripts/main.gd`, `scripts/obstacle_field.gd`, `scripts/patrol_drone.gd`, `scripts/space_environment.gd`, `tests/historical_fixture.gd`, `tests/validate_cinematic.gd`, `tests/validate_dynamic_space.gd`, `tests/validate_guided_demonstration.gd` |

M11 reste une référence historique : son ancien parcours de 100 secondes et ses sept prédécesseurs sont exercés par les tests dédiés.

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

En Simulation libre, la caméra initiale est en **Suivi** : elle suit le barycentre des survivants et s'éloigne doucement quand le groupe s'étale. **F** passe en **Libre**, une vue orbitale avec un point d'observation déplaçable. La vue reste alors à l'endroit choisi pendant que les agents continuent leur vol. **G** ou **Home / Début** recentre sur le groupe actuel. **C** active **Cinématique** ; un second C revient au Suivi. F permet aussi de reprendre la caméra Libre depuis Cinématique. La souris contrôle seulement le mode Libre.

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

Les touches sont définies par des **Input Actions dans `project.godot`**. C est réservé à Cinématique ; Q sert au déplacement à gauche. Le pan vaut 24 m/s en temps réel, indépendamment de la vitesse de simulation. L'aide est visible dans FREE ; GUIDED la masque au démarrage. **H puis TAB** laissent uniquement le compteur de pertes et les étoiles pour enregistrer une vidéo. Le plein écran utilise [DisplayServer](https://docs.godotengine.org/en/stable/classes/class_displayserver.html) et restaure le mode, la taille et la position de la fenêtre ; celle-ci reste redimensionnable.

### Caméra cinématique

Les six cadrages sont **CHASE, SIDE_LEFT, SIDE_RIGHT, HIGH, LOW_CLOSE et WIDE**. La séquence alterne arrière, gauche, haut, droite, bas et large, toutes les **6–12 secondes de démonstration**, avec des durées déterministes issues de `simulation_seed`. Les offsets changent par une interpolation douce de **2 s**, complétée par le lissage de la position, de l'orientation (slerp) et du FOV. G/Home reprend CHASE par une transition. Une légère oscillation et un très faible roulis évitent la vue rigide sans orbite permanente.

Le cadrage tient compte des positions bleues et du format du viewport ; WIDE prend le relais au-delà de 45 m de dispersion. `action_intensity` résume tirs, esquives, explosions et hostiles proches pour élargir légèrement le FOV. Une correction d'enveloppe et un raycast sur le déplacement de la caméra limitent l'entrée dans les astéroïdes. Le micro-shake est exporté, **désactivé par défaut**. La caméra n'est pas un agent et ne transmet aucune consigne de trajectoire aux chasseurs.

M9 ajoute une réaction douce à la vitesse moyenne X/Y du groupe : décalage latéral, petite avance/retard de 3,5 m, cible légèrement anticipée et roulis borné à **±4°**. La vitesse de démonstration, l'activité des tirs et le mouvement latéral élargissent progressivement le FOV, plafonné à **68°**. La progression physique reste vers −Z et aucun virage n'est imposé aux agents.

## Contrôles de démonstration M7–M8

Le panneau **Contrôles**, visible dans FREE, est placé à droite : largeur **264 px**, marge **18 px**, fond spatial bleu sombre transparent et accent cyan. Il utilise uniquement les nœuds Control Godot standards. **TAB** le masque et le réaffiche. Les étoiles restent visibles dans les deux cas.

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

`simulation_speed_multiplier` utilise **Engine.time_scale** : agents, lasers, délais de poursuite/rafale/remplacement et explosions suivent la même horloge. Les vitesses physiques de base M13 sont appliquées ; seules les fixtures historiques fixent celles de M6. Le taux physique conserve un pas simulé au plus égal à 1/60 s : **60 Hz jusqu’à 1×, 120 Hz jusqu’à 2×**, puis des multiples de **30 Hz** au-delà (150 Hz à 2,1/2,2×, 180 Hz à 2,5×). Les fixtures historiques conservent les multiples de 60 Hz. Les paramètres Engine précédents sont restaurés à la fermeture de la scène. Cette méthode suit les recommandations de la [documentation Engine](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-time-scale).

Le suivi utilise le temps de simulation pour rester fluide ; le pan libre utilise le delta divisé par `time_scale`. Orbite et zoom réagissent directement à la souris. Le panneau consomme ses événements : cliquer un slider/bouton ne déclenche ni orbite ni zoom ; relâcher le clic droit au-dessus du panneau termine aussi une orbite commencée dans l'espace. Les contrôles n'accaparent pas le focus clavier. Aucun paramètre de combat n'est exposé.

### Populations et réglages

Les comptes ennemis affichés sont des **cibles**, pas des statistiques de destruction. `manual_drone_count_override`, `manual_interceptor_count_override` et `manual_capital_count_override` valent **−1** par défaut : utiliser la difficulté. Une valeur **0–8** (ou **0–1** pour le Capital) maintient la population choisie, même après un changement de niveau. **Reset agents** restaure −1 : les populations reprennent les nombres du niveau courant. Les morts, la distance, l'environnement, les BlueShip et les autres sliders restent inchangés.

Les ajouts runtime sont espacés de **0,4 s de simulation**. Les ennemis réutilisent leurs apparitions sûres ; les nouveaux BlueShip apparaissent autour/derrière le groupe, avec contrôle des autres corps et du rayon des rochers. Chaque chasseur reçoit une seed unique, les groupes et les connexions de combat, puis rejoint les règles locales. Une position encombrée retarde l'ajout et provoque une nouvelle tentative.

Une réduction BlueShip retire les excédents **sans explosion ni mort**. Les pertes réelles diminuent le compte restant : elles ne sont **jamais remplacées automatiquement**. `ship_spawn_count` et `ship_retired_count` permettent le bilan **vivants + morts + retraits = créations**. Le nombre initial et toutes les métriques M6 sont conservés.

Mouvement et Espacement sont interpolés sur les chasseurs existants ; les futurs chasseurs reçoivent les valeurs courantes. Mouvement multiplie seulement le wander naturel, sans modifier séparation, cohésion ou collisions. Espacement multiplie les trois distances indiquées, avec des bornes limitées ; il ne change pas les poids des forces ou les hitboxes. Ces contrôles sont des paramètres extérieurs d'expérimentation, pas des perceptions supplémentaires des agents.

Exemple de démonstration : **3**, Interceptor **5**, PatrolDrone **6**, BlueShip **15**, Vitesse **1,8×**, Mouvement **1,5**, puis **H** et **TAB** pour observer la scène.

## Agents et obstacles actuels

- **Type 1 — BlueShip** : `CharacterBody3D`, chasseur spatial original. Le fuselage et les nacelles utilisent chacun un petit **ArrayMesh créé avec SurfaceTool : dix points, seize triangles**, avec un nez effilé en hauteur et en largeur, un dos et un ventre. Les prismes seuls donnaient encore une pointe verticale trop épaisse de profil. Cockpit sombre/cyan surélevé, ailes balayées, pylônes épais et moteurs restent des primitives Godot. Les flammes cyan varient avec la vitesse. Les deux boîtes physiques du M7 restent identiques.
- **Type 2 — PatrolDrone** : `CharacterBody3D`, drone vert avec un corps hexagonal court, un capteur lumineux vert-cyan, de petites ailes, une dérive et deux propulseurs. Il conserve sa patrouille par waypoints et son évitement local. Il devient le premier **agent hostile destructible**, avec **4 HP**, sans poursuite ; en GUIDED, il tire des pulses prédictifs dans son cône.
- **Type 3 — Interceptor** : chasseur rouge pointu, cockpit sombre, ailes courtes et moteurs orange. Il détecte localement un BlueShip, le poursuit temporairement et tire par rafales, puis se désengage. **4 HP**, primitives Godot uniquement.
- **Type 4 — Capital Artillery Ship** : observateur du groupe, batteries prédictives et missiles/attaques de zone. En GUIDED, plusieurs instances du même type restent à grande distance ; en FREE, population 0–1 et rapprochement vulnérable conservés.
- **Obstacle environnemental — SpaceAsteroid** : `AnimatableBody3D` indépendant, avec les mêmes volumes low-poly et formes convexes. Petits : 1–2 m ; moyens : 2–4 m ; grands : 4–7 m de diamètre nominal. La racine physique n'est pas mise à l'échelle. Rotation et trajectoire sont appliquées au pas physique par une seule écriture de transform. Certains restent sans translation. **Les astéroïdes sont des obstacles, pas des agents**, même lorsqu'ils bougent.

### Orientation visuelle du BlueShip

Le nez garde −Z comme direction dominante. Pitch **±8°**, yaw **±10°**, roll **±30°**, ou **±55° pendant EVASIVE_BOOST** : le pitch réagit plus lentement, le roll plus vite, puis revient progressivement à plat. La vitesse physique X/Y peut rester importante sans relever le nez de 30°. Ces angles concernent seulement `Visuals` ; ils ne modifient ni les forces SMA ni les collisions. Le marqueur de tir suit le nouveau nez à **Z = −4,55 m**.

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
| `forward_speed` | 16 m/s | Vitesse avant, variation individuelle ±3 % |
| `max_side_speed` | 15 m/s | Limite combinée en X/Y |
| `acceleration` | 22 m/s² | Lissage de la vitesse |
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
| `forward_speed` | 13 m/s ; Main alterne 13 et 13,6 m/s en FREE |
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

Le HUD principal affiche **Vaisseaux bleus détruits : X** à gauche et **trois étoiles seules** en haut-centre. Le panneau droit contient les six réglages, Reset agents et les outils de présentation M8. L'aide caméra est en bas à gauche. **H puis TAB** masquent les deux panneaux ; le compteur et les étoiles restent visibles. Aucun HP, score, distance ou statistique de combat n'est affiché.

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
- Le HUD conserve « Vaisseaux bleus détruits : X » après la dernière mort bleue. La caméra conserve alors son centre.

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

M1–M15 sont implémentés. La démo guidée prépare la présentation orale autour des quatre agents et du phénomène émergent. Le PowerPoint, une étude de plusieurs graines et les bombes BlueShip restent hors de ce travail.
