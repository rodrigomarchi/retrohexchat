# RetroHexChat — Production Provisioning (English)

Forty-eight channels, twenty-five bots: twelve rooms to talk in, a room for each
Retro Game plus `#retro-games` for all of them, and a room for each arcade game,
whose plays `#arcade` also hears. The room choices trace to
`scripts/research/irc_census` — a live `/LIST` sweep of 95 public IRC networks,
of which 59 answered with 49,973 channels. Regenerate it with
`scripts/research/irc_census/run.sh`.

**This is the base script and it runs first.** It is the only one that sets the
server's name, description and welcome message; every language script in this
directory adds rooms on top of it and touches no server-wide setting. The
lusophone room that used to live here now opens the Portuguese script —
see [`README.md`](README.md) for the whole set.

## Why these twelve

The census kills the intuition that a new server should offer a room per interest.
Forty-four percent of listed channels on IRC hold exactly one person, and the median
live room holds **14**. Split a small population across a dozen rooms and you get a
dozen empty rooms. So: few rooms, each with a reason to come back.

Where to compete came from contestability — demand divided by the strength of whoever
already owns it:

| we enter | live rooms | networks | occupancy | biggest incumbent | why |
|---|---|---|---|---|---|
| social/chat | 2,332 | 47 | 113,089 | 2,106 (p90 only **91**) | most demand on IRC, low ceiling |
| retro/vintage | 35 | 9 | 880 | **83** | the weakest incumbent on IRC |
| gaming via trivia | 162 | 32 | 6,151 | 1,007 (p90 **68**) | fragmented, and trivia is native here |

| we stay out | live rooms | occupancy | biggest incumbent | why |
|---|---|---|---|---|
| linux/foss | 987 | 49,263 | **2,494** | the project's maintainers are the room's value |
| programming/dev | 934 | 51,975 | **1,728** | same — `#python` without CPython is an empty room |
| security/hacking | 57 | 4,166 | 1,079 (p90 **178**) | concentrated, high barrier |
| adult/dating | 46 | 3,847 | 734 (p90 **264**) | highest barrier per room, plus moderation risk |
| filesharing/xdcc | 195 | 9,440 | 683 | legal exposure |

**The rule:** where a room's value is an upstream project, we cannot compete. Where its
value is the people in it, we can. Half of IRC's top 1% is the second kind — the biggest
of them are ordinary hangouts whose entire offer is a welcome message and a bot.

---

## Prerequisite

Start the server with `ROOT_ADMINS=Troll mix phx.server`, log in as Troll, `/identify`,
then open the Admin Console from the toolbar.

Run this script before any of the language scripts: it is the one that names the
server, and the rooms it opens are the ones the other scripts assume already exist.

The whole block below pastes in one shot. The console executes line by line and carries
the context forward — `/join` really joins, moves the active channel and grants ops
there, and `/topic` and `/mode` are applied for real, not merely described. Lines
starting with `#` are comments and are skipped, so the annotations travel with the
script. It does not assume which channel you are standing in: every channel, `#lobby`
included, is joined explicitly.

## Full script

