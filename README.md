# Simulation SMA spatiale — milestone 8

Projet pédagogique **Godot 4.7.2 / GDScript**. Dix chasseurs bleus progressent vers **Z négatif**, comme un banc de poissons dans un champ d'astéroïdes. Les trois agents sont **BlueShip, PatrolDrone et Interceptor**. M8 ajoute une caméra cinématique, un chasseur spatial redessiné, six barrages ouverts et des projectiles plus visibles. La démonstration démarre à **1,7×**, avec **Mouvement 1,2**. Le flocking et l'équilibrage du combat sont conservés. **MANUEL 3** est le scénario principal ; le lancement reste en AUTO. Aucun nouvel agent ou asset externe.

## Lancement

Importer `project.godot` dans **Godot 4.7.2**, puis appuyer sur **F5**. La scène principale est `res://scenes/main.tscn`. Le rendu Compatibility et le MSAA 4× assurent des contours lisibles. Aucun raccourci clavier ne crée de danger. Arrêter avec F8 dans l'éditeur, puis F5 pour recommencer. `config/features` avait déjà été mis à jour en `4.7` par l'éditeur : cette déclaration est conservée, sans migration supplémentaire.

## Caméra et commandes

La caméra démarre en **Suivi** : elle suit le barycentre des survivants et s'éloigne doucement quand le groupe s'étale. **F** passe en **Libre**, une vue orbitale avec un point d'observation déplaçable. La vue reste alors à l'endroit choisi pendant que les agents continuent leur vol. **G** ou **Home / Début** recentre sur le groupe actuel. **C** active **Cinématique** ; un second C revient au Suivi. F permet aussi de reprendre la caméra Libre depuis Cinématique. La souris contrôle seulement le mode Libre.

| Commande | Effet |
|---|---|
| Clic droit maintenu + souris | Orbite autour du point d'observation |
| Molette haut / bas | Zoom avant / arrière, distance limitée à 6–220 m |
| Flèches haut / bas, ou W / Z et S | Pan avant / arrière sur le plan horizontal de la vue |
| Flèches gauche / droite, ou A / Q et D | Pan gauche / droite |
| PageUp ou E | Monter |
| PageDown | Descendre en Libre |
| G ou Home | Recentrer sur le groupe |
| F | Alterner Suivi / Libre |
| C | Activer Cinématique / revenir au Suivi |
| F11 ou Alt+Entrée | Basculer Fenêtré / Plein écran |
| TAB | Afficher / masquer le panneau de contrôles |
| H | Afficher / masquer l'aide caméra en bas à gauche |

Les touches sont définies par des **Input Actions dans `project.godot`**. C est réservé à Cinématique ; Q sert au déplacement à gauche. Le pan vaut 24 m/s en temps réel, indépendamment de la vitesse de simulation. L'aide est visible au lancement. **H puis TAB** laissent uniquement le compteur de pertes et les étoiles pour enregistrer une vidéo. Le plein écran utilise [DisplayServer](https://docs.godotengine.org/en/stable/classes/class_displayserver.html) et restaure le mode, la taille et la position de la fenêtre ; celle-ci reste redimensionnable.

### Caméra cinématique

Les six cadrages sont **CHASE, SIDE_LEFT, SIDE_RIGHT, HIGH, LOW_CLOSE et WIDE**. La séquence alterne arrière, gauche, haut, droite, bas et large, toutes les **6–12 secondes de démonstration**, avec des durées déterministes issues de `simulation_seed`. Les offsets changent par une interpolation douce de **2 s**, complétée par le lissage de la position, de l'orientation (slerp) et du FOV. G/Home reprend CHASE par une transition. Une légère oscillation et un très faible roulis évitent la vue rigide sans orbite permanente.

Le cadrage tient compte des positions bleues et du format du viewport ; WIDE prend le relais au-delà de 45 m de dispersion. `action_intensity` résume tirs, esquives, explosions et hostiles proches pour élargir légèrement le FOV. Une correction d'enveloppe et un raycast sur le déplacement de la caméra limitent l'entrée dans les astéroïdes. Le micro-shake est exporté, **désactivé par défaut**. La caméra n'est pas un agent et ne transmet aucune consigne de trajectoire aux chasseurs.

