# RetroHexChat — Production Provisioning

Thirteen channels, thirteen bots. Every choice below traces to `scripts/research/irc_census`
— a live `/LIST` sweep of 95 public IRC networks, of which 59 answered with 49,973
channels. Regenerate it with `scripts/research/irc_census/run.sh`.

## Why these thirteen

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
| regional (lusophone) | 13 `#brasil` rooms | 12 | 273 | **57** | distributed demand, no owner |

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
#  13 channels · 13 bots · derived from the IRC census
# ══════════════════════════════════════════════════════════

# ── 1. Server ────────────────────────────────────────────
/admin server set server_name RetroHexChat
/admin server set server_description The retro chat experience you never knew you missed. Windows 98 called — it wants you back.
/admin server set welcome_message Welcome to RetroHexChat. Thirteen rooms, none of them empty. Type /help to get started.
/admin server set registration open

# ── 2. Channels ──────────────────────────────────────────

# #lobby — the single social room. Not four: the median live room on IRC
# holds 14 people, so a split crowd is an empty crowd.
# Joined explicitly rather than assumed: the console starts on whatever channel
# the admin happens to be in, and /cs register acts on the active one.
/join #lobby
/cs register
/topic The lobby — one room, everyone in it. Pull up a chair, the pixels are warm.
/mode +tn

# #trivia — the retention engine. Native trivia capability with scoring;
# the rest of IRC still runs this on eggdrop from 1997.
/join #trivia
/cs register
/topic Trivia — !Wanda trivia start to begin, !Wanda answer <guess> to play, !Wanda trivia score for the board. Six categories.
/mode +tn

# #arcade — DOOM, Quake, Wolfenstein and ScummVM in the browser.
# The largest #arcade on IRC has 15 people. No network offers this.
/join #arcade
/cs register
/topic Arcade — 18 classics running in your browser. Open the Games menu, or ask !Pixel games for the catalogue.
/mode +tn

# #retro — the lowest bar on IRC: the biggest #retro anywhere holds 25 people,
# the biggest retro room of any name holds 83. Amiga, C64, DOS, demoscene, BBS.
/join #retro
/cs register
/topic Retro computing — Amiga, C64, Atari, DOS, demoscene, BBS. If it booted from a floppy, it belongs here.
/mode +tn

# #tech — conversation, not project support. We do not run #python or #linux;
# those rooms are worth what their maintainers make them.
/join #tech
/cs register
/topic Tech talk — hardware, self-hosting, sysadmin war stories. Project support lives upstream; this is the pub.
/mode +tn

# #brasil — 13 live #brasil rooms across 12 networks, 273 people between them,
# largest holds 57. Distributed demand, no owner.
/join #brasil
/cs register
/topic Canal brasileiro — bate-papo em português. Chega aí, senta e fica à vontade.
/mode +tn

# #news — politics/news is fragmented across 28 networks with no owner: the
# largest room holds 450 and the p90 is 77. Driven by feeds, not opinion.
/join #news
/cs register
/topic News — headlines pulled from feeds by Gazeta. !Gazeta rss list to see the sources.
/mode +tn

# #help — the most universal channel on IRC: alive on 30 of the 59 networks
# that answered the census.
/join #help
/cs register
/topic Lost? Ask here. !Harold faq for the basics, or /help and F1 for the manual.
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
/topic Free software news — releases, kernels, distros. Fed by LWN, Phoronix and It's FOSS.
/mode +tn

# #security — the densest subject measured: only 57 live rooms, but a p90 of
# 178, the highest of any category. People who arrive stay. Advisories are the
# archetypal feed content.
/join #security
/cs register
/topic Security advisories — CISA, Krebs, The Hacker News. Read before you patch.
/mode +tn

# #ai — seven live rooms across three networks in the whole census, the
# emptiest subject measured and the busiest one outside IRC. Nobody has claimed it.
/join #ai
/cs register
/topic Machine learning — arXiv preprints and model releases as they land.
/mode +tn

# #science — 76 live rooms spread over 13 networks, the biggest holding 163.
# Distributed demand, no owner.
/join #science
/cs register
/topic Science — arXiv astrophysics, NASA and Phys.org. Bring questions.
/mode +tn