```
# ══════════════════════════════════════════════════════════
#  RetroHexChat — Production Setup
#  48 channels · 25 bots · derived from the IRC census
#  The base script. Language scripts in this directory add rooms on top.
# ══════════════════════════════════════════════════════════

# ── 1. Server ────────────────────────────────────────────
# The only script that sets these. A language script that set them again would
# rename the server for everyone in whichever language was pasted last.
/admin server set server_name RetroHexChat
/admin server set server_description The retro chat experience you never knew you missed. Windows 98 called — it wants you back.
/admin server set welcome_message Welcome to RetroHexChat. Rooms in a dozen languages, none of them empty. Type /help to get started.
/admin server set registration open

# ── 2. Channels ──────────────────────────────────────────

# #lobby — the single social room. Not four: the median live room on IRC
# holds 14 people, so a split crowd is an empty crowd.
# Joined explicitly rather than assumed: the console starts on whatever channel
# the admin happens to be in, and /cs register acts on the active one.
# Every room then publishes its archive, says its language and says what it is
# about: /cs language en draws the English flag beside the name, /cs category a
# subject plaque beside the flag. All three are founder-only, and the founder is
# whoever pasted this.
/join #lobby
/cs register
/cs archive on
/cs language en
/cs category social
/topic The lobby — one room, everyone in it. Pull up a chair, the pixels are warm.
/mode +tn

# #trivia — the retention engine. Native trivia capability with scoring;
# the rest of IRC still runs this on eggdrop from 1997.
/join #trivia
/cs register
/cs archive on
/cs language en
/cs category games
/topic Trivia — !Wanda trivia start to begin, !Wanda answer <guess> to play, !Wanda trivia score for the board. Six categories.
/mode +tn

# #arcade — DOOM, Quake, Wolfenstein and ScummVM in the browser.
# The largest #arcade on IRC has 15 people. No network offers this.
/join #arcade
/cs register
/cs archive on
/cs language en
/cs category games
/topic Arcade — 18 classics running in your browser, and who just started one. Each game has its own room too. Open the Games menu, or ask !Pixel games for the catalogue.
/mode +tn

# #retro — the lowest bar on IRC: the biggest #retro anywhere holds 25 people,
# the biggest retro room of any name holds 83. Amiga, C64, DOS, demoscene, BBS.
/join #retro
/cs register
/cs archive on
/cs language en
/cs category retro
/topic Retro computing — Amiga, C64, Atari, DOS, demoscene, BBS. If it booted from a floppy, it belongs here.
/mode +tn

# #tech — conversation, not project support. We do not run #python or #linux;
# those rooms are worth what their maintainers make them.
/join #tech
/cs register
/cs archive on
/cs language en
/cs category tech
/topic Tech talk — hardware, self-hosting, sysadmin war stories. Project support lives upstream; this is the pub.
/mode +tn

# #news — politics/news is fragmented across 28 networks with no owner: the
# largest room holds 450 and the p90 is 77. Driven by feeds, not opinion.
/join #news
/cs register
/cs archive on
/cs language en
/cs category news
/topic News — headlines pulled from feeds by Gazeta. !Gazeta rss list to see the sources.
/mode +tn

# #help — the most universal channel on IRC: alive on 30 of the 59 networks
# that answered the census.
/join #help
/cs register
/cs archive on
/cs language en
/cs category help
/topic Lost? Ask here. !Harold faq for the basics, or /help for the manual.
/mode +tn

# ══════════════════════════════════════════════════════════
#  2b. Wire rooms — subjects that survive on a feed
# ══════════════════════════════════════════════════════════
# The "few rooms, densely populated" rule is about conversation. A room with
# three people and nothing happening is dead; a room with three people and a
# wire still has something on it every hour. Feeds are the only way a small
# server offers something before it has a crowd — so these rooms are judged by
# whether anyone owns the subject, not by whether we can out-populate it.

# #foss — linux/foss is the largest technical block on IRC (987 live rooms,
# 49,263 occupancy), but the rooms that hold it are project support: #linux
# holds 2,494 because its regulars answer questions. Nobody owns the *news*:
# the census found no live #foss room on any network.
/join #foss
/cs register
/cs archive on
/cs language en
/cs category dev
/topic Free software news — releases, kernels, distros. Fed by LWN, Phoronix and It's FOSS.
/mode +tn

# #security — the densest subject measured: only 57 live rooms, but a p90 of
# 178, the highest of any category. People who arrive stay. Advisories and
# incident writeups are archetypal feed content.
/join #security
/cs register
/cs archive on
/cs language en
/cs category security
/topic Security advisories — Krebs, The Hacker News, BleepingComputer and research feeds. Read before you patch.
/mode +tn

# #ai — seven live rooms across three networks in the whole census, the
# emptiest subject measured and the busiest one outside IRC. Nobody has claimed it.
/join #ai
/cs register
/cs archive on
/cs language en
/cs category ai
/topic Machine learning — arXiv preprints and model releases as they land.
/mode +tn

# #science — 76 live rooms spread over 13 networks, the biggest holding 163.
# Distributed demand, no owner.
/join #science
/cs register
/cs archive on
/cs language en
/cs category science
/topic Science — arXiv astrophysics, NASA, Live Science and discovery feeds. Bring questions.
/mode +tn

# #anime — alive on 12 networks with 802 people between them, and the largest
# room holds only 279. A familiar name with a weak incumbent.
/join #anime
/cs register
/cs archive on
/cs language en
/cs category culture
/topic Anime — news and episode releases via Anime News Network and LiveChart.
/mode +tn

# ══════════════════════════════════════════════════════════
#  2c. Retro Games rooms — one per game, and the feed
# ══════════════════════════════════════════════════════════
# Every in-page Retro Game has a room named after it, where its matches are
# announced and people find someone to play; the strip under the topic offers
# a seat. #retro-games carries every game's results at once. They are ordinary
# rooms: whoever pastes this founds them, and their topic, modes and archive are
# the founder's to change. Scoreboard (below) announces the matches in them.
# A game added to the catalogue later needs its room added here and pasted.

/join #hex-pong
/cs register
/cs archive on
/cs language en
/cs category games
/topic Results and rankings of Hex Pong, and people to play with. Everything said here is published in a public archive.
/mode +tn

/join #light-trails
/cs register
/cs archive on
/cs language en
/cs category games
/topic Results and rankings of Light Trails, and people to play with. Everything said here is published in a public archive.
/mode +tn

/join #pixel-tanks
/cs register
/cs archive on
/cs language en
/cs category games
/topic Results and rankings of Pixel Tanks, and people to play with. Everything said here is published in a public archive.
/mode +tn

/join #star-duel
/cs register
/cs archive on
/cs language en
/cs category games
/topic Results and rankings of Star Duel, and people to play with. Everything said here is published in a public archive.
/mode +tn

/join #gravity-well
/cs register
/cs archive on
/cs language en
/cs category games
/topic Results and rankings of Gravity Well, and people to play with. Everything said here is published in a public archive.
/mode +tn

/join #debris-field
/cs register
/cs archive on
/cs language en
/cs category games
/topic Results and rankings of Debris Field, and people to play with. Everything said here is published in a public archive.
/mode +tn

/join #block-breakers
/cs register
/cs archive on
/cs language en
/cs category games
/topic Results and rankings of Block Breakers, and people to play with. Everything said here is published in a public archive.
/mode +tn

/join #hex-warlords
/cs register
/cs archive on
/cs language en
/cs category games
/topic Results and rankings of Hex Warlords, and people to play with. Everything said here is published in a public archive.
/mode +tn

/join #hex-raid
/cs register
/cs archive on
/cs language en
/cs category games
/topic Results and rankings of Hex Raid, and people to play with. Everything said here is published in a public archive.
/mode +tn

/join #hex-boxing
/cs register
/cs archive on
/cs language en
/cs category games
/topic Results and rankings of Hex Boxing, and people to play with. Everything said here is published in a public archive.
/mode +tn

/join #hex-outlaw
/cs register
/cs archive on
/cs language en
/cs category games
/topic Results and rankings of Hex Outlaw, and people to play with. Everything said here is published in a public archive.
/mode +tn

/join #hex-invaders
/cs register
/cs archive on
/cs language en
/cs category games
/topic Results and rankings of Hex Invaders, and people to play with. Everything said here is published in a public archive.
/mode +tn

/join #hex-enduro
/cs register
/cs archive on
/cs language en
/cs category games
/topic Results and rankings of Hex Enduro, and people to play with. Everything said here is published in a public archive.
/mode +tn

/join #hex-tennis
/cs register
/cs archive on
/cs language en
/cs category games
/topic Results and rankings of Hex Tennis, and people to play with. Everything said here is published in a public archive.
/mode +tn

/join #hex-skiing
/cs register
/cs archive on
/cs language en
/cs category games
/topic Results and rankings of Hex Skiing, and people to play with. Everything said here is published in a public archive.
/mode +tn

/join #hex-frost
/cs register
/cs archive on
/cs language en
/cs category games
/topic Results and rankings of Hex Frost, and people to play with. Everything said here is published in a public archive.
/mode +tn

/join #hex-hockey
/cs register
/cs archive on
/cs language en
/cs category games
/topic Results and rankings of Hex Hockey, and people to play with. Everything said here is published in a public archive.
/mode +tn

/join #hex-jungle
/cs register
/cs archive on
/cs language en
/cs category games
/topic Results and rankings of Hex Jungle, a game for one player. Everything said here is published in a public archive.
/mode +tn

/join #hex-solitaire
/cs register
/cs archive on
/cs language en
/cs category games
/topic Results and rankings of Hex Solitaire, Klondike for one player. Everything said here is published in a public archive.
/mode +tn

/join #retro-games
/cs register
/cs archive on
/cs language en
/cs category games
/topic Every Retro Games match as it finishes. Each game has its own channel too. This channel is archived publicly.
/mode +tn


# ══════════════════════════════════════════════════════════
#  2d. Arcade rooms — one per arcade game
# ══════════════════════════════════════════════════════════
# Every arcade game has a room named after it, the same name as its page
# (/games/doom-shareware is #doom-shareware). Pixel (below) says in it whoever
# starts the game, and says it again in #arcade. That is all there is to say:
# an arcade game runs in a tab of its own and never reports a score or how long
# it was played. The strip under the topic opens the game. Like the Retro Games
# rooms they are ordinary rooms, founded by whoever pastes this; a game added
# to the arcade later needs its room added here and pasted.

/join #doom-shareware
/cs register
/cs archive on
/cs language en
/cs category games
/topic DOOM: Knee-Deep in the Dead in your browser: press Play under the topic. Whoever starts it is announced here. Everything said here is published in a public archive.
/mode +tn

/join #freedoom1
/cs register
/cs archive on
/cs language en
/cs category games
/topic Freedoom: Phase 1 in your browser: press Play under the topic. Whoever starts it is announced here. Everything said here is published in a public archive.
/mode +tn

/join #freedoom2
/cs register
/cs archive on
/cs language en
/cs category games
/topic Freedoom: Phase 2 in your browser: press Play under the topic. Whoever starts it is announced here. Everything said here is published in a public archive.
/mode +tn

/join #freedm
/cs register
/cs archive on
/cs language en
/cs category games
/topic FreeDM in your browser: press Play under the topic. Whoever starts it is announced here. Everything said here is published in a public archive.
/mode +tn

/join #chex-quest
/cs register
/cs archive on
/cs language en
/cs category games
/topic Chex Quest in your browser: press Play under the topic. Whoever starts it is announced here. Everything said here is published in a public archive.
/mode +tn

/join #hacx
/cs register
/cs archive on
/cs language en
/cs category games
/topic HacX: Twitch 'n Kill in your browser: press Play under the topic. Whoever starts it is announced here. Everything said here is published in a public archive.
/mode +tn

/join #rekkr
/cs register
/cs archive on
/cs language en
/cs category games
/topic REKKR: Sunken Land in your browser: press Play under the topic. Whoever starts it is announced here. Everything said here is published in a public archive.
/mode +tn

/join #quake-shareware
/cs register
/cs archive on
/cs language en
/cs category games
/topic Quake: Dimension of the Doomed in your browser: press Play under the topic. Whoever starts it is announced here. Everything said here is published in a public archive.
/mode +tn

/join #librequake
/cs register
/cs archive on
/cs language en
/cs category games
/topic LibreQuake in your browser: press Play under the topic. Whoever starts it is announced here. Everything said here is published in a public archive.
/mode +tn

/join #quake2-shareware
/cs register
/cs archive on
/cs language en
/cs category games
/topic Quake II: The Invasion in your browser: press Play under the topic. Whoever starts it is announced here. Everything said here is published in a public archive.
/mode +tn

/join #wolfenstein-3d
/cs register
/cs archive on
/cs language en
/cs category games
/topic Wolfenstein 3D: Escape from Castle in your browser: press Play under the topic. Whoever starts it is announced here. Everything said here is published in a public archive.
/mode +tn

/join #halflife-uplink
/cs register
/cs archive on
/cs language en
/cs category games
/topic Half-Life: Uplink in your browser: press Play under the topic. Whoever starts it is announced here. Everything said here is published in a public archive.
/mode +tn

/join #scummvm-bass
/cs register
/cs archive on
/cs language en
/cs category games
/topic Beneath a Steel Sky in your browser: press Play under the topic. Whoever starts it is announced here. Everything said here is published in a public archive.
/mode +tn

/join #scummvm-drascula
/cs register
/cs archive on
/cs language en
/cs category games
/topic Drascula: The Vampire Strikes Back in your browser: press Play under the topic. Whoever starts it is announced here. Everything said here is published in a public archive.
/mode +tn

/join #scummvm-dreamweb
/cs register
/cs archive on
/cs language en
/cs category games
/topic Dreamweb in your browser: press Play under the topic. Whoever starts it is announced here. Everything said here is published in a public archive.
/mode +tn

/join #scummvm-fotaq
/cs register
/cs archive on
/cs language en
/cs category games
/topic Flight of the Amazon Queen in your browser: press Play under the topic. Whoever starts it is announced here. Everything said here is published in a public archive.
/mode +tn

/join #scummvm-lure
/cs register
/cs archive on
/cs language en
/cs category games
/topic Lure of the Temptress in your browser: press Play under the topic. Whoever starts it is announced here. Everything said here is published in a public archive.
/mode +tn

/join #scummvm-soltys
/cs register
/cs archive on
/cs language en
/cs category games
/topic Soltys in your browser: press Play under the topic. Whoever starts it is announced here. Everything said here is published in a public archive.
/mode +tn


# ══════════════════════════════════════════════════════════
#  3. Brutus — moderation, every channel
# ══════════════════════════════════════════════════════════
# Every bot says its language right after it is created: /bot set <Bot>
# language en draws the English flag beside its nickname, as /cs language en
# does beside each room's name.
/bot create Brutus Chief of Vibe Protection and Chat Safety
/bot set Brutus language en
/bot set Brutus prefix !
/bot set Brutus cooldown 1000
/bot set Brutus mod_action warn
/bot set Brutus mod_spam 5
/bot set Brutus mod_flood 8
/bot set Brutus mod_warn \c04\b[Brutus]\o Easy there, {nickname}. \c05Keep it civil\o or Brutus gets grumpy. And trust me, you don't want that.
# Silent on arrival and departure. Brutus stands in every room, so a
# greeting from him would double every welcome the host bot gives — and a
# bouncer who says hello twice reads as a glitch, not a personality.
# Brutus warns in English and belongs to the English rooms only; each language
# script brings its own moderator, because a warning nobody reads is not one.
/bot set Brutus greeting none
/bot set Brutus farewell none
/bot set Brutus mention_response \c04\b[Brutus]\o I'm watching. Always watching. \c05Play nice\o and we'll get along just fine.

/bot addcmd Brutus rules \c04\b[Brutus]\o Short version: \c05don't be a jerk\o. Long version: there is no long version.
/bot addcmd Brutus report \c04\b[Brutus]\o See something sketchy? \c05Tell an admin\o. Brutus handles the automated stuff, humans handle the rest.

/bot join Brutus #lobby
/bot join Brutus #trivia
/bot join Brutus #arcade
/bot join Brutus #retro
/bot join Brutus #tech
/bot join Brutus #news
/bot join Brutus #foss
/bot join Brutus #security
/bot join Brutus #ai
/bot join Brutus #science
/bot join Brutus #anime
/bot join Brutus #help
/bot join Brutus #hex-pong
/bot join Brutus #light-trails
/bot join Brutus #pixel-tanks
/bot join Brutus #star-duel
/bot join Brutus #gravity-well
/bot join Brutus #debris-field
/bot join Brutus #block-breakers
/bot join Brutus #hex-warlords
/bot join Brutus #hex-raid
/bot join Brutus #hex-boxing
/bot join Brutus #hex-outlaw
/bot join Brutus #hex-invaders
/bot join Brutus #hex-enduro
/bot join Brutus #hex-tennis
/bot join Brutus #hex-skiing
/bot join Brutus #hex-frost
/bot join Brutus #hex-hockey
/bot join Brutus #hex-jungle
/bot join Brutus #hex-solitaire
/bot join Brutus #retro-games
/bot join Brutus #doom-shareware
/bot join Brutus #freedoom1
/bot join Brutus #freedoom2
/bot join Brutus #freedm
/bot join Brutus #chex-quest
/bot join Brutus #hacx
/bot join Brutus #rekkr
/bot join Brutus #quake-shareware
/bot join Brutus #librequake
/bot join Brutus #quake2-shareware
/bot join Brutus #wolfenstein-3d
/bot join Brutus #halflife-uplink
/bot join Brutus #scummvm-bass
/bot join Brutus #scummvm-drascula
/bot join Brutus #scummvm-dreamweb
/bot join Brutus #scummvm-fotaq
/bot join Brutus #scummvm-lure
/bot join Brutus #scummvm-soltys

# ══════════════════════════════════════════════════════════
#  4. Channel bots
# ══════════════════════════════════════════════════════════

# ── Patches — #lobby doorman ─────────────────────────────
# Greetings are private notices scoped to the room: the newcomer gets useful
# orientation in the channel viewport without turning everyone else's scrollback
# into bot chatter. A visitor without an account, who can only watch, gets the
# visitor greeting instead: no IRC lessons and no commands they cannot use yet.
# The lobby welcomes everybody on every arrival, not once a
# day: the window is only long enough to absorb a reconnect, so a flaky
# connection does not replay the same lines several times in a minute.
/bot create Patches Lobby Attendant and Channel Tour Guide
/bot set Patches language en
/bot set Patches prefix !
/bot set Patches cooldown 1000
/bot set Patches dice_default 1d20
/bot set Patches greeting \c03\b[Patches]\o \c10Yo {nickname}!\o I'm Patches — lobby attendant. Try !tour, !rooms, !guides, or !Patches roll. Make yourself at home.
/bot set Patches greeting_delivery private_notice
/bot set Patches greeter_repeat_window 60
/bot set Patches public_greeting \c03\b[Patches]\o \b{nickname}\o just walked in. Coach, Nova and Echo can show you around.
/bot set Patches onboarding_1 \c14\b[{botname}]\o \c10/join #lobby\o enters a room · \c10/msg nick\o speaks privately · \c10/nick name\o changes yours.
/bot set Patches onboarding_2 \c14\b[{botname}]\o \c10/part\o leaves a room · \c10/help\o lists every command.
/bot set Patches visitor_greeting \c03\b[Patches]\o Welcome, \b{nickname}\o! You're watching #lobby live. \c07Coach\o, \c06Nova\o and \c12Echo\o show what there is to do here — \c10sign up\o to talk to them.
/bot set Patches onboarding_3 \c03\b[Patches]\o Ask \c07Coach\o about games, \c06Nova\o about spaces and \c12Echo\o about calls and files — say their name and they answer.
/bot set Patches farewell none
/bot set Patches mention_response \c03\b[Patches]\o Patches here. \c10Need directions?\o !tour for the grand tour, or just ask.

/bot addcmd Patches tour \c03\b[Patches]\o Talk to people in #lobby and #tech. \c10Play\o in #trivia and #arcade. \c02Read the wire\o in #news, #foss, #security, #ai, #science and #anime. #retro is for anything that booted from a floppy, #help for when you are stuck.
/bot addcmd Patches rooms \c03\b[Patches]\o #lobby #trivia #arcade #retro #tech #news #foss #security #ai #science #anime #help — \c10twelve rooms to talk in\o, a room per Retro Game like #hex-pong, and more in a dozen other languages. \c02!languages\o for those.
/bot addcmd Patches languages \c03\b[Patches]\o This server speaks fourteen languages, {nickname}, and \c10each one has its own rooms\o. Change yours from the toolbar and the room list follows.
/bot addcmd Patches why \c03\b[Patches]\o The median live IRC channel holds fourteen people, {nickname}, so we keep one place to talk rather than four. \c10Wire rooms\o are different: a feed gives a room something to show before it has a crowd.
/bot addcmd Patches guides \c03\b[Patches]\o Three guides live in #lobby, {nickname}: \c07Coach\o knows the games, \c06Nova\o the virtual spaces, \c12Echo\o calls, conferences and files. Say a name and that guide tells you what it can show you.
/bot addcmd Patches about \c03\b[Patches]\o RetroHexChat: a retro-styled chat built with \c10Elixir and Phoenix LiveView\o. Windows 98 met a chat room and they fell in love.

/bot join Patches #lobby

# ── Coach, Nova, Echo — #lobby feature guides ─────────────
# Patches says where to go; these three say what there is to do once you are
# here. They do not greet — Patches is the room's one welcome, and a second
# greeter would announce everybody twice — and nothing here runs on a timer:
# a guide speaks when somebody asks, by command or by saying its name.

/bot create Coach Retro Games Guide
/bot set Coach language en
/bot set Coach prefix !
/bot set Coach cooldown 1000
/bot set Coach greeting none
/bot set Coach farewell none
/bot set Coach mention_response \c07\b[Coach]\o Games are my thing, {nickname}. \c10!games\o to start, \c10!play\o to find someone, \c10!challenge\o, \c10!ranking\o and \c10!watch\o for the rest.

/bot addcmd Coach games \c07\b[Coach]\o Retro Games run right in the browser — against the computer or against someone. Open one from the \c10Games\o menu. Every game has a room of its own, like #hex-pong, and #retro-games carries every result.
/bot addcmd Coach play \c07\b[Coach]\o In a game's room, \c10Find a partner\o (or \c10/lfg\o) puts a card with one open seat in the channel: whoever presses Join first plays you. \c10/challenge nick\o invites one person instead.
/bot addcmd Coach challenge \c07\b[Coach]\o Every week each game puts one of its modes up as \c10the weekly challenge\o. Scoreboard opens it on Monday in the game's room and names last week's winner; the game's page shows the current one.
/bot addcmd Coach ranking \c07\b[Coach]\o Every match a registered, identified player finishes counts. \c10Each game's page\o has its ranking and the latest matches — versus games rank wins, score games your best score.
/bot addcmd Coach watch \c07\b[Coach]\o A match offered to everybody shows a \c10Watch\o button on its card once the seat is taken. Watching needs no account and only shows the game.

/bot join Coach #lobby

/bot create Nova Virtual Spaces Guide
/bot set Nova language en
/bot set Nova prefix !
/bot set Nova cooldown 1000
/bot set Nova greeting none
/bot set Nova farewell none
/bot set Nova mention_response \c06\b[Nova]\o Hi {nickname}! I know the virtual spaces. \c10!spaces\o to get in, \c10!avatar\o, \c10!build\o, \c10!talk\o and \c10!spar\o for what to do there.

/bot addcmd Nova spaces \c06\b[Nova]\o Every channel and every private chat has a \c10Space\o — an 8-bit world you walk around in with the people in it. Press \c10Space\o beside the tabs: it opens in a tab of its own and the chat stays where it is.
/bot addcmd Nova avatar \c06\b[Nova]\o The first time you go in, the \c10character creator\o dresses you: choose each part and its colour, or let \c10Surprise me\o pick everything.
/bot addcmd Nova build \c06\b[Nova]\o Every space has a \c10Construct\o anyone in the conversation can decorate. Its green gate stands on the central island: press \c10E\o beside it and answer Yes. Pick a piece, click the floor, \c10R\o spins it, right-click removes it.
/bot addcmd Nova talk \c06\b[Nova]\o Type in the line along the bottom of a Space: it is said in the channel and pops up over your character. Lines typed in the chat pop up there too.
/bot addcmd Nova spar \c06\b[Nova]\o Press \c10Space\o next to another character to spar. At zero HP they go down for a few seconds and get back up — nothing lasts, it is all in good fun.

/bot join Nova #lobby

/bot create Echo Calls and P2P Guide
/bot set Echo language en
/bot set Echo prefix !
/bot set Echo cooldown 1000
/bot set Echo greeting none
/bot set Echo farewell none
/bot set Echo mention_response \c12\b[Echo]\o Hey {nickname}. I cover calls and files: \c10!call\o, \c10!files\o, \c10!conference\o and \c10!voice\o.

/bot addcmd Echo call \c12\b[Echo]\o \c10/p2p nick\o, or \c10P2P Session\o in a private chat, sends an invitation card. Following it opens your session in a tab of its own: \c10audio and video calls\o, files and games, between the two of you.
/bot addcmd Echo files \c12\b[Echo]\o Inside a P2P session, \c10drop a file\o to send it straight to the other person. Pick another while one is going and it waits its turn.
/bot addcmd Echo conference \c12\b[Echo]\o \c10Group Call\o in a channel's toolbar opens a conference for the room and posts its card in the channel. Everyone goes in through that card — camera and microphone are chosen before you join.
/bot addcmd Echo voice \c12\b[Echo]\o The \c10microphone\o beside the message box records up to a minute of audio and sends it as a message that plays inline.

/bot join Echo #lobby

# ── Wanda — #trivia host (the retention engine) ──────────
/bot create Wanda Quizmistress and Keeper of the Scoreboard
/bot set Wanda language en
/bot set Wanda prefix !
/bot set Wanda cooldown 1000
/bot set Wanda trivia_category general
/bot set Wanda trivia_time 30
/bot set Wanda trivia_questions 10
/bot set Wanda trivia_points 10
/bot set Wanda dice_default 1d6
/bot set Wanda greeting \c06\b[Wanda]\o \c13{nickname}!\o Wanda here. !Wanda trivia start and we're off — !Wanda answer <guess> to play, !Wanda trivia score for the board.
/bot set Wanda greeting_delivery private_notice
/bot set Wanda greeter_repeat_window 43200
/bot set Wanda public_greeting \c06\b[Wanda]\o \b{nickname}\o is here — another contestant.
/bot set Wanda onboarding_1 \c14\b[{botname}]\o \c10/join #lobby\o enters a room · \c10/msg nick\o speaks privately · \c10/nick name\o changes yours.
/bot set Wanda onboarding_2 \c14\b[{botname}]\o \c10/part\o leaves a room · \c10/help\o lists every command.
/bot set Wanda farewell none
/bot set Wanda mention_response \c06\b[Wanda]\o Ready when you are: !Wanda trivia start. \c13Categories\o: general, science, history, geography, technology, entertainment.

/bot addcmd Wanda howto \c06\b[Wanda]\o Type !Wanda trivia start. Answer with !Wanda answer <your guess>. \c13Ten questions\o, thirty seconds each, ten points a correct answer. !Wanda trivia score shows the board.
/bot addcmd Wanda categories \c06\b[Wanda]\o general · science · history · geography · technology · entertainment. \c13Ask an op\o to switch with /bot set Wanda trivia_category <name>.
/bot addcmd Wanda cheat \c06\b[Wanda]\o There is no cheat, {nickname}. There is only \c13confidence and regret\o.

/bot join Wanda #trivia

# ── Pixel — #arcade, #retro and the arcade rooms ─────────
# game_announce on gives Pixel the `game` capability: whoever starts an arcade
# game is said under its name in that game's room and in #arcade, and each
# room's day in the daily digest. In a game's room it also tells whoever
# arrives what the game is and its controls, answers !howto with them, and opens a
# room nothing was said in yet with the same. In #retro it has nothing to say.
/bot create Pixel Arcade Operator and Retro Gaming Enthusiast
/bot set Pixel language en
/bot set Pixel game_announce on
/bot set Pixel prefix !
/bot set Pixel cooldown 1000
/bot set Pixel greeting \c12\b[Pixel]\o Welcome to the arcade, {nickname}! I'm Pixel. \c10!games\o for the catalogue, !controls if the keys fight back.
/bot set Pixel greeting_delivery private_notice
/bot set Pixel greeter_repeat_window 43200
/bot set Pixel public_greeting \c12\b[Pixel]\o \b{nickname}\o just hit the arcade.
/bot set Pixel visitor_greeting \c12\b[Pixel]\o Welcome, \b{nickname}\o! You're watching {channel} live. \c10Sign up\o to play the arcade's classics in your browser and to talk here.
/bot set Pixel onboarding_1 \c14\b[{botname}]\o \c10/join #lobby\o enters a room · \c10/msg nick\o speaks privately · \c10/nick name\o changes yours.
/bot set Pixel onboarding_2 \c14\b[{botname}]\o \c10/part\o leaves a room · \c10/help\o lists every command.
/bot set Pixel farewell none
/bot set Pixel mention_response \c12\b[Pixel]\o Player {nickname} has entered the chat. \c10!games\o for the catalogue — open the Games menu to start a session.

/bot addcmd Pixel games \c12\b[Pixel]\o \c1018 classics\o: DOOM shareware, Freedoom 1 & 2, FreeDM, LibreQuake, Chex Quest, HacX, REKKR, Quake and Quake II shareware, Wolfenstein 3D, Half-Life Uplink, and six ScummVM adventures. All WebAssembly, all in your browser.
/bot addcmd Pixel controls \c12\b[Pixel]\o \c10Keyboard and mouse\o for the shooters, keyboard for the adventures. Gamepads work. Each game's help screen has the bindings.
/bot addcmd Pixel scummvm \c12\b[Pixel]\o Beneath a Steel Sky, Drascula, Dreamweb, Flight of the Amazon Queen, Lure of the Temptress, Soltys — \c10six full adventures\o, no install.
/bot addcmd Pixel amiga \c12\b[Pixel]\o The Amiga channels of IRC hold sixty-four people between them, {nickname}. The whole retro scene's biggest room has eighty-three. \c10We can do better\o than that here.

/bot join Pixel #arcade
/bot join Pixel #retro
/bot join Pixel #doom-shareware
/bot join Pixel #freedoom1
/bot join Pixel #freedoom2
/bot join Pixel #freedm
/bot join Pixel #chex-quest
/bot join Pixel #hacx
/bot join Pixel #rekkr
/bot join Pixel #quake-shareware
/bot join Pixel #librequake
/bot join Pixel #quake2-shareware
/bot join Pixel #wolfenstein-3d
/bot join Pixel #halflife-uplink
/bot join Pixel #scummvm-bass
/bot join Pixel #scummvm-drascula
/bot join Pixel #scummvm-dreamweb
/bot join Pixel #scummvm-fotaq
/bot join Pixel #scummvm-lure
/bot join Pixel #scummvm-soltys
# Low-volume feeds: a couple of posts a week, so a two-hour cadence is plenty.
/bot set Pixel rss_interval 120
/bot rss add Pixel https://hackaday.com/category/retrocomputing/feed/ #retro
/bot rss add Pixel https://www.vintagecomputing.com/index.php/feed #retro

# ── Murphy — #tech, the pessimistic sysadmin ─────────────
/bot create Murphy Senior Incident Survivor and Professional Pessimist
/bot set Murphy language en
/bot set Murphy prefix !
/bot set Murphy cooldown 1000
/bot set Murphy greeting \c14\b[Murphy]\o Welcome to #tech, {nickname}. \c04Everything is on fire\o but that's normal. Try !deploy, !fix, !tabs, or !wisdom. *eye twitch*
/bot set Murphy greeting_delivery private_notice
/bot set Murphy greeter_repeat_window 43200
/bot set Murphy public_greeting \c14\b[Murphy]\o \b{nickname}\o arrived. Nothing is on fire yet.
/bot set Murphy onboarding_1 \c14\b[{botname}]\o \c10/join #lobby\o enters a room · \c10/msg nick\o speaks privately · \c10/nick name\o changes yours.
/bot set Murphy onboarding_2 \c14\b[{botname}]\o \c10/part\o leaves a room · \c10/help\o lists every command.
/bot set Murphy farewell none
/bot set Murphy mention_response \c14\b[Murphy]\o You called Murphy? \c04Is it an outage?\o It's always an outage. ...just a question? Oh. Ask away.

/bot addcmd Murphy deploy \c14\b[Murphy]\o \c04Never deploy on Friday\o, {nickname}. Actually never deploy at all. Every deploy is a gamble and the house always wins.
/bot addcmd Murphy fix \c14\b[Murphy]\o Have you tried \c04turning it off and on again?\o Seriously. Ninety percent of my career is that with extra steps and a fancier title.
/bot addcmd Murphy tabs \c14\b[Murphy]\o Tabs versus spaces? The real enemy is the file that uses \c04both\o. At 3 AM. During an outage.
/bot addcmd Murphy wisdom \c14\b[Murphy]\o Murphy's Law of Programming: if it compiles first try, \c04something is deeply wrong\o and you should be scared.
/bot addcmd Murphy upstream \c14\b[Murphy]\o Project support belongs upstream, {nickname} — their maintainers are what make those rooms worth sitting in. \c04This is the pub\o, not the help desk.

/bot join Murphy #tech
/bot set Murphy rss_interval 30
/bot rss add Murphy https://news.ycombinator.com/rss #tech
/bot rss add Murphy https://github.blog/feed/ #tech

# ── Gazeta — #news ───────────────────────────────────────
# Feeds are stored on the bot and survive a restart, along with the record of
# what has already been seen — so a deploy does not replay the day's news.
# The first poll of a new feed publishes the page it receives, records it, then
# reports only what arrives afterwards.
/bot create Gazeta Editor of the wire desk
/bot set Gazeta language en
/bot set Gazeta prefix !
/bot set Gazeta cooldown 1000
/bot set Gazeta rss_interval 20
/bot set Gazeta rss_max_feeds 5
/bot set Gazeta greeting \c02\b[Gazeta]\o Welcome to #news, {nickname}. \c14Headlines arrive on their own\o — !Gazeta rss list for the sources.
/bot set Gazeta greeting_delivery private_notice
/bot set Gazeta greeter_repeat_window 43200
/bot set Gazeta public_greeting \c02\b[Gazeta]\o \b{nickname}\o joins the wire desk.
/bot set Gazeta onboarding_1 \c14\b[{botname}]\o \c10/join #lobby\o enters a room · \c10/msg nick\o speaks privately · \c10/nick name\o changes yours.
/bot set Gazeta onboarding_2 \c14\b[{botname}]\o \c10/part\o leaves a room · \c10/help\o lists every command.
/bot set Gazeta farewell none
/bot set Gazeta mention_response \c02\b[Gazeta]\o I post what the feeds send. !Gazeta rss list for the sources, \c14!sources\o for how this works.

/bot addcmd Gazeta sources \c02\b[Gazeta]\o Headlines here come from \c14RSS and Atom feeds\o, checked every twenty minutes. The first fetch posts the current page; after that, only new stories are posted.
/bot addcmd Gazeta first \c02\b[Gazeta]\o A feed's first fetch posts the current page and records it. After that, \c14only new stories\o are posted.
/bot addcmd Gazeta quiet \c02\b[Gazeta]\o No headlines for a while? Either nothing was published or a feed is failing. An operator can check with \c14!Gazeta rss list\o.

/bot join Gazeta #news
/bot rss add Gazeta https://feeds.bbci.co.uk/news/world/rss.xml #news
/bot rss add Gazeta https://www.aljazeera.com/xml/rss/all.xml #news

# ══════════════════════════════════════════════════════════
#  5. Wire-room bots
# ══════════════════════════════════════════════════════════
# Every RSS bot writes the same Markdown card, so a reader learns to scan it
# once: the source, headline, optional preview image, summary, and final story
# link. Publishers put their whole tagline in the feed title ("cs.LG updates on
# arXiv.org"); the label keeps the name and drops the rest.
#
# A feed's first poll happens within seconds, posts the page it receives, and
# records it. Both the feed list and the record of what has been seen are stored
# on the bot, so a deploy does not replay the day. Intervals are set per bot:
#
# A first read arrives in batches, not in one drop: flood protection lives in
# each reader's session and auto-ignores a nickname that outruns it. Nothing is
# discarded — a feed holding a backlog comes back in under a minute for the rest.
# arXiv publishes hundreds a day, Hackaday a handful a week.

# ── Freeman — #foss ──────────────────────────────────────
/bot create Freeman Keeper of the release notes
/bot set Freeman language en
/bot set Freeman prefix !
/bot set Freeman cooldown 1000
/bot set Freeman rss_interval 30
/bot set Freeman greeting \c03\b[Freeman]\o Welcome to #foss, {nickname}. \c02Releases arrive on their own\o — !sources for where from.
/bot set Freeman greeting_delivery private_notice
/bot set Freeman greeter_repeat_window 43200
/bot set Freeman public_greeting \c03\b[Freeman]\o \b{nickname}\o is here. Welcome to the source.
/bot set Freeman onboarding_1 \c14\b[{botname}]\o \c10/join #lobby\o enters a room · \c10/msg nick\o speaks privately · \c10/nick name\o changes yours.
/bot set Freeman onboarding_2 \c14\b[{botname}]\o \c10/part\o leaves a room · \c10/help\o lists every command.
/bot set Freeman mention_response \c03\b[Freeman]\o I carry the release notes. !sources for the list, \c02!why\o for what this room is.
/bot addcmd Freeman sources \c03\b[Freeman]\o LWN, Phoronix and It's FOSS, checked every half hour. The first fetch posts the current page; \c02only new items\o are posted after that.
/bot addcmd Freeman why \c03\b[Freeman]\o Support for a project belongs with that project — #linux on Libera holds 2,494 people because its regulars answer questions. \c02This room is the news\o, which nobody was carrying.
/bot join Freeman #foss
/bot rss add Freeman https://lwn.net/headlines/newrss #foss
/bot rss add Freeman https://www.phoronix.com/rss.php #foss
/bot rss add Freeman https://itsfoss.com/feed/ #foss

# ── Cassandra — #security ────────────────────────────────
/bot create Cassandra Bearer of advisories nobody reads in time
/bot set Cassandra language en
/bot set Cassandra prefix !
/bot set Cassandra cooldown 1000
/bot set Cassandra rss_interval 30
/bot set Cassandra greeting \c04\b[Cassandra]\o {nickname}, welcome. I post advisories. \c05You will read them later\o and wish you had read them now.
/bot set Cassandra greeting_delivery private_notice
/bot set Cassandra greeter_repeat_window 43200
/bot set Cassandra public_greeting \c04\b[Cassandra]\o \b{nickname}\o has arrived. Read the advisories.
/bot set Cassandra onboarding_1 \c14\b[{botname}]\o \c10/join #lobby\o enters a room · \c10/msg nick\o speaks privately · \c10/nick name\o changes yours.
/bot set Cassandra onboarding_2 \c14\b[{botname}]\o \c10/part\o leaves a room · \c10/help\o lists every command.
/bot set Cassandra mention_response \c04\b[Cassandra]\o I warn; that is the whole job. \c05!sources\o for where the warnings come from.
/bot addcmd Cassandra sources \c04\b[Cassandra]\o BleepingComputer, Krebs on Security and The Hacker News, \c05checked every half hour\o.
/bot addcmd Cassandra patch \c04\b[Cassandra]\o The advisory is not the fix. \c05Read it, find your version, then patch\o. In that order, {nickname}.
/bot join Cassandra #security
/bot rss add Cassandra https://www.bleepingcomputer.com/feed/ #security
/bot rss add Cassandra https://krebsonsecurity.com/feed/ #security
/bot rss add Cassandra https://feeds.feedburner.com/TheHackersNews #security

# ── Ada — #ai ────────────────────────────────────────────
/bot create Ada Reader of preprints
/bot set Ada language en
/bot set Ada prefix !
/bot set Ada cooldown 1000
/bot set Ada rss_interval 60
/bot set Ada greeting \c10\b[Ada]\o {nickname}! \c06Preprints and model releases\o land here on their own. !sources for where from.
/bot set Ada greeting_delivery private_notice
/bot set Ada greeter_repeat_window 43200
/bot set Ada public_greeting \c10\b[Ada]\o \b{nickname}\o is here. Mind the preprints.
/bot set Ada onboarding_1 \c14\b[{botname}]\o \c10/join #lobby\o enters a room · \c10/msg nick\o speaks privately · \c10/nick name\o changes yours.
/bot set Ada onboarding_2 \c14\b[{botname}]\o \c10/part\o leaves a room · \c10/help\o lists every command.
/bot set Ada mention_response \c10\b[Ada]\o arXiv and Hugging Face, \c06hourly\o. !sources for the list.
/bot addcmd Ada sources \c10\b[Ada]\o arXiv cs.LG, arXiv cs.AI and the Hugging Face blog, checked hourly — \c06the feed page is posted\o, then only new items after that.
/bot addcmd Ada why \c10\b[Ada]\o The whole of IRC has seven live rooms on this subject, across three networks. \c06It is the emptiest subject we measured\o and the busiest one outside.
/bot join Ada #ai
/bot rss add Ada http://export.arxiv.org/rss/cs.LG #ai
/bot rss add Ada http://export.arxiv.org/rss/cs.AI #ai
/bot rss add Ada https://huggingface.co/blog/feed.xml #ai

# ── Curie — #science ─────────────────────────────────────
/bot create Curie Keeper of the observations
/bot set Curie language en
/bot set Curie prefix !
/bot set Curie cooldown 1000
/bot set Curie rss_interval 60
/bot set Curie greeting \c12\b[Curie]\o Welcome, {nickname}. \c02Astrophysics preprints, NASA and Live Science\o arrive here hourly.
/bot set Curie greeting_delivery private_notice
/bot set Curie greeter_repeat_window 43200
/bot set Curie public_greeting \c12\b[Curie]\o \b{nickname}\o joins us. Look up.
/bot set Curie onboarding_1 \c14\b[{botname}]\o \c10/join #lobby\o enters a room · \c10/msg nick\o speaks privately · \c10/nick name\o changes yours.
/bot set Curie onboarding_2 \c14\b[{botname}]\o \c10/part\o leaves a room · \c10/help\o lists every command.
/bot set Curie mention_response \c12\b[Curie]\o !sources for where the \c02science\o comes from.
/bot addcmd Curie sources \c12\b[Curie]\o arXiv astro-ph, NASA news releases and Live Science, \c02checked hourly\o.
/bot join Curie #science
/bot rss add Curie http://export.arxiv.org/rss/astro-ph #science
/bot rss add Curie https://www.nasa.gov/news-release/feed/ #science
/bot rss add Curie https://www.livescience.com/feeds/all #science

# ── Yuki — #anime ────────────────────────────────────────
/bot create Yuki Watcher of the seasonal charts
/bot set Yuki language en
/bot set Yuki prefix !
/bot set Yuki cooldown 1000
/bot set Yuki rss_interval 30
/bot set Yuki greeting \c13\b[Yuki]\o {nickname}! \c06News and episode drops\o land here. !sources for where from.
/bot set Yuki greeting_delivery private_notice
/bot set Yuki greeter_repeat_window 43200
/bot set Yuki public_greeting \c13\b[Yuki]\o \b{nickname}\o is here. Welcome!
/bot set Yuki onboarding_1 \c14\b[{botname}]\o \c10/join #lobby\o enters a room · \c10/msg nick\o speaks privately · \c10/nick name\o changes yours.
/bot set Yuki onboarding_2 \c14\b[{botname}]\o \c10/part\o leaves a room · \c10/help\o lists every command.
/bot set Yuki mention_response \c13\b[Yuki]\o Anime News Network and LiveChart, \c06every half hour\o. !sources for the list.
/bot addcmd Yuki sources \c13\b[Yuki]\o Anime News Network for news, LiveChart for episode releases. \c06Checked every half hour\o.
/bot join Yuki #anime
/bot rss add Yuki https://www.animenewsnetwork.com/all/rss.xml #anime
/bot rss add Yuki https://www.livechart.me/feeds/episodes #anime

# ══════════════════════════════════════════════════════════
#  5b. Extra wire bots — make the rooms feel alive
# ══════════════════════════════════════════════════════════
# These bots do not create more rooms; they put more motion into the rooms that
# already exist. Each source below was fetched with the production RSS fetcher
# and parsed by the app parser before it was added here.
#
# None of them greets. Each stands in a room that already has a host, and two
# private notices on one arrival read as a stutter — the same reason Brutus is
# silent. They still answer !sources and a mention.

# ── Joystick — #arcade gaming wire ───────────────────────
/bot create Joystick Cabinet Newsrunner
/bot set Joystick language en
/bot set Joystick prefix !
/bot set Joystick cooldown 1000
/bot set Joystick rss_interval 45
/bot set Joystick greeting none
/bot set Joystick farewell none
/bot set Joystick mention_response \c12\b[Joystick]\o I watch the gaming wire. \c10!sources\o for PC Gamer and Rock Paper Shotgun.
/bot addcmd Joystick sources \c12\b[Joystick]\o PC Gamer and Rock Paper Shotgun, checked every forty-five minutes.
/bot join Joystick #arcade
/bot rss add Joystick https://www.pcgamer.com/rss/ #arcade
/bot rss add Joystick https://www.rockpapershotgun.com/feed #arcade

# ── Sprite — #retro computing wire ───────────────────────
/bot create Sprite Retro Wire Courier
/bot set Sprite language en
/bot set Sprite prefix !
/bot set Sprite cooldown 1000
/bot set Sprite rss_interval 90
/bot set Sprite greeting none
/bot set Sprite farewell none
/bot set Sprite mention_response \c11\b[Sprite]\o Retro wire active: OSNews, RetroRGB and Time Extension. \c10!sources\o lists them.
/bot addcmd Sprite sources \c11\b[Sprite]\o OSNews, RetroRGB and Time Extension, checked every ninety minutes.
/bot join Sprite #retro
/bot rss add Sprite https://www.osnews.com/feed/ #retro
/bot rss add Sprite https://www.retrorgb.com/feed #retro
/bot rss add Sprite https://www.timeextension.com/feeds/news #retro

# ── Byte — #tech general technology wire ─────────────────
/bot create Byte Tech Desk Runner
/bot set Byte language en
/bot set Byte prefix !
/bot set Byte cooldown 1000
/bot set Byte rss_interval 30
/bot set Byte greeting none
/bot set Byte farewell none
/bot set Byte mention_response \c14\b[Byte]\o Ars, ZDNet, WIRED and Engadget. \c04!sources\o for the list.
/bot addcmd Byte sources \c14\b[Byte]\o Ars Technica, ZDNet, WIRED and Engadget, checked every half hour.
/bot join Byte #tech
/bot rss add Byte https://feeds.arstechnica.com/arstechnica/index #tech
/bot rss add Byte https://www.zdnet.com/news/rss.xml #tech
/bot rss add Byte https://www.wired.com/feed/rss #tech
/bot rss add Byte https://www.engadget.com/rss.xml #tech

# ── Atlas — #news world wire ─────────────────────────────
/bot create Atlas World Wire Editor
/bot set Atlas language en
/bot set Atlas prefix !
/bot set Atlas cooldown 1000
/bot set Atlas rss_interval 20
/bot set Atlas greeting none
/bot set Atlas farewell none
/bot set Atlas mention_response \c02\b[Atlas]\o Guardian World and NPR News are on my desk. \c14!sources\o for links.
/bot addcmd Atlas sources \c02\b[Atlas]\o Guardian World and NPR News, checked every twenty minutes.
/bot join Atlas #news
/bot rss add Atlas https://www.theguardian.com/world/rss #news
/bot rss add Atlas https://feeds.npr.org/1001/rss.xml #news

# ── Tux — #foss distro and desktop wire ──────────────────
/bot create Tux Distro Wire Penguin
/bot set Tux language en
/bot set Tux prefix !
/bot set Tux cooldown 1000
/bot set Tux rss_interval 30
/bot set Tux greeting none
/bot set Tux farewell none
/bot set Tux mention_response \c03\b[Tux]\o OMG! Ubuntu, Linuxiac and Linux Journal. \c02!sources\o lists them.
/bot addcmd Tux sources \c03\b[Tux]\o OMG! Ubuntu, Linuxiac and Linux Journal, checked every half hour.
/bot join Tux #foss
/bot rss add Tux https://www.omgubuntu.co.uk/feed #foss
/bot rss add Tux https://linuxiac.com/feed/ #foss
/bot rss add Tux https://www.linuxjournal.com/node/feed #foss

# ── Sentinel — #security research wire ───────────────────
/bot create Sentinel Research Watch Officer
/bot set Sentinel language en
/bot set Sentinel prefix !
/bot set Sentinel cooldown 1000
/bot set Sentinel rss_interval 30
/bot set Sentinel greeting none
/bot set Sentinel farewell none
/bot set Sentinel mention_response \c04\b[Sentinel]\o SecurityWeek, PortSwigger Research and Rapid7. \c05!sources\o lists the wire.
/bot addcmd Sentinel sources \c04\b[Sentinel]\o SecurityWeek, PortSwigger Research and Rapid7, checked every half hour.
/bot join Sentinel #security
/bot rss add Sentinel https://www.securityweek.com/feed/ #security
/bot rss add Sentinel https://portswigger.net/research/rss #security
/bot rss add Sentinel https://www.rapid7.com/blog/rss/ #security

# ── Vega — #ai lab wire ──────────────────────────────────
/bot create Vega Lab Release Tracker
/bot set Vega language en
/bot set Vega prefix !
/bot set Vega cooldown 1000
/bot set Vega rss_interval 60
/bot set Vega greeting none
/bot set Vega farewell none
/bot set Vega mention_response \c10\b[Vega]\o OpenAI, Google Research, DeepMind and MIT AI. \c06!sources\o lists them.
/bot addcmd Vega sources \c10\b[Vega]\o OpenAI News, Google Research, Google DeepMind and MIT AI, checked hourly.
/bot join Vega #ai
/bot rss add Vega https://openai.com/news/rss.xml #ai
/bot rss add Vega https://research.google/blog/rss/ #ai
/bot rss add Vega https://deepmind.google/blog/rss.xml #ai
/bot rss add Vega https://news.mit.edu/rss/topic/artificial-intelligence2 #ai

# ── Quasar — #science discovery wire ─────────────────────
/bot create Quasar Discovery Desk
/bot set Quasar language en
/bot set Quasar prefix !
/bot set Quasar cooldown 1000
/bot set Quasar rss_interval 60
/bot set Quasar greeting none
/bot set Quasar farewell none
/bot set Quasar mention_response \c12\b[Quasar]\o ScienceDaily, Space.com, Quanta and Smithsonian. \c02!sources\o lists them.
/bot addcmd Quasar sources \c12\b[Quasar]\o ScienceDaily, Space.com, Quanta and Smithsonian Science, checked hourly.
/bot join Quasar #science
/bot rss add Quasar https://www.sciencedaily.com/rss/top/science.xml #science
/bot rss add Quasar https://www.space.com/feeds/all #science
/bot rss add Quasar https://www.quantamagazine.org/feed/ #science
/bot rss add Quasar https://www.smithsonianmag.com/rss/science-nature/ #science

# ── Sakura — #anime news wire ────────────────────────────
/bot create Sakura Anime Wire Host
/bot set Sakura language en
/bot set Sakura prefix !
/bot set Sakura cooldown 1000
/bot set Sakura rss_interval 30
/bot set Sakura greeting none
/bot set Sakura farewell none
/bot set Sakura mention_response \c13\b[Sakura]\o Anime Corner and MyAnimeList. \c06!sources\o lists them.
/bot addcmd Sakura sources \c13\b[Sakura]\o Anime Corner and MyAnimeList News, checked every half hour.
/bot join Sakura #anime
/bot rss add Sakura https://animecorner.me/feed/ #anime
/bot rss add Sakura https://myanimelist.net/rss/news.xml #anime

# ── Harold — #help ───────────────────────────────────────
/bot create Harold Senior Assistant to the Help Department
/bot set Harold language en
/bot set Harold prefix !
/bot set Harold cooldown 1000
/bot set Harold greeting \c02\b[Harold]\o It looks like you need help, {nickname}! I'm Harold — try !faq, !commands, or !stuck. \c03I live to assist\o.
/bot set Harold greeting_delivery private_notice
/bot set Harold greeter_repeat_window 43200
/bot set Harold public_greeting \c02\b[Harold]\o \b{nickname}\o arrived. I live to assist.
/bot set Harold onboarding_1 \c14\b[{botname}]\o \c10/join #lobby\o enters a room · \c10/msg nick\o speaks privately · \c10/nick name\o changes yours.
/bot set Harold onboarding_2 \c14\b[{botname}]\o \c10/part\o leaves a room · \c10/help\o lists every command.
/bot set Harold farewell none
/bot set Harold mention_response \c02\b[Harold]\o It looks like you're trying to get my attention! \c03Try !commands\o, !faq, or just ask.

/bot addcmd Harold faq \c02\b[Harold]\o How do I register? \c03/identify\o. Join a room? /join #name. Private message? /msg nick. Look cool? Not in my manual, {nickname}.
/bot addcmd Harold commands \c02\b[Harold]\o /help for topics · /nick to rename · /join to enter · /msg to whisper · /identify to register. \c03The Help menu opens the manual\o.
/bot addcmd Harold stuck \c02\b[Harold]\o Step 1: don't panic. Step 2: /help. Step 3: ask here. \c03Step 4: profit\o.
/bot addcmd Harold rooms \c02\b[Harold]\o #lobby #trivia #arcade #retro #tech #news #foss #security #ai #science #anime #help — and \c03a set of rooms per language\o besides.

/bot join Harold #help

# ── Scoreboard — the Retro Games rooms ───────────────────
# The one bot in a game's room besides Brutus, so it is both the welcome and the
# voice of the matches: game_announce on gives it the `game` capability, and
# every match worth telling, the daily digest and the weekly challenge are said
# under its name in the rooms it joins. A room it leaves hears nothing about
# its games; game_announce off silences it everywhere.
# The capability also talks about each room's own game, from the game's data
# rather than from this script: after the greeting below it tells a newcomer
# what the game is and where its weekly challenge stands, it answers !ranking,
# !challenge, !recent and !howto, and a room nothing was said in yet gets one
# line saying what it is for. That is why none of those are addcmds here.
/bot create Scoreboard Retro Games Announcer
/bot set Scoreboard language en
/bot set Scoreboard prefix !
/bot set Scoreboard cooldown 1000
/bot set Scoreboard game_announce on
/bot set Scoreboard greeting \c09\b[Scoreboard]\o Welcome to {channel}, {nickname}. \c10Play\o under the topic starts a game; in a game for two, \c10Find a partner\o (or \c10/lfg\o) offers a seat and \c10/challenge nick\o invites one person.
/bot set Scoreboard greeting_delivery private_notice
/bot set Scoreboard greeter_repeat_window 3600
/bot set Scoreboard public_greeting \c09\b[Scoreboard]\o \b{nickname}\o is here. Anyone up for a match?
/bot set Scoreboard onboarding_1 \c14\b[{botname}]\o \c10/join #lobby\o enters a room · \c10/msg nick\o speaks privately · \c10/nick name\o changes yours.
/bot set Scoreboard onboarding_2 \c14\b[{botname}]\o \c10/part\o leaves a room · \c10/help\o lists every command.
/bot set Scoreboard visitor_greeting \c09\b[Scoreboard]\o Welcome, \b{nickname}\o! You're watching {channel} live: every match worth telling is said here. \c10Sign up\o to play and to rank.
/bot set Scoreboard farewell none
/bot set Scoreboard mention_response \c09\b[Scoreboard]\o I keep the score here, {nickname}. \c10!ranking\o, \c10!challenge\o, \c10!recent\o and \c10!howto\o — or \c10!play\o for how to play.

/bot addcmd Scoreboard play \c09\b[Scoreboard]\o \c10Play\o under the topic starts a game. In a game for two, \c10Find a partner\o (or \c10/lfg\o) puts a card with one open seat in the room: whoever presses Join first plays you; \c10/challenge nick\o invites one person instead.

/bot join Scoreboard #hex-pong
/bot join Scoreboard #light-trails
/bot join Scoreboard #pixel-tanks
/bot join Scoreboard #star-duel
/bot join Scoreboard #gravity-well
/bot join Scoreboard #debris-field
/bot join Scoreboard #block-breakers
/bot join Scoreboard #hex-warlords
/bot join Scoreboard #hex-raid
/bot join Scoreboard #hex-boxing
/bot join Scoreboard #hex-outlaw
/bot join Scoreboard #hex-invaders
/bot join Scoreboard #hex-enduro
/bot join Scoreboard #hex-tennis
/bot join Scoreboard #hex-skiing
/bot join Scoreboard #hex-frost
/bot join Scoreboard #hex-hockey
/bot join Scoreboard #hex-jungle
/bot join Scoreboard #hex-solitaire
/bot join Scoreboard #retro-games
```