## Contrôles de démonstration M7–M8

Le panneau **Contrôles**, visible au lancement, est placé à droite : largeur **264 px**, marge **18 px**, fond spatial bleu sombre transparent et accent cyan. Il utilise uniquement les nœuds Control Godot standards. **TAB** le masque et le réaffiche. Les étoiles restent visibles dans les deux cas.

| Contrôle | Bornes | Valeur initiale / effet |
|---|---|---|
| Vitesse | 0,5–2,5×, pas 0,1 | **1,7×** ; changement immédiat |
| BlueShip −/+ | 5–20 | 10 ; ajoute ou retire des chasseurs |
| PatrolDrone −/+ | 0–8 | Cible du niveau, puis override explicite |
| Interceptor −/+ | 0–8 | Cible du niveau, puis override explicite |
| Mouvement | 0,5–2,0, pas 0,1 | **1,2** ; amplitude du wander X/Y/Z |
| Espacement | 0,8–1,4, pas 0,1 | 1,0 ; distances de séparation, seuil critique et confort de cohésion |
| Reset agents | Bouton | Efface seulement les deux overrides ennemis |
| Plein écran | Toggle | Même bascule que F11 |
| Caméra cinématique | Toggle | Synchronisé avec C et F |
| Mode spectacle | Bouton | Manuel 3, vitesse 1,7×, mouvement 1,3, verts 5, rouges 4, espacement 1,0 et Cinématique |
| Normal | Bouton | Vitesse 1,7×, mouvement 1,2, populations du niveau courant, espacement 1,0 et Suivi |

Les presets réutilisent les réglages runtime. Ils ne recréent pas la scène et conservent les morts, la distance, les BlueShip et le champ. Normal conserve la difficulté courante. HUD, panneau et aide sont ancrés dans un viewport logique 1280×720, adapté aux fenêtres **1280×720, 1920×1080 et 800×450**.

Les étoiles **★☆☆ / ★★☆ / ★★★** représentent toujours `difficulty_level` effectif, avec les étoiles pleines jaunes et les vides gris. Elles changent immédiatement avec les touches 0/1/2/3 et avec les seuils AUTO. Aucun texte « Niveau », « AUTO » ou « MANUEL » ne les accompagne.

### Vitesse et caméra

`simulation_speed_multiplier` utilise **Engine.time_scale** : agents, lasers, délais de poursuite/rafale/remplacement et explosions suivent la même horloge. Les vitesses physiques de base M6 sont conservées. Le taux physique monte par multiples de 60 : **60 Hz jusqu'à 1×, 120 Hz jusqu'à 2×, 180 Hz au-delà**, ce qui conserve un pas de simulation au plus égal à 1/60 s. Les paramètres Engine précédents sont restaurés à la fermeture de la scène. Cette méthode suit les recommandations de la [documentation Engine](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-time-scale).

Le suivi utilise le temps de simulation pour rester fluide ; le pan libre utilise le delta divisé par `time_scale`. Orbite et zoom réagissent directement à la souris. Le panneau consomme ses événements : cliquer un slider/bouton ne déclenche ni orbite ni zoom ; relâcher le clic droit au-dessus du panneau termine aussi une orbite commencée dans l'espace. Les contrôles n'accaparent pas le focus clavier. Aucun paramètre de combat n'est exposé.

### Populations et réglages

Les comptes ennemis affichés sont des **cibles**, pas des statistiques de destruction. `manual_drone_count_override` et `manual_interceptor_count_override` valent **−1** par défaut : utiliser la difficulté. Une valeur **0–8** maintient la population choisie, même après un changement de niveau. **Reset agents** restaure −1 : les populations reprennent les nombres du niveau courant. Les morts, la distance, l'environnement, les BlueShip et les autres sliders restent inchangés.

