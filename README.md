# Simulation SMA spatiale — milestone 3

Projet pédagogique **Godot 4.7.2 / GDScript**. Dix chasseurs bleus progressent vers **Z négatif**, comme un banc de poissons dans un champ d'astéroïdes. Le milestone 3 ajoute une récupération locale du groupe, un champ continu et trois difficultés automatiques selon la distance. Il conserve les mouvements, l'espace personnel, les graphismes et la caméra du M2. Aucun asset externe, sol ou formation imposée.

## Lancement

Importer `project.godot` dans **Godot 4.7.2**, puis appuyer sur **F5**. La scène principale est `res://scenes/main.tscn`. Le rendu Compatibility et le MSAA 4× assurent des contours lisibles. Aucun raccourci clavier ne crée de danger. Arrêter avec F8 dans l'éditeur, puis F5 pour recommencer. `config/features` avait déjà été mis à jour en `4.7` par l'éditeur : cette déclaration est conservée, sans migration supplémentaire.

## Caméra et commandes

La caméra démarre en **Suivi** : elle suit le barycentre des survivants et s'éloigne doucement quand le groupe s'étale. **F** passe en **Libre**, une vue orbitale avec un point d'observation déplaçable. La vue reste alors à l'endroit choisi pendant que les agents continuent leur vol. **G** ou **Home / Début** recentre immédiatement sur le groupe actuel, sans quitter le mode libre. **F** ramène au suivi et à une vue cadrée sur le groupe.

| Commande | Effet en mode libre |
|---|---|
| Clic droit maintenu + souris | Orbite autour du point d'observation |
| Molette haut / bas | Zoom avant / arrière, distance limitée à 6–180 m |
| Flèches haut / bas, ou W / Z et S | Pan avant / arrière sur le plan horizontal de la vue |
| Flèches gauche / droite, ou A / Q et D | Pan gauche / droite |
| PageUp ou E | Monter |
| PageDown ou C | Descendre |
| G ou Home | Recentrer sur le groupe |
| F | Alterner Suivi / Libre |

Les touches sont définies par des **Input Actions dans `project.godot`**, modifiables dans l'éditeur : `camera_toggle`, `camera_recenter`, `camera_forward`, `camera_backward`, `camera_left`, `camera_right`, `camera_up`, `camera_down`, `camera_orbit`, `camera_zoom_in`, `camera_zoom_out`. Q est réservé au déplacement à gauche, ce qui évite le conflit AZERTY avec la descente. Le pan vaut 24 m/s. Le HUD affiche discrètement le mode et les touches F/G. La caméra ne transmet aucune force ou consigne aux agents.

## Agent et obstacles actuels

- **Type 1 — BlueShip** : `CharacterBody3D`, chasseur bleu construit avec des boîtes, cônes, prismes et une sphère aplatie pour le cockpit. Nez allongé vers −Z, cockpit bombé bleu sombre/cyan sur un cadre clair, ailes triangulaires fines dont les pointes sont rejetées vers l'arrière, deux dérives et deux moteurs visibles. Les cônes cyan des réacteurs pulsent avec des phases individuelles. L'orientation et le roulis interpolés concernent le nœud visuel ; les deux petites boîtes physiques restent stables.
- **Obstacle environnemental — SpaceAsteroid** : `StaticBody3D` indépendant. Deux à quatre volumes low-poly déformés composent un rocher irrégulier ; les grands combinent aussi des blocs anguleux. Petits : 1–2 m ; moyens : 2–4 m ; grands : 4–7 m de diamètre nominal. Échelles, orientations des lobes et palettes gris foncé/gris clair/brun varient par graine. Chaque volume possède une enveloppe convexe qui reprend les points déformés du mesh. La racine physique n'est pas mise à l'échelle. Chaque astéroïde tourne autour d'un axe individuel à environ 0,055–0,12 rad/s ; visuels et collisions tournent ensemble au pas physique, sans translation. Les astéroïdes sont des obstacles, pas des agents. **BlueShip reste le seul type d'agent.**

## Comportement des chasseurs

Chaque chasseur évalue uniquement les voisins dans son rayon de perception. Les groupes Godot fournissent les candidats ; le filtrage par distance précède tout calcul comportemental. Aucun agent ne reçoit le centre global de l'essaim ou une position assignée.