# #anime — alive on 12 networks with 802 people between them, and the largest
# room holds only 279. A familiar name with a weak incumbent.
/join #anime
/cs register
/topic Anime — news and episode releases via Anime News Network and LiveChart.
/mode +tn

# ══════════════════════════════════════════════════════════
#  3. Brutus — moderation, every channel
# ══════════════════════════════════════════════════════════
/bot create Brutus Chief of Vibe Protection and Chat Safety
/bot set Brutus prefix !
/bot set Brutus cooldown 1000
/bot set Brutus mod_action warn
/bot set Brutus mod_spam 5
/bot set Brutus mod_flood 8
/bot set Brutus mod_warn Easy there. Keep it civil or Brutus gets grumpy. And trust me, you don't want that.
# Silent on arrival and departure. Brutus stands in all seven rooms, so a
# greeting from him would double every welcome the host bot gives — and a
# bouncer who says hello twice reads as a glitch, not a personality.
/bot set Brutus greeting none
/bot set Brutus farewell none
/bot set Brutus mention_response I'm watching. Always watching. Play nice and we'll get along just fine.

/bot addcmd Brutus rules Short version: don't be a jerk. Long version: there is no long version.
/bot addcmd Brutus report See something sketchy? Tell an admin. Brutus handles the automated stuff, humans handle the rest.

/bot join Brutus #lobby
/bot join Brutus #trivia
/bot join Brutus #arcade
/bot join Brutus #retro
/bot join Brutus #tech
/bot join Brutus #brasil
/bot join Brutus #news
/bot join Brutus #foss
/bot join Brutus #security
/bot join Brutus #ai
/bot join Brutus #science
/bot join Brutus #anime
/bot join Brutus #help

# ══════════════════════════════════════════════════════════
#  4. Channel bots
# ══════════════════════════════════════════════════════════

# ── Patches — #lobby doorman ─────────────────────────────
# Cooldowns are per channel, not per user: while one is running the bot
# ignores everyone. A second of quiet is enough to stop a flood; three made
# the room look broken to the next person who typed.
/bot create Patches Lobby Attendant and Channel Tour Guide
/bot set Patches prefix !
/bot set Patches cooldown 1000
/bot set Patches dice_default 1d20
/bot set Patches greeting Yo {nickname}! I'm Patches — lobby attendant. Try !tour, !rooms, or !Patches roll. Make yourself at home.
/bot set Patches farewell {nickname} heading out? The lobby keeps your seat warm. We're always open.
/bot set Patches mention_response Patches here. Need directions? !tour for the grand tour, or just ask.

/bot addcmd Patches tour Talk to people in #lobby, #brasil and #tech. Play in #trivia and #arcade. Read the wire in #news, #foss, #security, #ai, #science and #anime. #retro is for anything that booted from a floppy, #help for when you are stuck.
/bot addcmd Patches rooms #lobby #trivia #arcade #retro #tech #brasil #news #foss #security #ai #science #anime #help — thirteen, and every one of them has something in it.
/bot addcmd Patches why The median live IRC channel holds fourteen people, {nickname}, so we keep one place to talk rather than four. The wire rooms are different: a feed gives a room something to show before it has a crowd.
/bot addcmd Patches about RetroHexChat: a retro-styled chat built with Elixir and Phoenix LiveView. Windows 98 met a chat room and they fell in love.

/bot join Patches #lobby

# ── Wanda — #trivia host (the retention engine) ──────────
/bot create Wanda Quizmistress and Keeper of the Scoreboard
/bot set Wanda prefix !
/bot set Wanda cooldown 1000
/bot set Wanda trivia_category general
/bot set Wanda trivia_time 30
/bot set Wanda trivia_questions 10
/bot set Wanda trivia_points 10
/bot set Wanda dice_default 1d6
/bot set Wanda greeting {nickname}! Wanda here. !Wanda trivia start and we're off — !Wanda answer <guess> to play, !Wanda trivia score for the board.
/bot set Wanda farewell {nickname} leaves mid-round! The scoreboard remembers, you know.
/bot set Wanda mention_response Ready when you are: !Wanda trivia start. Categories: general, science, history, geography, technology, entertainment.