Les ajouts runtime sont espacés de **0,4 s de simulation**. Les ennemis réutilisent leurs apparitions sûres ; les nouveaux BlueShip apparaissent autour/derrière le groupe, avec contrôle des autres corps et du rayon des rochers. Chaque chasseur reçoit une seed unique, les groupes et les connexions de combat, puis rejoint les règles locales. Une position encombrée retarde l'ajout et provoque une nouvelle tentative.

Une réduction BlueShip retire les excédents **sans explosion ni mort**. Les pertes réelles diminuent le compte restant : elles ne sont **jamais remplacées automatiquement**. `ship_spawn_count` et `ship_retired_count` permettent le bilan **vivants + morts + retraits = créations**. Le nombre initial et toutes les métriques M6 sont conservés.

Mouvement et Espacement sont interpolés sur les chasseurs existants ; les futurs chasseurs reçoivent les valeurs courantes. Mouvement multiplie seulement le wander naturel, sans modifier séparation, cohésion ou collisions. Espacement multiplie les trois distances indiquées, avec des bornes limitées ; il ne change pas les poids des forces ou les hitboxes. Ces contrôles sont des paramètres extérieurs d'expérimentation, pas des perceptions supplémentaires des agents.

Exemple de démonstration : **3**, Interceptor **5**, PatrolDrone **6**, BlueShip **15**, Vitesse **1,8×**, Mouvement **1,5**, puis **H** et **TAB** pour observer la scène.

## Agents et obstacles actuels

- **Type 1 — BlueShip** : `CharacterBody3D`, chasseur spatial original en primitives Godot. Long fuselage bleu clair, nez très pointu vers −Z, cockpit sombre/cyan surélevé, deux grosses nacelles bleu profond, ailes balayées et pointes arrière, deux pylônes et moteurs intégrés. Les flammes cyan à deux couches s'allongent selon la vitesse et pulsent avec des phases individuelles. Le banking plus marqué concerne seulement les visuels ; les deux boîtes physiques du M7 restent identiques.
- **Type 2 — PatrolDrone** : `CharacterBody3D`, drone vert avec un corps hexagonal court, un capteur lumineux vert-cyan, de petites ailes, une dérive et deux propulseurs. Il conserve sa patrouille par waypoints et son évitement local. Il devient le premier **agent hostile destructible**, avec **4 HP**, sans poursuite ni tirs ennemis.
- **Type 3 — Interceptor** : chasseur rouge pointu, cockpit sombre, ailes courtes et moteurs orange. Il détecte localement un BlueShip, le poursuit temporairement et tire par rafales, puis se désengage. **4 HP**, primitives Godot uniquement.
- **Obstacle environnemental — SpaceAsteroid** : `StaticBody3D` indépendant. Deux à quatre volumes low-poly déformés composent un rocher irrégulier ; les grands combinent aussi des blocs anguleux. Petits : 1–2 m ; moyens : 2–4 m ; grands : 4–7 m de diamètre nominal. Échelles, orientations des lobes et palettes gris foncé/gris clair/brun varient par graine. Chaque volume possède une enveloppe convexe qui reprend les points déformés du mesh. La racine physique n'est pas mise à l'échelle. Chaque astéroïde tourne autour d'un axe individuel à environ 0,055–0,12 rad/s ; visuels et collisions tournent ensemble au pas physique, sans translation. **Les astéroïdes sont des obstacles, pas des agents.**

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

Le `Marker3D` **Visuals/Muzzle**, placé à **Z = −3,5 m** devant le nouveau nez, donne le vrai départ du projectile. La direction initiale estime une seule fois le déplacement de la cible pendant le vol, à vitesse constante. Elle doit rester dans le même cône frontal. Le chasseur ne s'oriente pas vers la cible ; après son lancement, le projectile suit une droite sans correction ni guidage.

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
scenes/blue_ship_visuals.tscn Silhouette spatiale M8 en primitives
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
```

Les 650 étoiles sont distribuées en trois couches : lointaine (environ 62 %), intermédiaire (30 %) et proche (8 %). Leurs profondeurs et tailles diffèrent ; elles restent immobiles dans le monde jusqu'au recyclage aux bords du volume observé. Le déplacement de la caméra produit donc une parallaxe naturelle. Le recyclage fonctionne aussi pendant le pan libre. Deux planètes à atmosphère légère, une petite lune et un quad de nébuleuse discret donnent de la profondeur sans collision. La caméra conserve son dernier centre après la dernière mort.

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
```