1. **Wander** : plusieurs sinusoïdes de fréquences différentes font varier X, Y et la vitesse en Z. Le wander longitudinal est renforcé : les chasseurs prennent progressivement de l'avance ou du retard relativement au groupe. Phase, amplitude, fréquence et vitesse de base varient par individu, sans tirage aléatoire à chaque frame.
2. **Séparation** : répulsion douce sous 11 m, renforcée progressivement sous 7 m avec un terme quadratique. La répulsion critique conserve sa force pendant l'évitement. Une superposition exacte reçoit aussi une correction.
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

avoidance = obstacle_avoidance * avoidance_weight
steering = local_motion * (1.0 - 0.75 * avoidance_priority) + avoidance
# La partie critique de la séparation est rétablie à pleine force.
```

Ce mélange définit une vitesse souhaitée ; l'accélération limite les changements. La priorité d'évitement varie progressivement avec son intensité, entre 0 et 1. La variation longitudinale est limitée à ±3 m/s autour de la vitesse propre de base (10,5 m/s ±3 %). La composante avant reste toujours négative. X/Y partagent une limite de vitesse latérale. L'orientation et le roulis suivent doucement le mouvement visuel, sans simulation aérodynamique.

L'enum `behavior_state` décrit **NAVIGATION**, **AVOIDANCE** (évitement), **REGROUPING** (regroupement) ou **DESTROYED**. L'évitement prend la priorité descriptive sur le regroupement. Ces états reflètent les forces calculées en continu ; ils ne fixent aucune destination ou place dans une formation. Main utilise le centre du groupe pour l'observation, les statistiques et le placement de l'environnement ; il ne le transmet jamais aux chasseurs comme force de déplacement.

La direction de contournement dans le plan X/Y dépend de la position future du chasseur par rapport au centre du rocher ; si l'obstacle est exactement dans l'axe, une préférence individuelle prend le relais. Huit directions simples sont comparées une seule fois au début de la manœuvre pour favoriser un côté moins encombré par les autres menaces sélectionnées. Une direction par obstacle est **mémorisée jusqu'au dépassement**, ce qui évite les changements rapides gauche/droite. L'intensité dépend du déplacement latéral restant et du temps avant contact. La menace principale ne peut pas être complètement annulée par une correction secondaire opposée. Le rayon englobant, calculé sur les points réels des primitives, sert uniquement à anticiper : la destruction dépend du contact physique.

Les hitboxes des chasseurs sont volontairement plus petites que leurs ailes : fuselage 0,78 × 0,5 × 3,15 m ; ailes centrales 2,8 × 0,16 × 1,25 m, pour une envergure visuelle de 5,6 m. Un effleurement de pointe n'est donc pas fatal ; un contact du corps ou de la partie centrale des ailes reste destructeur. Les collisions restent activées en scénario normal.

`move_and_collide(velocity * delta)` balaie le déplacement. À la première collision avec un astéroïde, le chasseur cesse sa logique, quitte immédiatement `blue_ships`, émet `died` une seule fois, crée une brève explosion de cubes lumineux, puis est supprimé. Main retire sa référence et met à jour les vivants/morts. Aucun cadavre ne reste dans les calculs des voisins.

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

La marge géométrique d'anticipation du chasseur est de 2,5 m, en plus de `obstacle_clearance`. Dans Main : `ship_count = 10`, `initial_ship_spacing = 8,5 m`, `simulation_seed = 20261012`, `camera_follow_speed = 3`, `streaming_enabled = true` et `metrics_update_interval = 0,4 s`. Les positions initiales sont aléatoires avec un espacement minimal. La séparation à 11 m, la zone critique à 7 m et les poids du M2 restent inchangés.

## Champ continu et difficulté

Le nœud `Asteroids`, piloté par `scripts/obstacle_field.gd`, renouvelle le champ à chaque pas physique depuis Main. Il prépare des configurations jusqu'à **320 m devant le chasseur le plus avancé**. Leur position X/Y utilise le centre actuel des survivants, avec une variation aléatoire ; la caméra ne participe pas à la génération. La première configuration commence à **55 m** devant. Une configuration est supprimée seulement lorsque toute son enveloppe est à plus de **100 m derrière le dernier survivant**, y compris un retardataire. Les références de menaces et de directions mémorisées sont effacées lors de la sortie d'un obstacle de l'arbre.

Le budget est de **72 astéroïdes actifs maximum**, avec un à trois rochers par configuration et au plus douze nouvelles configurations par appel. Les listes gardent uniquement les configurations actives. Les collisions restent actives jusqu'à la suppression. Les paramètres du champ sont exportés sur `Main/Asteroids` : `spawn_ahead_distance`, `start_distance`, `cleanup_distance`, `max_active_asteroids`, `horizontal_spread = 18 m` et `vertical_spread = 12 m`. Les deux spreads règlent le décalage aléatoire du centre du pattern, multiplié par 0,45 ; les offsets du pattern s'ajoutent ensuite.

| Pattern | Disposition |
|---|---|
| `SINGLE` | Un rocher isolé |
| `OFFSET_PAIR` | Deux rochers décalés en X/Y et en profondeur |
| `HORIZONTAL_PAIR` | Deux rochers côte à côte |
| `VERTICAL_PAIR` | Deux rochers superposés verticalement |
| `STAGGERED_CLUSTER` | Trois rochers répartis sur trois profondeurs |
| `LARGE_WITH_COMPANIONS` | Un gros rocher central et deux petits compagnons décalés |

Les patterns occupent un volume limité, avec des côtés ouverts pour une route gauche, droite, haute ou basse. Ils ne forment pas de mur fermé. La géométrie et les collisions des rochers sont celles du M2.

| Niveau | Distance parcourue | Distance entre configurations | Échelle des écarts X/Y (`gap`) | Diamètres nominaux | Patterns autorisés |
|---|---|---:|---:|---|---|
| 1 — Facile | 0 à moins de 500 m | 56 m | 22 m | 1,2–3,7 m | Single, Offset pair |
| 2 — Intermédiaire | 500 à moins de 1 100 m | 44 m | 18 m | 2–5,5 m | Offset pair, Horizontal pair, Vertical pair, Staggered cluster |
| 3 — Difficile | À partir de 1 100 m | 34 m | 14 m | 4–6,5 m ; gros central 5,5–7 m et compagnons 1,2–2,2 m | Horizontal pair, Vertical pair, Staggered cluster, Large with companions |

Les paramètres sont `intermediate_distance`, `hard_distance`, `easy_spacing`, `intermediate_spacing`, `hard_spacing`, `easy_gap`, `intermediate_gap` et `hard_gap`. `gap` est l'échelle du gabarit, pas une largeur libre entre surfaces. La difficulté d'une configuration dépend de sa distance en Z depuis l'origine du groupe : le champ plus difficile est ainsi préparé devant avant que le HUD annonce le franchissement du seuil. Aucun menu ou raccourci ne change la difficulté.

La graine **20261012** initialise les chasseurs et un générateur indépendant pour le champ. À graine, paramètres et progression identiques, les patterns, positions, tailles et formes sont reproductibles. La progression affichée est le déplacement en Z du centre des survivants, conservé sans recul si une mort déplace ce centre.

## Mesures du HUD

Le HUD conserve les vivants, les morts et le mode caméra. Il ajoute la **distance parcourue**, la **difficulté**, l'**espacement moyen** et la **dispersion**, actualisés toutes les **0,4 s**. L'espacement est la moyenne de la distance de chaque survivant à son voisin vivant le plus proche. La dispersion est la plus grande distance entre un survivant et le centre mesuré du groupe. Avec moins de deux survivants, l'espacement affiche 0, faute de paire à mesurer. Les mesures n'influencent pas le comportement des agents.

## Architecture

```text
project.godot                 Scène principale, affichage, couches physiques
scenes/main.tscn              Environnement, lumières, caméra, conteneurs, HUD
scenes/blue_ship.tscn         Silhouette du chasseur et deux collisions
scenes/asteroid.tscn          Obstacle environnemental SpaceAsteroid
scenes/explosion.tscn         Effet visuel temporaire
scripts/main.gd              Initialisation, statistiques, centre d'observation
scripts/blue_ship.gd          Perception, règles locales, anticipation, mort
scripts/asteroid.gd           Géométrie procédurale et collisions des rochers
scripts/obstacle_field.gd     Patterns, difficulté, streaming et nettoyage borné
scripts/camera_controller.gd  Suivi, orbite libre, pan, zoom et recentrage
scripts/space_environment.gd  Trois couches d'étoiles, planètes et lune
scripts/explosion.gd          Animation des débris, puis suppression
materials/*.tres              Bleu, gris clair, cockpit, cyan des propulseurs
materials/nebula.gdshader     Nébuleuse transparente, sans texture externe
tests/validate_simulation.gd  Validation reproductible du milestone
```

Les 650 étoiles sont distribuées en trois couches : lointaine (environ 62 %), intermédiaire (30 %) et proche (8 %). Leurs profondeurs et tailles diffèrent ; elles restent immobiles dans le monde jusqu'au recyclage aux bords du volume observé. Le déplacement de la caméra produit donc une parallaxe naturelle. Le recyclage fonctionne aussi pendant le pan libre. Deux planètes à atmosphère légère, une petite lune et un quad de nébuleuse discret donnent de la profondeur sans collision. La caméra conserve son dernier centre après la dernière mort.

### Groupes, signaux et couches

- Groupes : `blue_ships` et `asteroids`.
- Signal : `BlueShip.died(ship)` connecté une fois par Main.
- Vaisseaux : couche **1**, masque **2**. Astéroïdes : couche **2**, masque **0**.
- Les chasseurs se séparent par leurs règles locales ; ils ne se bloquent pas mutuellement par une collision physique. Le masque des chasseurs détecte les corps statiques des rochers.
- Le HUD affiche les vivants et les morts, puis « Tous les agents ont été détruits » quand il n'y a plus de survivants.

## Validation

```powershell
& 'CHEMIN\Godot.exe' --headless --path . --editor --import
& 'CHEMIN\Godot.exe' --headless --path . --fixed-fps 60 --script res://tests/validate_simulation.gd
```

La première commande importe les scènes et vérifie le parsing avec les warnings GDScript traités comme erreurs. La seconde vérifie le lancement, les agents/groupes/couches, la rotation des rochers, le vol 3D sans obstacles, le mouvement relatif en Z, la séparation, la perception locale, les quatre directions de contournement, deux dangers voisins, la destruction réelle, l'unicité du signal, l'explosion et le HUD après la dernière mort. Elle teste également le suivi, les événements clavier/souris de la caméra, les bindings AZERTY, le recentrage et le recyclage des trois couches d'étoiles après un grand déplacement libre. Une comparaison du même parcours en Suivi et Libre vérifie l'indépendance des trajectoires des agents. `--fixed-fps 60` conserve un pas physique de 1/60 s en exécutant le test aussi vite que possible.

Validation effectuée avec **Godot 4.7.2 stable** le 12 octobre 2026, graine **20261012**, pas fixe de 1/60 s : tests sans warning ni erreur, code de sortie 0.

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

Sous Windows, si l'exécutable graphique Godot rend la main avant sa fin, utiliser `Start-Process -Wait -PassThru -WindowStyle Hidden` et lire le journal passé à `--log-file` pour confirmer le résultat. Les contrôles ci-dessus ont attendu la fin réelle des processus.

Références API : [PrismMesh](https://docs.godotengine.org/en/stable/classes/class_prismmesh.html), [PhysicsBody3D.move_and_collide](https://docs.godotengine.org/en/stable/classes/class_physicsbody3d.html#class-physicsbody3d-method-move-and-collide), [StaticBody3D](https://docs.godotengine.org/en/stable/classes/class_staticbody3d.html) et [InputEventMouseMotion](https://docs.godotengine.org/en/stable/classes/class_inputeventmousemotion.html).

## Limites connues

- Le champ se renouvelle continuellement mais son budget reste borné. Un groupe exceptionnellement étiré en Z ou des paramètres extrêmes peuvent remplir le budget et retarder la préparation devant. Le nettoyage continue de protéger le dernier survivant.
- Évitement réactif de trois menaces proches au maximum, sans planification d'un chemin complet. Les dix survivants sont validés pour la graine et les paramètres par défaut ; une collision reste possible si la vitesse augmente, la portée baisse, les marges diminuent ou les obstacles se resserrent.
- La récupération ne peut réunir des groupes dont aucun membre ne voit l'autre à 50 m. Aucun rappel global invisible n'impose un regroupement.
- L'objectif de 9–14 m est un espacement moyen, pas une distance minimale imposée. Les manœuvres peuvent créer des rapprochements brefs ; le test normal M3 mesure 6,71 m au plus près.
- Les hitboxes simplifient et réduisent la silhouette des chasseurs ; les pointes des ailes, le bout du nez et les flammes ne sont pas intégralement couverts.
- Les tailles des astéroïdes sont nominales : la déformation et les lobes irréguliers modifient leurs dimensions exactes.
- L'émission cyan est visible en Compatibility, sans dépendre d'un halo de post-traitement.
- Le déplacement continu en Z ne recale pas l'origine du monde ; des parcours beaucoup plus longs peuvent perdre en précision numérique. Le test de cinq minutes ne mesure pas une session de plusieurs heures ni les FPS graphiques sur cette durée.

## Hors de ce milestone et perspectives

BlueShip est le seul agent implémenté. Les astéroïdes tournent mais ne dérivent pas. Les futurs drones de patrouille, intercepteurs et poseurs de mines restent réservés aux prochains milestones ; aucune de ces fonctionnalités n'est présente dans M3.