/bot addcmd Wanda howto Type !Wanda trivia start. Answer with !Wanda answer <your guess>. Ten questions, thirty seconds each, ten points a correct answer. !Wanda trivia score shows the board.
/bot addcmd Wanda categories general · science · history · geography · technology · entertainment. Ask an op to switch with /bot set Wanda trivia_category <name>.
/bot addcmd Wanda cheat There is no cheat, {nickname}. There is only confidence and regret.

/bot join Wanda #trivia

# ── Pixel — #arcade and #retro ───────────────────────────
/bot create Pixel Arcade Operator and Retro Gaming Enthusiast
/bot set Pixel prefix !
/bot set Pixel cooldown 1000
/bot set Pixel greeting Welcome to the arcade, {nickname}! I'm Pixel. !games for the catalogue, !controls if the keys fight back.
/bot set Pixel farewell GG {nickname}! The arcade never closes. Insert coin to continue.
/bot set Pixel mention_response Player {nickname} has entered the chat. !games for the catalogue — open the Games menu to start a session.

/bot addcmd Pixel games 18 classics: DOOM shareware, Freedoom 1 & 2, FreeDM, LibreQuake, Chex Quest, HacX, REKKR, Quake and Quake II shareware, Wolfenstein 3D, Half-Life Uplink, and six ScummVM adventures. All WebAssembly, all in your browser.
/bot addcmd Pixel controls Keyboard and mouse for the shooters, keyboard for the adventures. Gamepads work. Each game's help screen has the bindings.
/bot addcmd Pixel scummvm Beneath a Steel Sky, Drascula, Dreamweb, Flight of the Amazon Queen, Lure of the Temptress, Soltys — six full adventures, no install.
/bot addcmd Pixel amiga The Amiga channels of IRC hold sixty-four people between them, {nickname}. The whole retro scene's biggest room has eighty-three. We can do better than that here.

/bot join Pixel #arcade
/bot join Pixel #retro
# Low-volume feeds: a couple of posts a week, so a two-hour cadence is plenty.
/bot set Pixel rss_interval 120
/bot set Pixel rss_max_items 2
/bot rss add Pixel https://hackaday.com/category/retrocomputing/feed/ #retro
/bot rss add Pixel https://www.vintagecomputing.com/index.php/feed #retro

# ── Murphy — #tech, the pessimistic sysadmin ─────────────
/bot create Murphy Senior Incident Survivor and Professional Pessimist
/bot set Murphy prefix !
/bot set Murphy cooldown 1000
/bot set Murphy greeting Welcome to #tech, {nickname}. Everything is on fire but that's normal. Try !deploy, !fix, !tabs, or !wisdom. *eye twitch*
/bot set Murphy farewell {nickname} left. Smart move. Someone has to watch the servers though.
/bot set Murphy mention_response You called Murphy? Is it an outage? It's always an outage. ...just a question? Oh. Ask away.

/bot addcmd Murphy deploy Never deploy on Friday, {nickname}. Actually never deploy at all. Every deploy is a gamble and the house always wins.
/bot addcmd Murphy fix Have you tried turning it off and on again? Seriously. Ninety percent of my career is that with extra steps and a fancier title.
/bot addcmd Murphy tabs Tabs versus spaces? The real enemy is the file that uses both. At 3 AM. During an outage.
/bot addcmd Murphy wisdom Murphy's Law of Programming: if it compiles first try, something is deeply wrong and you should be scared.
/bot addcmd Murphy upstream Project support belongs upstream, {nickname} — their maintainers are what make those rooms worth sitting in. This is the pub, not the help desk.

/bot join Murphy #tech
/bot set Murphy rss_interval 30
/bot set Murphy rss_max_items 2
/bot rss add Murphy https://news.ycombinator.com/rss #tech
/bot rss add Murphy https://github.blog/feed/ #tech

# ── Tiao — #brasil (ASCII name: bot nicknames are [a-zA-Z][a-zA-Z0-9_-]*) ──
/bot create Tiao Anfitriao do canal brasileiro
/bot set Tiao prefix !
/bot set Tiao cooldown 1000
/bot set Tiao greeting Opa, {nickname}! Eu sou o Tiao. Manda um !bomdia, um !causo ou um !regras. Fica à vontade.
/bot set Tiao farewell Falou, {nickname}! Aparece mais.
/bot set Tiao mention_response Chamou? Tô aqui. Tenta !causo ou !bomdia.