La première commande importe les scènes et vérifie le parsing avec les warnings GDScript traités comme erreurs. Les suites historiques utilisent `HistoricalFixture` : décor M1–M7 sans les barrages M8, spreads 38/26 m, plafond 72 et mouvement 1,0. Les trois premières forcent la vitesse 1,0 à 60 Hz ; M7 conserve son profil 1,5× et ses réglages runtime. Cela isole les régressions SMA/combat de la nouvelle mise en scène. La suite M8 exerce le nouveau décor et les nouvelles valeurs. `--fixed-fps 60` exécute ces tests aussi vite que possible ; il ne mesure pas les FPS graphiques.

Validation historique M5 avec **Godot 4.7.2 stable** le 12 octobre 2026, graine **20261012**, pas fixe de 1/60 s. Les résultats M6 ci-dessous ont été mesurés le 13 octobre : suites sans warning ni erreur, codes de sortie 0.

### Validation M8 — 13 octobre 2026

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
- Les tirs sont droits et leur visée initiale est approximative. L'intercepteur poursuit pendant un temps limité ; les BlueShip ne poursuivent pas de cible. Aucun impact rouge n'est observé dans les trois parcours M6, et aucun hostile n'est détruit dans les deux parcours MANUEL 3 : l'équilibrage reste à étudier sur plusieurs graines.
- L'objectif de 9–14 m est un espacement moyen, pas une distance minimale imposée. Les manœuvres peuvent créer des rapprochements brefs ; le test normal M3 mesure 6,71 m au plus près.
- Les hitboxes simplifient et réduisent la silhouette des chasseurs ; les pointes des ailes, le bout du nez et les flammes ne sont pas intégralement couverts.
- Les tailles des astéroïdes sont nominales : la déformation et les lobes irréguliers modifient leurs dimensions exactes.
- L'émission cyan est visible en Compatibility, sans dépendre d'un halo de post-traitement.
- Le déplacement continu en Z ne recale pas l'origine du monde ; des parcours beaucoup plus longs peuvent perdre en précision numérique. Le test de cinq minutes ne mesure pas une session de plusieurs heures ni les FPS graphiques sur cette durée.
- Les réglages extrêmes peuvent disperser le groupe ; les apparitions restent sûres et peuvent être retardées. Les comptes ennemis sont des cibles : la destruction et les délais de remplacement réduisent temporairement les effectifs.
- Engine.time_scale et la fréquence physique sont globaux ; l'application est prévue pour une seule simulation active. Accélérer augmente le nombre de calculs physiques par seconde réelle. L'équilibrage n'a pas été étudié sur plusieurs graines.
- Le cadrage cinématique privilégie le groupe bleu ; des ennemis éloignés peuvent sortir du champ. La correction caméra utilise les enveloppes des rochers et ne constitue pas un solveur de collision complet. Le micro-shake est désactivé ; le test de cadrage porte sur les centres échantillonnés.

## Hors de ce milestone et perspectives

BlueShip, PatrolDrone et Interceptor sont les trois agents implémentés. Les astéroïdes restent indestructibles et ne sont pas des agents. **Agent 4, Bomber/MineLayer, mines, bombes BlueShip, missiles et vagues clavier ne sont pas implémentés.**

Planning : **M8 — Cinématique / barrages / design spatial** réalisé ; **M9 — Agent 4 : Bomber / MineLayer** ; **M10 — Scénarios, bombes BlueShip, étude et finalisation**. Si M10 devient trop volumineux, un **M11 de finalisation** pourra être ajouté. M8 s'arrête à la présentation actuelle.
