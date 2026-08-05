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
/bot set Brutus mod_warn \c04\b[Brutus]\o Easy there, {nickname}. \c05Keep it civil\o or Brutus gets grumpy. And trust me, you don't want that.
# Silent on arrival and departure. Brutus stands in all thirteen rooms, so a
# greeting from him would double every welcome the host bot gives — and a
# bouncer who says hello twice reads as a glitch, not a personality.
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
# Greetings are private notices scoped to the room: the newcomer gets useful
# orientation in the channel viewport without turning everyone else's scrollback
# into bot chatter. The repeat window keeps reconnects from replaying the same
# line to the same nick over and over.
/bot create Patches Lobby Attendant and Channel Tour Guide
/bot set Patches prefix !
/bot set Patches cooldown 1000
/bot set Patches dice_default 1d20
/bot set Patches greeting \c03\b[Patches]\o \c10Yo {nickname}!\o I'm Patches — lobby attendant. Try !tour, !rooms, or !Patches roll. Make yourself at home.
/bot set Patches greeting_delivery private_notice
/bot set Patches greeter_repeat_window 43200
/bot set Patches farewell none
/bot set Patches mention_response \c03\b[Patches]\o Patches here. \c10Need directions?\o !tour for the grand tour, or just ask.

/bot addcmd Patches tour \c03\b[Patches]\o Talk to people in #lobby, #brasil and #tech. \c10Play\o in #trivia and #arcade. \c02Read the wire\o in #news, #foss, #security, #ai, #science and #anime. #retro is for anything that booted from a floppy, #help for when you are stuck.
/bot addcmd Patches rooms \c03\b[Patches]\o #lobby #trivia #arcade #retro #tech #brasil #news #foss #security #ai #science #anime #help — \c10thirteen rooms\o, and every one of them has something in it.
/bot addcmd Patches why \c03\b[Patches]\o The median live IRC channel holds fourteen people, {nickname}, so we keep one place to talk rather than four. \c10Wire rooms\o are different: a feed gives a room something to show before it has a crowd.
/bot addcmd Patches about \c03\b[Patches]\o RetroHexChat: a retro-styled chat built with \c10Elixir and Phoenix LiveView\o. Windows 98 met a chat room and they fell in love.

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
/bot set Wanda greeting \c06\b[Wanda]\o \c13{nickname}!\o Wanda here. !Wanda trivia start and we're off — !Wanda answer <guess> to play, !Wanda trivia score for the board.
/bot set Wanda greeting_delivery private_notice
/bot set Wanda greeter_repeat_window 43200
/bot set Wanda farewell none
/bot set Wanda mention_response \c06\b[Wanda]\o Ready when you are: !Wanda trivia start. \c13Categories\o: general, science, history, geography, technology, entertainment.

/bot addcmd Wanda howto \c06\b[Wanda]\o Type !Wanda trivia start. Answer with !Wanda answer <your guess>. \c13Ten questions\o, thirty seconds each, ten points a correct answer. !Wanda trivia score shows the board.
/bot addcmd Wanda categories \c06\b[Wanda]\o general · science · history · geography · technology · entertainment. \c13Ask an op\o to switch with /bot set Wanda trivia_category <name>.
/bot addcmd Wanda cheat \c06\b[Wanda]\o There is no cheat, {nickname}. There is only \c13confidence and regret\o.

/bot join Wanda #trivia

# ── Pixel — #arcade and #retro ───────────────────────────
/bot create Pixel Arcade Operator and Retro Gaming Enthusiast
/bot set Pixel prefix !
/bot set Pixel cooldown 1000
/bot set Pixel greeting \c12\b[Pixel]\o Welcome to the arcade, {nickname}! I'm Pixel. \c10!games\o for the catalogue, !controls if the keys fight back.
/bot set Pixel greeting_delivery private_notice
/bot set Pixel greeter_repeat_window 43200
/bot set Pixel farewell none
/bot set Pixel mention_response \c12\b[Pixel]\o Player {nickname} has entered the chat. \c10!games\o for the catalogue — open the Games menu to start a session.