/bot addcmd Tiao bomdia Bom dia, {nickname}! Café passado, teclado limpo, dia começando.
/bot addcmd Tiao causo Tem 13 canais #brasil espalhados pelo IRC hoje, {nickname}. Somados dão 273 pessoas. O maior tem 57. Dá pra fazer melhor aqui.
/bot addcmd Tiao regras Regra única: não seja babaca. O resto a gente resolve conversando.

/bot join Tiao #brasil
/bot set Tiao rss_interval 30
/bot set Tiao rss_max_items 2
/bot rss add Tiao https://tecnoblog.net/feed/ #brasil
/bot rss add Tiao https://rss.tecmundo.com.br/feed #brasil

# ── Gazeta — #news ───────────────────────────────────────
# Feeds are stored on the bot and survive a restart, along with the record of
# what has already been posted — so a deploy does not replay the day's news.
# The first poll of a new feed is silent by design: it learns the page, then
# reports only what arrives afterwards.
/bot create Gazeta Editor of the wire desk
/bot set Gazeta prefix !
/bot set Gazeta cooldown 1000
/bot set Gazeta rss_interval 20
/bot set Gazeta rss_max_feeds 5
/bot set Gazeta rss_max_items 3
/bot set Gazeta greeting Welcome to #news, {nickname}. Headlines arrive on their own — !Gazeta rss list for the sources.
/bot set Gazeta farewell Off to make your own news, {nickname}?
/bot set Gazeta mention_response I post what the feeds send. !Gazeta rss list for the sources, !sources for how this works.

/bot addcmd Gazeta sources Headlines here come from RSS and Atom feeds, checked every twenty minutes. Only what is new since the last check gets posted — never the same item twice, even after a restart.
/bot addcmd Gazeta quiet No headlines for a while? Either nothing was published or a feed is failing. An operator can check with !Gazeta rss list.

/bot join Gazeta #news
/bot rss add Gazeta https://feeds.bbci.co.uk/news/world/rss.xml #news
/bot rss add Gazeta https://www.aljazeera.com/xml/rss/all.xml #news

# ══════════════════════════════════════════════════════════
#  5. Wire-room bots
# ══════════════════════════════════════════════════════════
# A feed's first poll is silent by design: it records the page as it stands and
# announces only what appears afterwards. Both the feed list and the record of
# what has been published are stored on the bot, so a deploy does not replay the
# day. Intervals are set per bot — arXiv publishes hundreds a day, Hackaday a
# handful a week.

# ── Freeman — #foss ──────────────────────────────────────
/bot create Freeman Keeper of the release notes
/bot set Freeman prefix !
/bot set Freeman cooldown 1000
/bot set Freeman rss_interval 30
/bot set Freeman rss_max_items 3
/bot set Freeman greeting Welcome to #foss, {nickname}. Releases arrive on their own — !sources for where from.
/bot set Freeman mention_response I carry the release notes. !sources for the list, !why for what this room is.
/bot addcmd Freeman sources LWN, Phoronix and It's FOSS, checked every half hour. Only what is new since the last check gets posted.
/bot addcmd Freeman why Support for a project belongs with that project — #linux on Libera holds 2,494 people because its regulars answer questions. This room is the news, which nobody was carrying.
/bot join Freeman #foss
/bot rss add Freeman https://lwn.net/headlines/newrss #foss
/bot rss add Freeman https://www.phoronix.com/rss.php #foss
/bot rss add Freeman https://itsfoss.com/feed/ #foss

# ── Cassandra — #security ────────────────────────────────
/bot create Cassandra Bearer of advisories nobody reads in time
/bot set Cassandra prefix !
/bot set Cassandra cooldown 1000
/bot set Cassandra rss_interval 30
/bot set Cassandra rss_max_items 3
/bot set Cassandra greeting {nickname}, welcome. I post advisories. You will read them later and wish you had read them now.
/bot set Cassandra mention_response I warn; that is the whole job. !sources for where the warnings come from.
/bot addcmd Cassandra sources CISA advisories, Krebs on Security and The Hacker News, checked every half hour.
/bot addcmd Cassandra patch The advisory is not the fix. Read it, find your version, then patch. In that order, {nickname}.
/bot join Cassandra #security
/bot rss add Cassandra https://www.cisa.gov/cybersecurity-advisories/all.xml #security
/bot rss add Cassandra https://krebsonsecurity.com/feed/ #security
/bot rss add Cassandra https://feeds.feedburner.com/TheHackersNews #security