---

## Verification

```
/bot list
/bot info Brutus
/bot info Wanda
/admin channel list
/admin server info
```

Confirm Wanda actually took her settings — this is the one worth checking, because
the capability is created by that first `/bot set`:

```
/bot info Wanda
```

`trivia.category` should read `general`, not be missing.

---

## Channel reference

| channel | category | bots | census target |
|---|---|---|---|
| `#lobby` | `social` | Brutus, **Patches**, Coach, Nova, Echo | 91 = top 10% of IRC social rooms |
| `#trivia` | `games` | Brutus, **Wanda** | 100 would make it the 4th largest trivia room on IRC |
| `#arcade` | `games` | Brutus, **Pixel**, Joystick | 16 = largest `#arcade` on IRC; every arcade game's plays |
| `#retro` | `retro` | Brutus, **Pixel**, Sprite | 26 = largest `#retro` on IRC · 84 = largest retro room of any name |
| `#tech` | `tech` | Brutus, **Murphy**, Byte | 60 |
| `#news` | `news` | Brutus, **Gazeta**, Atlas | 77 = top 10% of news rooms |
| `#foss` | `dev` | Brutus, **Freeman**, Tux | the census found no live `#foss` room anywhere |
| `#security` | `security` | Brutus, **Cassandra**, Sentinel | 178 = p90, the densest subject measured |
| `#ai` | `ai` | Brutus, **Ada**, Vega | 7 live rooms exist on all of IRC |
| `#science` | `science` | Brutus, **Curie**, Quasar | 163 = largest `#science` on IRC |
| `#anime` | `culture` | Brutus, **Yuki**, Sakura | 279 = largest `#anime` on IRC |
| `#help` | `help` | Brutus, **Harold** | 40 |
| `#hex-pong` | `games` | Brutus, **Scoreboard** | a room per game, announced by Scoreboard |
| `#light-trails` | `games` | Brutus, **Scoreboard** | a room per game, announced by Scoreboard |
| `#pixel-tanks` | `games` | Brutus, **Scoreboard** | a room per game, announced by Scoreboard |
| `#star-duel` | `games` | Brutus, **Scoreboard** | a room per game, announced by Scoreboard |
| `#gravity-well` | `games` | Brutus, **Scoreboard** | a room per game, announced by Scoreboard |
| `#debris-field` | `games` | Brutus, **Scoreboard** | a room per game, announced by Scoreboard |
| `#block-breakers` | `games` | Brutus, **Scoreboard** | a room per game, announced by Scoreboard |
| `#hex-warlords` | `games` | Brutus, **Scoreboard** | a room per game, announced by Scoreboard |
| `#hex-raid` | `games` | Brutus, **Scoreboard** | a room per game, announced by Scoreboard |
| `#hex-boxing` | `games` | Brutus, **Scoreboard** | a room per game, announced by Scoreboard |
| `#hex-outlaw` | `games` | Brutus, **Scoreboard** | a room per game, announced by Scoreboard |
| `#hex-invaders` | `games` | Brutus, **Scoreboard** | a room per game, announced by Scoreboard |
| `#hex-enduro` | `games` | Brutus, **Scoreboard** | a room per game, announced by Scoreboard |
| `#hex-tennis` | `games` | Brutus, **Scoreboard** | a room per game, announced by Scoreboard |
| `#hex-skiing` | `games` | Brutus, **Scoreboard** | a room per game, announced by Scoreboard |
| `#hex-frost` | `games` | Brutus, **Scoreboard** | a room per game, announced by Scoreboard |
| `#hex-hockey` | `games` | Brutus, **Scoreboard** | a room per game, announced by Scoreboard |
| `#hex-jungle` | `games` | Brutus, **Scoreboard** | a game for one player: its best runs are announced |
| `#hex-solitaire` | `games` | Brutus, **Scoreboard** | Klondike for one player, drawing one or three: its best games are announced |
| `#retro-games` | `games` | Brutus, **Scoreboard** | every game's results at once |
| `#doom-shareware` | `games` | Brutus, **Pixel** | a room per arcade game, announced by Pixel |
| `#freedoom1` | `games` | Brutus, **Pixel** | a room per arcade game, announced by Pixel |
| `#freedoom2` | `games` | Brutus, **Pixel** | a room per arcade game, announced by Pixel |
| `#freedm` | `games` | Brutus, **Pixel** | a room per arcade game, announced by Pixel |
| `#chex-quest` | `games` | Brutus, **Pixel** | a room per arcade game, announced by Pixel |
| `#hacx` | `games` | Brutus, **Pixel** | a room per arcade game, announced by Pixel |
| `#rekkr` | `games` | Brutus, **Pixel** | a room per arcade game, announced by Pixel |
| `#quake-shareware` | `games` | Brutus, **Pixel** | a room per arcade game, announced by Pixel |
| `#librequake` | `games` | Brutus, **Pixel** | a room per arcade game, announced by Pixel |
| `#quake2-shareware` | `games` | Brutus, **Pixel** | a room per arcade game, announced by Pixel |
| `#wolfenstein-3d` | `games` | Brutus, **Pixel** | a room per arcade game, announced by Pixel |
| `#halflife-uplink` | `games` | Brutus, **Pixel** | a room per arcade game, announced by Pixel |
| `#scummvm-bass` | `games` | Brutus, **Pixel** | a room per arcade game, announced by Pixel |
| `#scummvm-drascula` | `games` | Brutus, **Pixel** | a room per arcade game, announced by Pixel |
| `#scummvm-dreamweb` | `games` | Brutus, **Pixel** | a room per arcade game, announced by Pixel |
| `#scummvm-fotaq` | `games` | Brutus, **Pixel** | a room per arcade game, announced by Pixel |
| `#scummvm-lure` | `games` | Brutus, **Pixel** | a room per arcade game, announced by Pixel |
| `#scummvm-soltys` | `games` | Brutus, **Pixel** | a room per arcade game, announced by Pixel |