/bot addcmd Pixel games \c12\b[Pixel]\o \c1018 classics\o: DOOM shareware, Freedoom 1 & 2, FreeDM, LibreQuake, Chex Quest, HacX, REKKR, Quake and Quake II shareware, Wolfenstein 3D, Half-Life Uplink, and six ScummVM adventures. All WebAssembly, all in your browser.
/bot addcmd Pixel controls \c12\b[Pixel]\o \c10Keyboard and mouse\o for the shooters, keyboard for the adventures. Gamepads work. Each game's help screen has the bindings.
/bot addcmd Pixel scummvm \c12\b[Pixel]\o Beneath a Steel Sky, Drascula, Dreamweb, Flight of the Amazon Queen, Lure of the Temptress, Soltys — \c10six full adventures\o, no install.
/bot addcmd Pixel amiga \c12\b[Pixel]\o The Amiga channels of IRC hold sixty-four people between them, {nickname}. The whole retro scene's biggest room has eighty-three. \c10We can do better\o than that here.

/bot join Pixel #arcade
/bot join Pixel #retro
# Low-volume feeds: a couple of posts a week, so a two-hour cadence is plenty.
/bot set Pixel rss_interval 120
/bot set Pixel rss_max_items 1000
/bot rss add Pixel https://hackaday.com/category/retrocomputing/feed/ #retro
/bot rss add Pixel https://www.vintagecomputing.com/index.php/feed #retro

# ── Murphy — #tech, the pessimistic sysadmin ─────────────
/bot create Murphy Senior Incident Survivor and Professional Pessimist
/bot set Murphy prefix !
/bot set Murphy cooldown 1000
/bot set Murphy greeting \c14\b[Murphy]\o Welcome to #tech, {nickname}. \c04Everything is on fire\o but that's normal. Try !deploy, !fix, !tabs, or !wisdom. *eye twitch*
/bot set Murphy greeting_delivery private_notice
/bot set Murphy greeter_repeat_window 43200
/bot set Murphy farewell none
/bot set Murphy mention_response \c14\b[Murphy]\o You called Murphy? \c04Is it an outage?\o It's always an outage. ...just a question? Oh. Ask away.

/bot addcmd Murphy deploy \c14\b[Murphy]\o \c04Never deploy on Friday\o, {nickname}. Actually never deploy at all. Every deploy is a gamble and the house always wins.
/bot addcmd Murphy fix \c14\b[Murphy]\o Have you tried \c04turning it off and on again?\o Seriously. Ninety percent of my career is that with extra steps and a fancier title.
/bot addcmd Murphy tabs \c14\b[Murphy]\o Tabs versus spaces? The real enemy is the file that uses \c04both\o. At 3 AM. During an outage.
/bot addcmd Murphy wisdom \c14\b[Murphy]\o Murphy's Law of Programming: if it compiles first try, \c04something is deeply wrong\o and you should be scared.
/bot addcmd Murphy upstream \c14\b[Murphy]\o Project support belongs upstream, {nickname} — their maintainers are what make those rooms worth sitting in. \c04This is the pub\o, not the help desk.

/bot join Murphy #tech
/bot set Murphy rss_interval 30
/bot set Murphy rss_max_items 1000
/bot rss add Murphy https://news.ycombinator.com/rss #tech
/bot rss add Murphy https://github.blog/feed/ #tech

# ── Tiao — #brasil (ASCII name: bot nicknames are [a-zA-Z][a-zA-Z0-9_-]*) ──
/bot create Tiao Anfitriao do canal brasileiro
/bot set Tiao prefix !
/bot set Tiao cooldown 1000
/bot set Tiao greeting \c03\b[Tiao]\o Opa, {nickname}! Eu sou o Tiao. \c02Manda um !bomdia\o, um !causo ou um !regras. Fica à vontade.
/bot set Tiao greeting_delivery private_notice
/bot set Tiao greeter_repeat_window 43200
/bot set Tiao farewell none
/bot set Tiao mention_response \c03\b[Tiao]\o Chamou? Tô aqui. \c02Tenta !causo\o ou !bomdia.

/bot addcmd Tiao bomdia \c03\b[Tiao]\o \c02Bom dia\o, {nickname}! Café passado, teclado limpo, dia começando.
/bot addcmd Tiao causo \c03\b[Tiao]\o Tem 13 canais #brasil espalhados pelo IRC hoje, {nickname}. Somados dão 273 pessoas. O maior tem 57. \c02Dá pra fazer melhor\o aqui.
/bot addcmd Tiao regras \c03\b[Tiao]\o Regra única: \c02não seja babaca\o. O resto a gente resolve conversando.