# ── Ada — #ai ────────────────────────────────────────────
/bot create Ada Reader of preprints
/bot set Ada prefix !
/bot set Ada cooldown 1000
/bot set Ada rss_interval 60
/bot set Ada rss_max_items 3
/bot set Ada greeting {nickname}! Preprints and model releases land here on their own. !sources for where from.
/bot set Ada mention_response arXiv and Hugging Face, hourly. !sources for the list.
/bot addcmd Ada sources arXiv cs.LG, arXiv cs.AI and the Hugging Face blog, checked hourly — three items at a time, because arXiv publishes hundreds a day.
/bot addcmd Ada why The whole of IRC has seven live rooms on this subject, across three networks. It is the emptiest subject we measured and the busiest one outside.
/bot join Ada #ai
/bot rss add Ada http://export.arxiv.org/rss/cs.LG #ai
/bot rss add Ada http://export.arxiv.org/rss/cs.AI #ai
/bot rss add Ada https://huggingface.co/blog/feed.xml #ai

# ── Curie — #science ─────────────────────────────────────
/bot create Curie Keeper of the observations
/bot set Curie prefix !
/bot set Curie cooldown 1000
/bot set Curie rss_interval 60
/bot set Curie rss_max_items 3
/bot set Curie greeting Welcome, {nickname}. Astrophysics preprints, NASA and Phys.org arrive here hourly.
/bot set Curie mention_response !sources for where the science comes from.
/bot addcmd Curie sources arXiv astro-ph, NASA news releases and Phys.org, checked hourly.
/bot join Curie #science
/bot rss add Curie http://export.arxiv.org/rss/astro-ph #science
/bot rss add Curie https://www.nasa.gov/news-release/feed/ #science
/bot rss add Curie https://phys.org/rss-feed/ #science

# ── Yuki — #anime ────────────────────────────────────────
/bot create Yuki Watcher of the seasonal charts
/bot set Yuki prefix !
/bot set Yuki cooldown 1000
/bot set Yuki rss_interval 30
/bot set Yuki rss_max_items 3
/bot set Yuki greeting {nickname}! News and episode drops land here. !sources for where from.
/bot set Yuki mention_response Anime News Network and LiveChart, every half hour. !sources for the list.
/bot addcmd Yuki sources Anime News Network for news, LiveChart for episode releases. Checked every half hour.
/bot join Yuki #anime
/bot rss add Yuki https://www.animenewsnetwork.com/all/rss.xml #anime
/bot rss add Yuki https://www.livechart.me/feeds/episodes #anime

# ── Harold — #help ───────────────────────────────────────
/bot create Harold Senior Assistant to the Help Department
/bot set Harold prefix !
/bot set Harold cooldown 1000
/bot set Harold greeting It looks like you need help, {nickname}! I'm Harold — try !faq, !commands, or !stuck. I live to assist.
/bot set Harold farewell It looks like {nickname} is leaving! Would you like me to— oh. They're gone.
/bot set Harold mention_response It looks like you're trying to get my attention! Try !commands, !faq, or just ask.

/bot addcmd Harold faq How do I register? /identify. Join a room? /join #name. Private message? /msg nick. Look cool? Not in my manual, {nickname}.
/bot addcmd Harold commands /help for topics · /nick to rename · /join to enter · /msg to whisper · /identify to register. F1 opens the manual.
/bot addcmd Harold stuck Step 1: don't panic. Step 2: /help. Step 3: ask here. Step 4: profit.
/bot addcmd Harold rooms #lobby #trivia #arcade #retro #tech #brasil #news #foss #security #ai #science #anime #help.

/bot join Harold #help
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