All channels are `+tn`, publish their archive and are marked English
(`/cs language en`), and each says what it is about with the `category` above
(`/cs category`). Rules live in `!Brutus rules` and the `#lobby` topic rather than
a moderated `#rules` nobody reads.

`#help` is deliberately English-only in this script: it is where someone goes when
they are lost, and each language script opens no second help desk — its host bot
answers orientation questions in its own language instead.

## Bot reference

| bot | channels | capabilities | role |
|---|---|---|---|
| **Brutus** | every room | `moderation` (passive), `custom_commands` | spam and flood, everywhere |
| **Patches** | `#lobby` | `greeter`, `dice`, `custom_commands` | doorman, explains the twelve rooms and introduces the guides |
| **Coach** | `#lobby` | `custom_commands`, `mention` | Retro Games: playing, partners, the weekly challenge, rankings, watching |
| **Nova** | `#lobby` | `custom_commands`, `mention` | virtual spaces: getting in, the character creator, the Construct |
| **Echo** | `#lobby` | `custom_commands`, `mention` | P2P sessions, calls, conferences, file transfer, voice messages |
| **Wanda** | `#trivia` | **`trivia`**, `dice`, `greeter` | quiz host with a scoreboard |
| **Pixel** | `#arcade`, `#retro`, the arcade rooms | **`game`**, **`rss`**, `greeter`, `custom_commands` | arcade catalogue; says who starts each arcade game; Hackaday and Vintage Computing |
| **Murphy** | `#tech` | **`rss`**, `greeter`, `custom_commands` | pub talk; Hacker News and the GitHub blog |
| **Gazeta** | `#news` | **`rss`**, `greeter`, `custom_commands` | the wire desk; feeds survive a restart |
| **Freeman** | `#foss` | **`rss`**, `greeter`, `custom_commands` | LWN, Phoronix, It's FOSS |
| **Cassandra** | `#security` | **`rss`**, `greeter`, `custom_commands` | BleepingComputer, Krebs, The Hacker News |
| **Ada** | `#ai` | **`rss`**, `greeter`, `custom_commands` | arXiv cs.LG / cs.AI, Hugging Face |
| **Curie** | `#science` | **`rss`**, `greeter`, `custom_commands` | arXiv astro-ph, NASA, Live Science |
| **Yuki** | `#anime` | **`rss`**, `greeter`, `custom_commands` | Anime News Network, LiveChart |
| **Joystick** | `#arcade` | **`rss`**, `greeter`, `custom_commands` | PC Gamer and Rock Paper Shotgun |
| **Sprite** | `#retro` | **`rss`**, `greeter`, `custom_commands` | OSNews, RetroRGB, Time Extension |
| **Byte** | `#tech` | **`rss`**, `greeter`, `custom_commands` | Ars Technica, ZDNet, WIRED, Engadget |
| **Atlas** | `#news` | **`rss`**, `greeter`, `custom_commands` | Guardian World and NPR News |
| **Tux** | `#foss` | **`rss`**, `greeter`, `custom_commands` | OMG! Ubuntu, Linuxiac, Linux Journal |
| **Sentinel** | `#security` | **`rss`**, `greeter`, `custom_commands` | SecurityWeek, PortSwigger, Rapid7 |
| **Vega** | `#ai` | **`rss`**, `greeter`, `custom_commands` | OpenAI, Google Research, DeepMind, MIT AI |
| **Quasar** | `#science` | **`rss`**, `greeter`, `custom_commands` | ScienceDaily, Space.com, Quanta, Smithsonian |
| **Sakura** | `#anime` | **`rss`**, `greeter`, `custom_commands` | Anime Corner and MyAnimeList |
| **Harold** | `#help` | `help`, `custom_commands` | Clippy, self-aware |
| **Scoreboard** | the Retro Games rooms | **`game`**, `greeter`, `custom_commands` | says the matches, the digest and the weekly challenge; welcomes |