/bot join Tiao #brasil
/bot set Tiao rss_interval 30
/bot set Tiao rss_max_items 1000
/bot rss add Tiao https://tecnoblog.net/feed/ #brasil
/bot rss add Tiao https://rss.tecmundo.com.br/feed #brasil

# ── Gazeta — #news ───────────────────────────────────────
# Feeds are stored on the bot and survive a restart, along with the record of
# what has already been seen — so a deploy does not replay the day's news.
# The first poll of a new feed publishes the page it receives, records it, then
# reports only what arrives afterwards.
/bot create Gazeta Editor of the wire desk
/bot set Gazeta prefix !
/bot set Gazeta cooldown 1000
/bot set Gazeta rss_interval 20
/bot set Gazeta rss_max_feeds 5
/bot set Gazeta rss_max_items 1000
/bot set Gazeta greeting \c02\b[Gazeta]\o Welcome to #news, {nickname}. \c14Headlines arrive on their own\o — !Gazeta rss list for the sources.
/bot set Gazeta greeting_delivery private_notice
/bot set Gazeta greeter_repeat_window 43200
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
# arXiv publishes hundreds a day, Hackaday a handful a week.

# ── Freeman — #foss ──────────────────────────────────────
/bot create Freeman Keeper of the release notes
/bot set Freeman prefix !
/bot set Freeman cooldown 1000
/bot set Freeman rss_interval 30
/bot set Freeman rss_max_items 1000
/bot set Freeman greeting \c03\b[Freeman]\o Welcome to #foss, {nickname}. \c02Releases arrive on their own\o — !sources for where from.
/bot set Freeman greeting_delivery private_notice
/bot set Freeman greeter_repeat_window 43200
/bot set Freeman mention_response \c03\b[Freeman]\o I carry the release notes. !sources for the list, \c02!why\o for what this room is.
/bot addcmd Freeman sources \c03\b[Freeman]\o LWN, Phoronix and It's FOSS, checked every half hour. The first fetch posts the current page; \c02only new items\o are posted after that.
/bot addcmd Freeman why \c03\b[Freeman]\o Support for a project belongs with that project — #linux on Libera holds 2,494 people because its regulars answer questions. \c02This room is the news\o, which nobody was carrying.
/bot join Freeman #foss
/bot rss add Freeman https://lwn.net/headlines/newrss #foss
/bot rss add Freeman https://www.phoronix.com/rss.php #foss
/bot rss add Freeman https://itsfoss.com/feed/ #foss

# ── Cassandra — #security ────────────────────────────────
/bot create Cassandra Bearer of advisories nobody reads in time
/bot set Cassandra prefix !
/bot set Cassandra cooldown 1000
/bot set Cassandra rss_interval 30
/bot set Cassandra rss_max_items 1000
/bot set Cassandra greeting \c04\b[Cassandra]\o {nickname}, welcome. I post advisories. \c05You will read them later\o and wish you had read them now.
/bot set Cassandra greeting_delivery private_notice
/bot set Cassandra greeter_repeat_window 43200
/bot set Cassandra mention_response \c04\b[Cassandra]\o I warn; that is the whole job. \c05!sources\o for where the warnings come from.
/bot addcmd Cassandra sources \c04\b[Cassandra]\o CISA advisories, Krebs on Security and The Hacker News, \c05checked every half hour\o.
/bot addcmd Cassandra patch \c04\b[Cassandra]\o The advisory is not the fix. \c05Read it, find your version, then patch\o. In that order, {nickname}.
/bot join Cassandra #security
/bot rss add Cassandra https://us-cert.cisa.gov/ncas/alerts.xml #security
/bot rss add Cassandra https://krebsonsecurity.com/feed/ #security
/bot rss add Cassandra https://feeds.feedburner.com/TheHackersNews #security