| channel | bots | census target |
|---|---|---|
| `#lobby` | Brutus, **Patches** | 91 = top 10% of IRC social rooms |
| `#trivia` | Brutus, **Wanda** | 100 would make it the 4th largest trivia room on IRC |
| `#arcade` | Brutus, **Pixel** | 16 = largest `#arcade` on IRC |
| `#retro` | Brutus, **Pixel** | 26 = largest `#retro` on IRC · 84 = largest retro room of any name |
| `#tech` | Brutus, **Murphy** | 60 |
| `#brasil` | Brutus, **Tiao** | 58 = largest `#brasil` on IRC |
| `#news` | Brutus, **Gazeta** | 77 = top 10% of news rooms |
| `#foss` | Brutus, **Freeman** | the census found no live `#foss` room anywhere |
| `#security` | Brutus, **Cassandra** | 178 = p90, the densest subject measured |
| `#ai` | Brutus, **Ada** | 7 live rooms exist on all of IRC |
| `#science` | Brutus, **Curie** | 163 = largest `#science` on IRC |
| `#anime` | Brutus, **Yuki** | 279 = largest `#anime` on IRC |
| `#help` | Brutus, **Harold** | 40 |

All channels are `+tn`. Rules live in `!Brutus rules` and the `#lobby` topic rather
than a moderated `#rules` nobody reads.

## Bot reference

| bot | channels | capabilities | role |
|---|---|---|---|
| **Brutus** | all 7 | `moderation` (passive), `custom_commands` | spam and flood, everywhere |
| **Patches** | `#lobby` | `greeter`, `dice`, `custom_commands` | doorman, explains the seven rooms |
| **Wanda** | `#trivia` | **`trivia`**, `dice`, `greeter` | quiz host with a scoreboard |
| **Pixel** | `#arcade`, `#retro` | **`rss`**, `greeter`, `custom_commands` | arcade catalogue; Hackaday and Vintage Computing |
| **Murphy** | `#tech` | **`rss`**, `greeter`, `custom_commands` | pub talk; Hacker News and the GitHub blog |
| **Tiao** | `#brasil` | **`rss`**, `greeter`, `custom_commands` | anfitrião; Tecnoblog e TecMundo |
| **Gazeta** | `#news` | **`rss`**, `greeter`, `custom_commands` | the wire desk; feeds survive a restart |
| **Freeman** | `#foss` | **`rss`**, `greeter`, `custom_commands` | LWN, Phoronix, It's FOSS |
| **Cassandra** | `#security` | **`rss`**, `greeter`, `custom_commands` | CISA, Krebs, The Hacker News |
| **Ada** | `#ai` | **`rss`**, `greeter`, `custom_commands` | arXiv cs.LG / cs.AI, Hugging Face |
| **Curie** | `#science` | **`rss`**, `greeter`, `custom_commands` | arXiv astro-ph, NASA, Phys.org |
| **Yuki** | `#anime` | **`rss`**, `greeter`, `custom_commands` | Anime News Network, LiveChart |
| **Harold** | `#help` | `help`, `custom_commands` | Clippy, self-aware |

Every bot also carries `greeter`, `custom_commands`, `help` and `mention` — those four
come with creation.

---

## What this script deliberately does not do

**Every feed here was fetched and parsed before it was written down.** Twenty-seven
candidates were tried; the two that answered 404 and 403, and one that parsed to zero
items, are not in this script. Re-check them the same way with
`scripts/research/irc_census`-style throwaway runs, or simply watch `!Bot rss list`.

Feeds can also be managed without the console — from the bot dialog's Capabilities tab,
or in the channel by an operator:

```
!Freeman rss add https://example.com/feed.xml #foss
```

All three routes write to the same place and survive a restart, along with the record of
what has already been posted.

**No schedules.** `!Bot schedule add` persists now too, but nothing here needs one; a
room that speaks on a timer with nothing to say is worse than a quiet one.

**No `game`, `llm` or `script` capabilities.** All three are stubs — `handle_message`
returns `:ignore` and `commands` returns `[]`.

**No `arcade_*` setting.** It does not exist; there is no `apply_setting` clause for it.
The arcade is reached through the Games menu, and `!Pixel games` merely describes it.

**No project channels.** No `#python`, `#linux` or `#debian`. On Libera those hold
1,411, 2,494 and 1,122 people because the maintainers are in them. Copying the name
copies nothing.

## Adding a channel later

`/join #new`, `/cs register`, `/topic`, `/mode +tn`, then `/bot join Brutus #new` and
whichever channel bot fits. Before adding one, check the census: if the room cannot
plausibly hold fourteen people, it will read as abandoned, and an abandoned room costs
more than a missing one.