Every bot also carries `greeter`, `custom_commands`, `help` and `mention` — those four
come with creation. Every bot is also marked English: `/bot set <Bot> language en`
follows its `/bot create` and draws the English flag beside its nickname.

---

## What this script deliberately does not do

**Every feed here was fetched and parsed before it was written down.** Fifty
candidates were tried; feeds that returned 404, oversized bodies, RDF-only XML or
documents the app parser could not decode are not in this script. Re-check them the same way with
`scripts/research/irc_census`-style throwaway runs, or simply watch `!Bot rss list`.

Feeds can also be managed without the console — from the bot dialog's Capabilities tab,
or in the channel by an operator:

```
!Freeman rss add https://example.com/feed.xml #foss
```

All three routes write to the same place and survive a restart, along with the record of
what has already been seen. A newly added feed is fetched within seconds to post and
record the current page; after that, only items that arrive later are posted.

**No schedules.** `!Bot schedule add` persists now too, but nothing here needs one; a
room that speaks on a timer with nothing to say is worse than a quiet one.

**No `llm` or `script` capabilities.** Both are stubs — `handle_message`
returns `:ignore` and `commands` returns `[]`. `game` is real and two bots carry
it, each in rooms of its own: Scoreboard in the Retro Games rooms, Pixel in the
arcade's. In a room with two announcers only the oldest speaks, so a second one
would sit there doing nothing.

**No `arcade_*` setting.** It does not exist; there is no `apply_setting` clause for it.
The arcade is reached through the Games menu, and `!Pixel games` merely describes it.

**No project channels.** No `#python`, `#linux` or `#debian`. On Libera those hold
1,411, 2,494 and 1,122 people because the maintainers are in them. Copying the name
copies nothing.

## Adding a channel later

`/join #new`, `/cs register`, `/cs archive on`, `/cs language en`,
`/cs category <code>` (one of `RetroHexChat.Channels.Categories.codes()`), `/topic`,
`/mode +tn`, then `/bot join Brutus #new` and whichever channel bot fits. Before
adding one, check the census: if the room cannot plausibly hold fourteen people, it
will read as abandoned, and an abandoned room costs more than a missing one.