# ── Ada — #ai ────────────────────────────────────────────
/bot create Ada Reader of preprints
/bot set Ada prefix !
/bot set Ada cooldown 1000
/bot set Ada rss_interval 60
/bot set Ada rss_max_items 1000
/bot set Ada greeting \c10\b[Ada]\o {nickname}! \c06Preprints and model releases\o land here on their own. !sources for where from.
/bot set Ada greeting_delivery private_notice
/bot set Ada greeter_repeat_window 43200
/bot set Ada mention_response \c10\b[Ada]\o arXiv and Hugging Face, \c06hourly\o. !sources for the list.
/bot addcmd Ada sources \c10\b[Ada]\o arXiv cs.LG, arXiv cs.AI and the Hugging Face blog, checked hourly — \c06the feed page is posted\o, then only new items after that.
/bot addcmd Ada why \c10\b[Ada]\o The whole of IRC has seven live rooms on this subject, across three networks. \c06It is the emptiest subject we measured\o and the busiest one outside.
/bot join Ada #ai
/bot rss add Ada http://export.arxiv.org/rss/cs.LG #ai
/bot rss add Ada http://export.arxiv.org/rss/cs.AI #ai
/bot rss add Ada https://huggingface.co/blog/feed.xml #ai

# ── Curie — #science ─────────────────────────────────────
/bot create Curie Keeper of the observations
/bot set Curie prefix !
/bot set Curie cooldown 1000
/bot set Curie rss_interval 60
/bot set Curie rss_max_items 1000
/bot set Curie greeting \c12\b[Curie]\o Welcome, {nickname}. \c02Astrophysics preprints, NASA and Phys.org\o arrive here hourly.
/bot set Curie greeting_delivery private_notice
/bot set Curie greeter_repeat_window 43200
/bot set Curie mention_response \c12\b[Curie]\o !sources for where the \c02science\o comes from.
/bot addcmd Curie sources \c12\b[Curie]\o arXiv astro-ph, NASA news releases and Phys.org, \c02checked hourly\o.
/bot join Curie #science
/bot rss add Curie http://export.arxiv.org/rss/astro-ph #science
/bot rss add Curie https://www.nasa.gov/news-release/feed/ #science
/bot rss add Curie https://phys.org/rss-feed/ #science

# ── Yuki — #anime ────────────────────────────────────────
/bot create Yuki Watcher of the seasonal charts
/bot set Yuki prefix !
/bot set Yuki cooldown 1000
/bot set Yuki rss_interval 30
/bot set Yuki rss_max_items 1000
/bot set Yuki greeting \c13\b[Yuki]\o {nickname}! \c06News and episode drops\o land here. !sources for where from.
/bot set Yuki greeting_delivery private_notice
/bot set Yuki greeter_repeat_window 43200
/bot set Yuki mention_response \c13\b[Yuki]\o Anime News Network and LiveChart, \c06every half hour\o. !sources for the list.
/bot addcmd Yuki sources \c13\b[Yuki]\o Anime News Network for news, LiveChart for episode releases. \c06Checked every half hour\o.
/bot join Yuki #anime
/bot rss add Yuki https://www.animenewsnetwork.com/all/rss.xml #anime
/bot rss add Yuki https://www.livechart.me/feeds/episodes #anime

# ── Harold — #help ───────────────────────────────────────
/bot create Harold Senior Assistant to the Help Department
/bot set Harold prefix !
/bot set Harold cooldown 1000
/bot set Harold greeting \c02\b[Harold]\o It looks like you need help, {nickname}! I'm Harold — try !faq, !commands, or !stuck. \c03I live to assist\o.
/bot set Harold greeting_delivery private_notice
/bot set Harold greeter_repeat_window 43200
/bot set Harold farewell none
/bot set Harold mention_response \c02\b[Harold]\o It looks like you're trying to get my attention! \c03Try !commands\o, !faq, or just ask.

/bot addcmd Harold faq \c02\b[Harold]\o How do I register? \c03/identify\o. Join a room? /join #name. Private message? /msg nick. Look cool? Not in my manual, {nickname}.
/bot addcmd Harold commands \c02\b[Harold]\o /help for topics · /nick to rename · /join to enter · /msg to whisper · /identify to register. \c03F1 opens the manual\o.
/bot addcmd Harold stuck \c02\b[Harold]\o Step 1: don't panic. Step 2: /help. Step 3: ask here. \c03Step 4: profit\o.
/bot addcmd Harold rooms \c02\b[Harold]\o #lobby #trivia #arcade #retro #tech #brasil #news #foss #security #ai #science #anime #help.

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
| **Brutus** | all 13 | `moderation` (passive), `custom_commands` | spam and flood, everywhere |
| **Patches** | `#lobby` | `greeter`, `dice`, `custom_commands` | doorman, explains the thirteen rooms |
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
what has already been seen. A newly added feed is fetched within seconds to post and
record the current page; after that, only items that arrive later are posted.

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
