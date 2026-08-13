# RetroHexChat — French Rooms — `fr`

Eleven channels, thirteen bots, twenty-five verified feeds. Documentation in
English for the operator; everything a user reads is in French.

French gets an eleventh room because it has an eleventh subject with a real
wire: `#libre`. The English script deliberately refuses to run `#linux` — a
project support room is worth what its maintainers make it — but LinuxFr is a
newsroom, not a help desk, and nobody on IRC carries free-software news in
French.

## Prerequisite

Run [`en.md`](en.md) first. Paste the block below into the Admin Console in one
shot, logged in as an admin who has `/identify`-ed.

## Full script

```
# ══════════════════════════════════════════════════════════
#  RetroHexChat — Installation fr
#  11 salons · 13 bots · flux vérifiés un par un
# ══════════════════════════════════════════════════════════

# ── 1. Salons ────────────────────────────────────────────

/join #france
/cs register
/topic Salon francophone — de Lille à Montréal. Entrez, asseyez-vous, on discute.
/mode +tn

/join #actualites
/cs register
/topic Actualités — Le Figaro, Libération et L'Obs, directement du flux. !Colette sources pour la liste.
/mode +tn

/join #monde
/cs register
/topic Monde — France 24 et RFI. L'international, en français.
/mode +tn

/join #informatique
/cs register
/topic Informatique — Next, Numerama, Les Numériques et 01net. Le support d'un projet reste chez le projet ; ici, on cause.
/mode +tn

/join #mobile
/cs register
/topic Mobile — Frandroid et Journal du Geek. Téléphones, montres et chargeurs incompatibles.
/mode +tn

/join #libre
/cs register
/topic Logiciel libre — LinuxFr et Korben. Les nouvelles, pas le dépannage : le dépannage appartient au projet.
/mode +tn

/join #developpement
/cs register
/topic Développement — Developpez.com sur le fil. Le bistrot, pas le service client.
/mode +tn

/join #jeuxvideo
/cs register
/topic Jeux vidéo — JeuxVideo.com et Gamekult. Pour jouer vraiment, ouvrez le menu Games : 18 classiques dans le navigateur.
/mode +tn

/join #culture
/cs register
/topic Culture — AlloCiné, Télérama et Les Inrocks. Cinéma, séries, musique, expositions.
/mode +tn

/join #sciences
/cs register
/topic Sciences — Futura et Sciences et Avenir. Aucune question bête, seulement des questions non posées.
/mode +tn

/join #economie
/cs register
/topic Économie — La Tribune et L'Usine Digitale. Un titre n'est pas un conseil.
/mode +tn

# ══════════════════════════════════════════════════════════
#  2. Vigie — modération, tous les salons
# ══════════════════════════════════════════════════════════
# Chaque langue a son modérateur : un avertissement qu'on ne lit pas n'en est
# pas un. Muette à l'arrivée comme au départ — elle est dans les onze salons,
# et un videur qui dit bonjour deux fois passe pour un bug.
/bot create Vigie Chef de la securite et de la paix
/bot set Vigie prefix !
/bot set Vigie cooldown 1000
/bot set Vigie mod_action warn
/bot set Vigie mod_spam 5
/bot set Vigie mod_flood 8
/bot set Vigie mod_warn \c04\b[Vigie]\o Doucement, {nickname}. \c05On reste courtois\o ici, sinon Vigie devient désagréable.
/bot set Vigie greeting none
/bot set Vigie farewell none
/bot set Vigie mention_response \c04\b[Vigie]\o Je regarde. \c05Je regarde toujours\o. Tenez-vous bien et tout ira très bien.

/bot addcmd Vigie regles \c04\b[Vigie]\o Version courte : \c05ne soyez pas pénible\o. Version longue : il n'y a pas de version longue.
/bot addcmd Vigie signaler \c04\b[Vigie]\o Quelque chose de louche ? \c05Prévenez un admin\o. Je gère l'automatique, les humains gèrent le reste.

/bot join Vigie #france
/bot join Vigie #actualites
/bot join Vigie #monde
/bot join Vigie #informatique
/bot join Vigie #mobile
/bot join Vigie #libre
/bot join Vigie #developpement
/bot join Vigie #jeuxvideo
/bot join Vigie #culture
/bot join Vigie #sciences
/bot join Vigie #economie

# ══════════════════════════════════════════════════════════
#  3. Margot — hôtesse de #france
# ══════════════════════════════════════════════════════════
# Accueil en notice privé : le nouveau venu s'oriente dans le salon sans
# encombrer l'historique de tout le monde.
/bot create Margot Hotesse du salon francophone
/bot set Margot prefix !
/bot set Margot cooldown 1000
/bot set Margot dice_default 1d20
/bot set Margot greeting \c03\b[Margot]\o Salut {nickname} ! Moi c'est Margot. \c02Essayez !salons\o, !bonjour ou !anglais. Faites comme chez vous.
/bot set Margot greeting_delivery private_notice
/bot set Margot greeter_repeat_window 43200
/bot set Margot farewell none
/bot set Margot mention_response \c03\b[Margot]\o On m'appelle ? Je suis là. \c02Essayez !salons\o.

/bot addcmd Margot salons \c03\b[Margot]\o #france #actualites #monde #informatique #mobile #libre #developpement #jeuxvideo #culture #sciences #economie — \c02onze salons en français\o, et il se passe quelque chose dans chacun.
/bot addcmd Margot bonjour \c03\b[Margot]\o \c02Bonjour\o, {nickname} ! Café passé, clavier propre, la journée commence.
/bot addcmd Margot anglais \c03\b[Margot]\o Il y a aussi des salons en anglais, {nickname} : \c02#lobby, #tech, #news\o et d'autres. La langue se change dans la barre d'outils.
/bot addcmd Margot accents \c03\b[Margot]\o Les noms de salon sont sans accent, {nickname} — \c02le client ne transforme en lien que l'ASCII\o. À l'intérieur, écrivez normalement.

/bot join Margot #france

# ══════════════════════════════════════════════════════════
#  4. Bots de flux — un par salon
# ══════════════════════════════════════════════════════════
# Chaque adresse ci-dessous a été récupérée par le fetcher de production et lue
# par le parseur de l'application avant d'être écrite ici. Le premier relevé
# publie la page reçue et l'enregistre ; ensuite, seul le nouveau sort.
#
# Une première lecture arrive par lots, pas d'un coup : la protection anti-flood
# vit dans la session de chaque lecteur et ignore d'office qui la dépasse. Rien
# n'est jeté — un flux en retard revient en moins d'une minute pour la suite.

# ── Gaspard — #france ────────────────────────────────────
# Pas d'accueil : dans ce salon, c'est Margot qui reçoit.
/bot create Gaspard Reporter de permanence
/bot set Gaspard prefix !
/bot set Gaspard cooldown 1000
/bot set Gaspard rss_interval 20
/bot set Gaspard greeting none
/bot set Gaspard farewell none
/bot set Gaspard mention_response \c03\b[Gaspard]\o Je lis Le Monde et France Info. \c02!sources\o liste les flux.
/bot addcmd Gaspard sources \c03\b[Gaspard]\o Le Monde et France Info, relevés \c02toutes les vingt minutes\o.
/bot join Gaspard #france
/bot rss add Gaspard https://www.lemonde.fr/rss/une.xml #france
/bot rss add Gaspard https://www.francetvinfo.fr/titres.rss #france

# ── Colette — #actualites ────────────────────────────────
/bot create Colette Redactrice en chef du fil
/bot set Colette prefix !
/bot set Colette cooldown 1000
/bot set Colette rss_interval 20
/bot set Colette greeting \c02\b[Colette]\o Bienvenue dans #actualites, {nickname}. \c14Les titres arrivent seuls\o — !sources dit d'où.
/bot set Colette greeting_delivery private_notice
/bot set Colette greeter_repeat_window 43200
/bot set Colette farewell none
/bot set Colette mention_response \c02\b[Colette]\o Je publie ce que le flux envoie. \c14!sources\o pour la liste, !premiere pour le reste.
/bot addcmd Colette sources \c02\b[Colette]\o Le Figaro, Libération et L'Obs, relevés \c14toutes les vingt minutes\o.
/bot addcmd Colette premiere \c02\b[Colette]\o Le premier relevé d'un flux publie la page actuelle et l'enregistre. Ensuite, \c14seuls les nouveaux articles sortent\o.
/bot join Colette #actualites
/bot rss add Colette https://www.lefigaro.fr/rss/figaro_actualites.xml #actualites
/bot rss add Colette https://www.liberation.fr/arc/outboundfeeds/rss-all/?outputType=xml #actualites
/bot rss add Colette https://www.nouvelobs.com/rss.xml #actualites

# ── Renaud — #monde ──────────────────────────────────────
/bot create Renaud Correspondant a l etranger
/bot set Renaud prefix !
/bot set Renaud cooldown 1000
/bot set Renaud rss_interval 30
/bot set Renaud greeting \c10\b[Renaud]\o Bonjour {nickname}. \c06France 24 et RFI\o arrivent ici tout seuls. !sources pour la liste.
/bot set Renaud greeting_delivery private_notice
/bot set Renaud greeter_repeat_window 43200
/bot set Renaud farewell none
/bot set Renaud mention_response \c10\b[Renaud]\o L'international, en français. \c06!sources\o liste les deux flux.
/bot addcmd Renaud sources \c10\b[Renaud]\o France 24 et RFI, relevés \c06toutes les demi-heures\o.
/bot join Renaud #monde
/bot rss add Renaud https://www.france24.com/fr/rss #monde
/bot rss add Renaud https://www.rfi.fr/fr/rss #monde

# ── Blaise — #informatique ───────────────────────────────
/bot create Blaise Veilleur informatique
/bot set Blaise prefix !
/bot set Blaise cooldown 1000
/bot set Blaise rss_interval 30
/bot set Blaise greeting \c12\b[Blaise]\o Salut {nickname}. \c10Next, Numerama, Les Numériques et 01net\o tombent ici. !sources pour la liste, !support avant de demander.
/bot set Blaise greeting_delivery private_notice
/bot set Blaise greeter_repeat_window 43200
/bot set Blaise farewell none
/bot set Blaise mention_response \c12\b[Blaise]\o Quatre flux informatiques sur le fil. \c10!sources\o dit lesquels.
/bot addcmd Blaise sources \c12\b[Blaise]\o Next, Numerama, Les Numériques et 01net, relevés \c10toutes les demi-heures\o.
/bot addcmd Blaise support \c12\b[Blaise]\o Le support d'un projet est chez le projet, {nickname} — ceux qui répondent bien sont ceux qui le maintiennent. \c10Ici, c'est le bistrot\o.
/bot join Blaise #informatique
/bot rss add Blaise https://next.ink/feed/ #informatique
/bot rss add Blaise https://www.numerama.com/feed/ #informatique
/bot rss add Blaise https://www.lesnumeriques.com/rss.xml #informatique
/bot rss add Blaise https://www.01net.com/actualites/feed/ #informatique

# ── Amelie — #mobile ─────────────────────────────────────
/bot create Amelie Testeuse de telephones
/bot set Amelie prefix !
/bot set Amelie cooldown 1000
/bot set Amelie rss_interval 45
/bot set Amelie greeting \c13\b[Amelie]\o Entrez, {nickname}. \c11Frandroid et Journal du Geek\o sur le fil — !sources pour la liste.
/bot set Amelie greeting_delivery private_notice
/bot set Amelie greeter_repeat_window 43200
/bot set Amelie farewell none
/bot set Amelie mention_response \c13\b[Amelie]\o Téléphones, montres et chargeurs qui ne rentrent nulle part. \c11!sources\o liste le fil.
/bot addcmd Amelie sources \c13\b[Amelie]\o Frandroid et Journal du Geek, relevés \c11toutes les 45 minutes\o.
/bot join Amelie #mobile
/bot rss add Amelie https://www.frandroid.com/feed #mobile
/bot rss add Amelie https://www.journaldugeek.com/feed/ #mobile

# ── Ambroise — #libre ────────────────────────────────────
/bot create Ambroise Gardien des notes de version
/bot set Ambroise prefix !
/bot set Ambroise cooldown 1000
/bot set Ambroise rss_interval 45
/bot set Ambroise greeting \c03\b[Ambroise]\o Bienvenue dans #libre, {nickname}. \c09LinuxFr et Korben\o arrivent seuls. !sources pour la liste, !pourquoi pour le reste.
/bot set Ambroise greeting_delivery private_notice
/bot set Ambroise greeter_repeat_window 43200
/bot set Ambroise farewell none
/bot set Ambroise mention_response \c03\b[Ambroise]\o Je porte les nouvelles du libre. \c09!sources\o pour la liste.
/bot addcmd Ambroise sources \c03\b[Ambroise]\o LinuxFr et Korben, relevés \c09toutes les 45 minutes\o.
/bot addcmd Ambroise pourquoi \c03\b[Ambroise]\o Le support d'un projet vaut ce que valent ses mainteneurs, {nickname}, et ils ne sont pas ici. \c09Les nouvelles, en revanche\o, personne ne les portait en français.
/bot join Ambroise #libre
/bot rss add Ambroise https://linuxfr.org/news.atom #libre
/bot rss add Ambroise https://korben.info/feed #libre

# ── Denis — #developpement ───────────────────────────────
/bot create Denis Lecteur de commits des autres
/bot set Denis prefix !
/bot set Denis cooldown 1000
/bot set Denis rss_interval 60
/bot set Denis greeting \c06\b[Denis]\o Salut {nickname}. \c13Developpez.com\o sur le fil. !sources pour la liste.
/bot set Denis greeting_delivery private_notice
/bot set Denis greeter_repeat_window 43200
/bot set Denis farewell none
/bot set Denis mention_response \c06\b[Denis]\o Je lis Developpez.com. \c13!sources\o pour la liste.
/bot addcmd Denis sources \c06\b[Denis]\o Developpez.com, relevé \c13toutes les heures\o.
/bot join Denis #developpement
/bot rss add Denis https://www.developpez.com/index/rss #developpement

# ── Lulu — #jeuxvideo ────────────────────────────────────
/bot create Lulu Patronne de la salle d arcade
/bot set Lulu prefix !
/bot set Lulu cooldown 1000
/bot set Lulu rss_interval 45
/bot set Lulu greeting \c12\b[Lulu]\o Entrez, {nickname} ! \c10JeuxVideo.com et Gamekult\o sur le fil, et le menu Games ouvre 18 classiques dans le navigateur. !sources, !jouer.
/bot set Lulu greeting_delivery private_notice
/bot set Lulu greeter_repeat_window 43200
/bot set Lulu farewell none
/bot set Lulu mention_response \c12\b[Lulu]\o Les nouvelles du jeu, c'est moi. \c10!jouer\o explique comment jouer ici même.
/bot addcmd Lulu sources \c12\b[Lulu]\o JeuxVideo.com et Gamekult, relevés \c10toutes les 45 minutes\o.
/bot addcmd Lulu jouer \c12\b[Lulu]\o Ouvrez le menu \c10Games\o en haut, {nickname} : DOOM, Quake, Wolfenstein et six aventures ScummVM, dans le navigateur.
/bot join Lulu #jeuxvideo
/bot rss add Lulu https://www.jeuxvideo.com/rss/rss.xml #jeuxvideo
/bot rss add Lulu https://www.gamekult.com/feed.xml #jeuxvideo

# ── Jacques — #culture ───────────────────────────────────
/bot create Jacques Ouvreur de la salle obscure
/bot set Jacques prefix !
/bot set Jacques cooldown 1000
/bot set Jacques rss_interval 60
/bot set Jacques greeting \c05\b[Jacques]\o Bienvenue, {nickname}. \c13AlloCiné, Télérama et Les Inrocks\o arrivent chaque heure. !sources pour la liste.
/bot set Jacques greeting_delivery private_notice
/bot set Jacques greeter_repeat_window 43200
/bot set Jacques farewell none
/bot set Jacques mention_response \c05\b[Jacques]\o Cinéma, séries, musique, expositions. \c13!sources\o liste le fil.
/bot addcmd Jacques sources \c05\b[Jacques]\o AlloCiné, Télérama et Les Inrocks, relevés \c13toutes les heures\o.
/bot join Jacques #culture
/bot rss add Jacques https://www.allocine.fr/rss/news.xml #culture
/bot rss add Jacques https://www.telerama.fr/rss/une.xml #culture
/bot rss add Jacques https://www.lesinrocks.com/feed/ #culture

# ── Camille — #sciences ──────────────────────────────────
/bot create Camille Gardienne des observations
/bot set Camille prefix !
/bot set Camille cooldown 1000
/bot set Camille rss_interval 60
/bot set Camille greeting \c11\b[Camille]\o Bonjour {nickname}. \c02Futura et Sciences et Avenir\o arrivent chaque heure. !sources pour la liste.
/bot set Camille greeting_delivery private_notice
/bot set Camille greeter_repeat_window 43200
/bot set Camille farewell none
/bot set Camille mention_response \c11\b[Camille]\o Vulgarisation, sans péage. \c02!sources\o liste le fil.
/bot addcmd Camille sources \c11\b[Camille]\o Futura et Sciences et Avenir, relevés \c02toutes les heures\o.
/bot join Camille #sciences
/bot rss add Camille https://www.futura-sciences.com/rss/actualites.xml #sciences
/bot rss add Camille https://www.sciencesetavenir.fr/rss.xml #sciences

# ── Odile — #economie ────────────────────────────────────
/bot create Odile Observatrice des marches
/bot set Odile prefix !
/bot set Odile cooldown 1000
/bot set Odile rss_interval 30
/bot set Odile greeting \c07\b[Odile]\o Bonjour {nickname}. \c14La Tribune et L'Usine Digitale\o sur le fil — !sources pour la liste, !avertissement avant d'y croire.
/bot set Odile greeting_delivery private_notice
/bot set Odile greeter_repeat_window 43200
/bot set Odile farewell none
/bot set Odile mention_response \c07\b[Odile]\o Je lis La Tribune et L'Usine Digitale. \c14!sources\o pour la liste.
/bot addcmd Odile sources \c07\b[Odile]\o La Tribune et L'Usine Digitale, relevés \c14toutes les demi-heures\o.
/bot addcmd Odile avertissement \c07\b[Odile]\o Un titre n'est pas un conseil, {nickname}. \c14Je lis des flux\o, pas l'avenir.
/bot join Odile #economie
/bot rss add Odile https://www.latribune.fr/feed.xml #economie
/bot rss add Odile https://www.usine-digitale.fr/rss #economie
```

---

## Verification

```
/bot list
/bot info Vigie
/admin channel list
```

`!Gaspard rss list` in `#france` shows what a bot actually stored — the check
that matters after a paste.

## Channel reference

| channel | host / wire bot | feeds |
|---|---|---|
| `#france` | **Margot**, Gaspard | Le Monde, France Info |
| `#actualites` | **Colette** | Le Figaro, Libération, L'Obs |
| `#monde` | **Renaud** | France 24, RFI |
| `#informatique` | **Blaise** | Next, Numerama, Les Numériques, 01net |
| `#mobile` | **Amelie** | Frandroid, Journal du Geek |
| `#libre` | **Ambroise** | LinuxFr, Korben |
| `#developpement` | **Denis** | Developpez.com |
| `#jeuxvideo` | **Lulu** | JeuxVideo.com, Gamekult |
| `#culture` | **Jacques** | AlloCiné, Télérama, Les Inrocks |
| `#sciences` | **Camille** | Futura, Sciences et Avenir |
| `#economie` | **Odile** | La Tribune, L'Usine Digitale |

**Vigie** stands in all eleven and greets in none of them. All channels are `+tn`.

`#sciences` is plural where the English `#science` is singular — that is what
keeps them from colliding, and it happens to be the natural French word anyway.
