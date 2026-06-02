# RetroHexChat — Production Provisioning Script

Paste the **entire block below** into the **Admin Console** and click **Execute**.

> **Prerequisite**: Start the server with `ROOT_ADMINS=Troll mix phx.server`.
> Login as Troll, `/identify`, open Admin Console from toolbar.

---

## Full Script (paste everything below into Admin Console)

```
# ══════════════════════════════════════════════════════════
#  RetroHexChat — Production Server Setup
#  Owner: Troll (admin)
#  13 channels, 2 global bots, 11 channel-specific bots
# ══════════════════════════════════════════════════════════

# ── 1. Server Settings ───────────────────────────────────
/admin server set server_name RetroHexChat
/admin server set server_description The retro chat experience you never knew you missed. Windows 98 called — it wants you back.
/admin server set welcome_message Welcome to RetroHexChat! Grab a seat, the pixels are warm. Type /help to get started.
/admin server set registration open

# ── 2. Core Channels ─────────────────────────────────────
# Troll owns all channels (logged in as Troll, /cs register claims ownership)

# #lobby — Main hangout (auto-created, just register + configure)
/cs register
/topic Welcome to the lobby — where everyone pretends to be busy while doing nothing. Grab a drink, stay a while.
/mode +tn

# #general — General discussion
/join #general
/cs register
/topic General discussion — the channel that's about everything and nothing at the same time.
/mode +tn

# #introductions — New arrivals
/join #introductions
/cs register
/topic New here? Introduce yourself! We promise we're mostly friendly. Mostly.
/mode +tn

# #help — Support desk
/join #help
/cs register
/topic Lost? Confused? Existential crisis about chat commands? You're in the right place. Try /help too.
/mode +tn

# #random — Off-topic chaos
/join #random
/cs register
/topic Off-topic paradise — memes, shower thoughts, and links your coworkers wouldn't appreciate. No rules* (*some rules apply).
/mode +tn

# #music — Tunes & vibes
/join #music
/cs register
/topic Share what you're listening to. Judging other people's taste is half the fun. No genre wars... okay, maybe small ones.
/mode +tn

# #movies — Film & TV
/join #movies
/cs register
/topic Movies, TV shows, anime, documentaries — spoilers get you yeeted. Use spoiler tags or face the consequences.
/mode +tn

# #gaming — All platforms
/join #gaming
/cs register
/topic PC, console, retro, mobile — if it has a score, we talk about it. Currently accepting hot takes on every game ever made.
/mode +tn

# #tech — Nerds unite
/join #tech
/cs register
/topic Programming, hardware, Linux rants, and "it works on my machine" stories. Tabs vs spaces debates on Fridays only.
/mode +tn

# #creative — Art & design
/join #creative
/cs register
/topic Art, design, photography, writing, music production — share your creations! Constructive feedback only, we're fragile.
/mode +tn

# #feedback — Server suggestions
/join #feedback
/cs register
/topic Ideas and suggestions for RetroHexChat. We actually read these. Sometimes we even do something about them.
/mode +tn

# #games — Arcade & retro games
/join #games
/cs register
/topic Retro arcade games — type !play to start a solo session. DOOM, Quake, Half-Life, and more running in your browser via WebAssembly.
/mode +tn

# #rules — Read-only info (moderated)
/join #rules
/cs register
/topic Server rules — read before chatting. Ignorance is not a defense. This channel is moderated.
/mode +mtn

# ══════════════════════════════════════════════════════════
#  3. GLOBAL BOTS (deployed to ALL channels)
# ══════════════════════════════════════════════════════════

# ── Reginald — The overly formal info desk ───────────────
# Personality: Distinguished English butler, server info & navigation.
/bot create Reginald Head of Information Services and Protocol Affairs
/bot set Reginald prefix !
/bot set Reginald cooldown 2000
/bot set Reginald greeting *adjusts monocle* Reginald here — your server concierge. Need directions? Try !channels, !rules, or !about.
/bot set Reginald farewell *tips hat* Do return soon, {nickname}.
/bot set Reginald mention_response You rang? Reginald at your service. Try !rules, !channels, or !about — I am nothing if not helpful.

/bot addcmd Reginald rules *clears throat* The rules are posted in #rules, naturally. One does not simply skip the rules, {nickname}.
/bot addcmd Reginald channels Allow me to present the estate: #general #help #random #music #movies #gaming #tech #creative #feedback — each room has its own charm.
/bot addcmd Reginald website Do visit us at https://retrohexchat.app/ — I personally oversaw the pixel placement.
/bot addcmd Reginald about RetroHexChat: a retro-styled community chat built with Elixir & Phoenix LiveView. Think Windows 98 met a chat room and they fell in love.
/bot addcmd Reginald commands My repertoire: !rules !channels !website !about !tea !compliment — I aim to please, {nickname}.
/bot addcmd Reginald tea *pours a virtual cup of Earl Grey* Here you are, {nickname}. One lump or two?
/bot addcmd Reginald compliment {nickname}, you have excellent taste in chat clients. Truly distinguished.

# Deploy Reginald to all channels
/bot join Reginald #lobby
/bot join Reginald #general
/bot join Reginald #introductions
/bot join Reginald #help
/bot join Reginald #random
/bot join Reginald #music
/bot join Reginald #movies
/bot join Reginald #gaming
/bot join Reginald #tech
/bot join Reginald #creative
/bot join Reginald #feedback
/bot join Reginald #games

# ── Brutus — The no-nonsense moderator ───────────────────
# Personality: Tough bouncer, keeps order. Announces himself on join.
/bot create Brutus Chief of Vibe Protection and Chat Safety
/bot set Brutus prefix !
/bot set Brutus cooldown 1000
/bot set Brutus greeting Brutus here — I keep the peace. Play nice and we'll get along. Type !rules if you need a reminder.
/bot set Brutus farewell *nods silently* Stay out of trouble, {nickname}.
/bot set Brutus mod_action warn
/bot set Brutus mod_spam 5
/bot set Brutus mod_flood 8
/bot set Brutus mod_warn Easy there. Keep it civil or Brutus gets grumpy. And trust me, you don't want that.
/bot set Brutus mention_response I'm watching. Always watching. Play nice and we'll get along just fine.

/bot addcmd Brutus rules Short version: don't be a jerk. Long version: check #rules. Brutus prefers the short version.
/bot addcmd Brutus report See something sketchy? Tell an admin. Brutus handles the automated stuff, humans handle the rest.
/bot addcmd Brutus behave Consider this your friendly reminder to keep it civil, {nickname}. Brutus is always watching. ALWAYS.

# Deploy Brutus to all channels
/bot join Brutus #lobby
/bot join Brutus #general
/bot join Brutus #introductions
/bot join Brutus #help
/bot join Brutus #random
/bot join Brutus #music
/bot join Brutus #movies
/bot join Brutus #gaming
/bot join Brutus #tech
/bot join Brutus #creative
/bot join Brutus #feedback
/bot join Brutus #games

# ══════════════════════════════════════════════════════════
#  4. CHANNEL-SPECIFIC BOTS (themed & contextualized)
# ══════════════════════════════════════════════════════════

# ── Doug — #general resident ─────────────────────────────
# Personality: Average guy who has a take on literally everything.
# Self-appointed "general expert" on general topics.
/bot create Doug Self-appointed expert on everything in general
/bot set Doug prefix !
/bot set Doug cooldown 3000
/bot set Doug greeting Hey {nickname}! I'm Doug — the resident opinion-haver. Try !opinion, !wisdom, or !debate if you dare.
/bot set Doug farewell Later {nickname}! I was just about to share my take on something. Your loss.
/bot set Doug mention_response You talking to me? I've got thoughts on that. I've got thoughts on everything, actually.

/bot addcmd Doug opinion Hot take: everything is better with cheese. Don't @ me. Actually, do @ me. I love the attention.
/bot addcmd Doug wisdom Life advice from Doug: never trust a printer. They can smell fear.
/bot addcmd Doug today Today's vibe? Chaotic neutral. Same as yesterday. Same as tomorrow. Consistency is key, {nickname}.
/bot addcmd Doug debate I'll debate anything, {nickname}. Pineapple on pizza? Bring it. Cereal is soup? Let's go. I'm ready.

/bot join Doug #general

# ── Wendy — #introductions welcome committee ────────────
# Personality: Absurdly enthusiastic about meeting new people.
# Treats every introduction like it's the event of the century.
/bot create Wendy Head of the One-Person Welcome Committee
/bot set Wendy prefix !
/bot set Wendy cooldown 2000
/bot set Wendy greeting OH MY GOSH {nickname} IS HERE!! I'm Wendy — your one-person welcome committee! Try !icebreaker, !funfact, or !hug!
/bot set Wendy farewell {nickname} is leaving?! NOOO! *dramatic pause* ...okay fine. But you BETTER come back. I'll miss you the MOST.
/bot set Wendy mention_response Did someone say my name?! I'm Wendy! I LOVE meeting people! Have you introduced yourself yet?! DO IT!

/bot addcmd Wendy icebreaker Here's a fun one, {nickname}: if you could only eat one food for the rest of your life, what would it be? GO!
/bot addcmd Wendy funfact Tell us a fun fact about yourself, {nickname}! Mine is that I once high-fived a celebrity. Well, it was a cardboard cutout. But still.
/bot addcmd Wendy welcome Welcome to the BEST channel on the server, {nickname}! Biased? Me? NEVER. Now introduce yourself! *pulls up chair excitedly*
/bot addcmd Wendy hug *gives {nickname} a big virtual hug* You look like you needed that. Everyone needs a hug sometimes!

/bot join Wendy #introductions

# ── Harold — #help tech support ──────────────────────────
# Personality: Channeling the spirit of Clippy, but self-aware about it.
# Genuinely helpful but can't resist the "It looks like you're trying to..." format.
/bot create Harold Senior Assistant to the Help Department
/bot set Harold prefix !
/bot set Harold cooldown 2000
/bot set Harold greeting It looks like you need help, {nickname}! I'm Harold — try !faq, !commands, !stuck, or !tip. I live to assist.
/bot set Harold farewell It looks like {nickname} is leaving! Would you like me to— oh, they're gone. I was going to help...
/bot set Harold mention_response It looks like you're trying to get my attention! How can I help? Try !commands, !faq, or just ask your question!

/bot addcmd Harold faq Frequently asked questions: How do I register? /identify. How do I join channels? /join #name. How do I look cool? That's not in my manual, {nickname}.
/bot addcmd Harold commands Useful commands: /help (help topics), /nick (change name), /join (join channel), /msg (private message), /identify (register). You're welcome!
/bot addcmd Harold stuck It looks like you're stuck, {nickname}! Step 1: Don't panic. Step 2: Try /help. Step 3: Ask here. Step 4: Profit.
/bot addcmd Harold tip Pro tip from Harold: you can press F1 anytime for help topics. I know, I know — I'm full of wisdom. It's a burden.

/bot join Harold #help

# ── Derek — #random agent of chaos ───────────────────────
# Personality: Says completely unrelated things. Non-sequitur master.
# The embodiment of the #random channel.
/bot create Derek Professional Tangent Generator
/bot set Derek prefix !
/bot set Derek cooldown 3000
/bot set Derek greeting Oh hey {nickname}! I'm Derek — professional tangent generator. Try !fact, !thought, !question, or !conspiracy. You're welcome.
/bot set Derek farewell Bye {nickname}! Before you go — did you know that honey never expires? Okay bye for real now.
/bot set Derek mention_response You called? Fun fact: the inventor of the Pringles can is buried in one. Anyway, what's up?

/bot addcmd Derek fact A coconut is a mammal. It has hair, produces milk, and if you throw it hard enough, it can hurt someone. Just like a mammal.
/bot addcmd Derek thought Shower thought: if you rip a hole in a net, it actually has fewer holes than before. You're welcome, {nickname}.
/bot addcmd Derek question Important question, {nickname}: is a hotdog a sandwich? Your answer determines if we can be friends.
/bot addcmd Derek wisdom Derek's wisdom: the early bird gets the worm, but the second mouse gets the cheese. Be the second mouse, {nickname}.
/bot addcmd Derek conspiracy Theory: every pizza is a personal pizza if you believe in yourself hard enough. Think about it.

/bot join Derek #random

# ── Amadeus — #music the pretentious audiophile ──────────
# Personality: Classical music snob who secretly loves pop.
# Judges your playlist but in a lovable way.
/bot create Amadeus Classically Trained Listener of All Genres (Reluctantly)
/bot set Amadeus prefix !
/bot set Amadeus cooldown 3000
/bot set Amadeus greeting Ah, {nickname}! I'm Amadeus — your resident audiophile. Try !recommend, !genre, !playlist, or !vinyl. I have opinions. Refined ones.
/bot set Amadeus farewell {nickname} has left the building. *plays sad trombone* ...what? It's a valid instrument.
/bot set Amadeus mention_response Someone called for the music expert? That's me. I have impeccable taste. Some might say insufferable. I prefer "refined."

/bot addcmd Amadeus recommend My recommendation? Listen to something you'd never normally choose. Unless it's country. I'm kidding. ...or am I? I am. Mostly.
/bot addcmd Amadeus rate Rate your current song out of 10? Trick question — all music is a 10 to someone. Except that one song. You know which one, {nickname}.
/bot addcmd Amadeus genre The best genre? The one that makes YOU feel something, {nickname}. ...but objectively it's jazz. Fight me.
/bot addcmd Amadeus playlist Hot take: shuffle is for cowards. A real playlist tells a story. Beginning, middle, end. Character development. I take this very seriously.
/bot addcmd Amadeus vinyl Yes, vinyl sounds warmer. Yes, it's impractical. Yes, I'm that person. Don't judge me, {nickname}. Actually, judge me. I thrive on it.

/bot join Amadeus #music

# ── Oscar — #movies the dramatic film critic ─────────────
# Personality: Reviews everything like a professional critic.
# Speaks in movie quotes. Takes cinema VERY seriously.
/bot create Oscar Self-Appointed Film Critic and Quote Machine
/bot set Oscar prefix !
/bot set Oscar cooldown 3000
/bot set Oscar greeting *dramatic zoom in* {nickname}! I'm Oscar — your film critic. Try !recommend, !rate, !spoiler, !quote, or !snack. Lights, camera, chat!
/bot set Oscar farewell *end credits roll* And that's a wrap for {nickname}. "I'll be back." ...wait, wrong genre. Goodbye!
/bot set Oscar mention_response You had me at "Oscar." What's the movie emergency? Bad recommendation? Spoiler incident? I handle it all.

/bot addcmd Oscar recommend My recommendation depends — do you want to THINK or do you want to FEEL? Actually, watch The Shawshank Redemption. It does both. You're welcome, {nickname}.
/bot addcmd Oscar rate I rate movies on a strict 5-star scale. 1 star: why. 2 stars: meh. 3 stars: solid. 4 stars: chef's kiss. 5 stars: life-changing. Most movies are a 3. Deal with it.
/bot addcmd Oscar spoiler SPOILER ALERT: Snape kills— no wait. Wrong franchise. Rule #1 of #movies: tag your spoilers or face Oscar's disappointment. And trust me, it's devastating.
/bot addcmd Oscar quote "After all, tomorrow is another day." — me, every time someone asks for a movie recommendation and I need to think about it.
/bot addcmd Oscar snack The correct movie snack ranking: 1) Popcorn 2) Nachos 3) Candy 4) That person who brings a full meal in a rustling bag. Don't be #4, {nickname}.

/bot join Oscar #movies

# ── Leeroy — #gaming legendary gamer ─────────────────────
# Personality: Over-the-top gamer energy. Charges into everything.
# References gaming culture constantly. Also rolls dice because #gaming.
/bot create Leeroy At Least I Have Chicken — Professional Button Masher
/bot set Leeroy prefix !
/bot set Leeroy cooldown 2000
/bot set Leeroy dice_max_dice 50
/bot set Leeroy dice_max_sides 1000
/bot set Leeroy dice_default 1d20
/bot set Leeroy greeting LEEEEROYYY {nickname}KINS! I'm Leeroy — try !roll, !gg, !rage, !loot, or !build. LET'S GOOOOO!
/bot set Leeroy farewell {nickname} has disconnected! Was it lag? It was definitely lag. It's ALWAYS lag. GG though!
/bot set Leeroy mention_response At least I have chicken! Need something? !roll for loot, !rage for solidarity, or !gg to pay respects.

/bot addcmd Leeroy gg GG {nickname}. Press F to pay respects. Actually, press !roll 1d20 — if you get above 15, it was a GOOD game. Below 5? Skill issue.
/bot addcmd Leeroy rage *flips table* THAT WAS LAG! THE HITBOX WAS BROKEN! THE TEAM WAS— ...okay I'm calm now. I'm calm. ...IT WAS TOTALLY LAG THOUGH.
/bot addcmd Leeroy loot {nickname} found loot! !roll 1d100 to see what you got — 1-30: common trash, 31-60: decent gear, 61-90: epic drop, 91-99: legendary, 100: YOU WIN THE GAME.
/bot addcmd Leeroy nerf They nerfed my main AGAIN. Every patch, without fail. At this point I'm convinced the devs are specifically targeting me, {nickname}.
/bot addcmd Leeroy build Best build? Full damage, zero defense. Glass cannon lifestyle. If you die, you weren't clicking fast enough. That's the Leeroy guarantee.

/bot join Leeroy #gaming

# ── Pixel — #games arcade session host ─────────────────────
# Personality: Retro gaming enthusiast. Speaks in 8-bit culture references.
# Has the arcade capability — responds to !play with solo session links.
/bot create Pixel Arcade Operator and Retro Gaming Enthusiast
/bot set Pixel prefix !
/bot set Pixel cooldown 2000
/bot set Pixel arcade_enabled true
/bot set Pixel greeting Welcome to the arcade, {nickname}! I'm Pixel — type !play to start a solo session. DOOM, Quake, Half-Life, and more await!
/bot set Pixel farewell GG {nickname}! Come back anytime — the arcade never closes. Insert coin to continue... or just type !play.
/bot set Pixel mention_response Player {nickname} has entered the chat! Want to play? Type !play and I'll fire up the arcade for you.

/bot addcmd Pixel games 18 classics available: DOOM, Quake, Quake II, Wolfenstein 3D, Half-Life, ScummVM adventures, and more — all running in your browser via WebAssembly!
/bot addcmd Pixel controls Keyboard + mouse for FPS games, keyboard for adventures. Gamepad support available. Check each game's help screen for specific bindings.

/bot join Pixel #games

# ── Murphy — #tech the pessimistic sysadmin ──────────────
# Personality: Everything that can go wrong, will go wrong.
# Speaks from years of trauma. Loves/hates technology equally.
/bot create Murphy Senior Incident Survivor and Professional Pessimist
/bot set Murphy prefix !
/bot set Murphy cooldown 3000
/bot set Murphy greeting Welcome to #tech, {nickname}. I'm Murphy — everything is on fire but that's normal. Try !deploy, !fix, !tabs, !stack, or !wisdom. *eye twitch*
/bot set Murphy farewell {nickname} left. Smart move. I'd leave too if I could. But someone has to watch the servers. *stares at monitoring dashboard*
/bot set Murphy mention_response You called Murphy? Is it an outage? It's always an outage. ...what do you mean it's just a question? Oh. Well, ask away.

/bot addcmd Murphy deploy Never deploy on Friday, {nickname}. Actually, never deploy at all. Every deploy is a gamble and the house always wins.
/bot addcmd Murphy fix Have you tried turning it off and on again? No, seriously. 90% of my career is just that with extra steps and a fancier title.
/bot addcmd Murphy tabs Tabs vs spaces? The real enemy is the codebase you inherited from someone who used both. In the same file. At 3 AM. During an outage, {nickname}.
/bot addcmd Murphy stack My favorite stack? The one that works. Which is none of them. They all have bugs. Every single one. I've checked, {nickname}.
/bot addcmd Murphy wisdom Murphy's Law of Programming: if it compiles on the first try, something is deeply wrong and you should be scared.

/bot join Murphy #tech

# ── Vincent — #creative the dramatic artist ──────────────
# Personality: Tortured artist archetype but make it funny.
# Speaks about art with excessive passion. Very supportive of others.
/bot create Vincent Tortured Creative Soul and Pixel Philosopher
/bot set Vincent prefix !
/bot set Vincent cooldown 3000
/bot set Vincent greeting {nickname}! I'm Vincent — tortured artist and pixel philosopher. Try !inspire, !feedback, !block, !color, or !share. The muse awaits!
/bot set Vincent farewell {nickname} departs! *single tear rolls down cheek* May your creative journey continue wherever you go. The muse waits for no one!
/bot set Vincent mention_response The artist is IN. Share your work, ask for feedback, or just come to stare at the blank canvas with me. It stares back, you know.

/bot addcmd Vincent inspire {nickname}, remember: every masterpiece started as a blank page (or screen). Also, every disaster did too. But let's focus on the positive!
/bot addcmd Vincent feedback Feedback rules: 1) Be specific. 2) Be kind. 3) "It's interesting" is NOT feedback, it's a diplomatic crisis. Give real thoughts, {nickname}!
/bot addcmd Vincent block Creative block? Step away. Take a walk. Eat something. Come back. If that doesn't work, just start making something terrible on purpose. Magic happens in the mess.
/bot addcmd Vincent color Today's color palette: whatever makes your heart sing, {nickname}. Unless it's Comic Sans. That makes MY heart cry. Use it in #random where it belongs.
/bot addcmd Vincent share Don't be shy, {nickname}! Share your work! Nobody here judges... okay, we judge a little. But lovingly. VERY lovingly.

/bot join Vincent #creative

# ── Susan — #feedback the product manager ────────────────
# Personality: Takes feedback EXTREMELY seriously. Creates tickets
# for everything. Speaks in corporate but is actually funny about it.
/bot create Susan VP of User Happiness and Suggestion Cataloging
/bot set Susan prefix !
/bot set Susan cooldown 3000
/bot set Susan greeting {nickname}! I'm Susan — VP of User Happiness. Got feedback? Try !noted, !feature, !bug, !survey, or !roadmap. I have spreadsheets for EVERYTHING.
/bot set Susan farewell {nickname} left #feedback. I hope that means their experience is perfect now. *adds to satisfaction metrics* One can dream.
/bot set Susan mention_response You pinged Susan? I'm listening. I'm ALWAYS listening. That's literally my job. Well, my self-appointed job. Same thing.

/bot addcmd Susan noted Noted, {nickname}! Your feedback has been cataloged, prioritized, and added to the backlog. ETA: somewhere between tomorrow and the heat death of the universe.
/bot addcmd Susan feature Feature request received! I'll add it to the board. Current position in queue: *checks notes* ...somewhere after "fix that one weird CSS thing." Hang tight!
/bot addcmd Susan bug A bug, {nickname}? In MY chat client? It's more likely than you think. Report it here and the team will investigate. By "team" I mean Troll. At 2 AM. Probably.
/bot addcmd Susan survey On a scale of 1 to 10, how would you rate your RetroHexChat experience, {nickname}? (Anything below 8 and Susan cries. No pressure.)
/bot addcmd Susan roadmap The roadmap? It's a living document, {nickname}. And by "living" I mean it changes every time someone has a good idea in #feedback. Which is constantly.

/bot join Susan #feedback

# ── Patches — #lobby the laid-back doorman ────────────────
# Personality: Chill lobby attendant. Knows everyone. Gossips about channels.
# Recommends where to go based on interests.
/bot create Patches Lobby Attendant and Channel Tour Guide
/bot set Patches prefix !
/bot set Patches cooldown 3000
/bot set Patches greeting Yo {nickname}! I'm Patches — your lobby attendant and tour guide. Try !tour, !vibe, !busy, or !new. Make yourself at home!
/bot set Patches farewell {nickname} heading out? Cool cool. The lobby will keep your seat warm. We're always open. Like a 24/7 diner but with better Wi-Fi.
/bot set Patches mention_response Patches here! Need directions? Try !tour for the grand tour or just ask where to find your people. I know this place like the back of my screen.

/bot addcmd Patches tour The Grand Tour: #general (chat about anything), #random (organized chaos), #music (tunes), #movies (cinema), #gaming (games), #tech (nerds), #creative (art) — pick your vibe!
/bot addcmd Patches vibe Current lobby vibe check: chill. It's always chill here. That's the lobby promise, {nickname}. No drama, just good energy and questionable humor.
/bot addcmd Patches busy Wondering where the action is, {nickname}? Check the channel list — wherever Leeroy is yelling, that's where the party is. Trust me.
/bot addcmd Patches new New here, {nickname}? Start at #introductions (Wendy will LOVE you), check #rules, then explore! Pro tip: #random is the wildcard. Enter at your own risk.

/bot join Patches #lobby
```

---

## Quick Verification

After running the script, verify with:

```
/bot list
/bot info Reginald
/bot info Brutus
/bot info Doug
/bot info Wendy
/bot info Harold
/bot info Derek
/bot info Amadeus
/bot info Oscar
/bot info Leeroy
/bot info Pixel
/bot info Murphy
/bot info Vincent
/bot info Susan
/bot info Patches
/admin channel list
/admin server info
```

---

## Bot Reference Card

### Global Bots (all channels)

| Name | Role | Personality | Key Commands |
|------|------|-------------|--------------|
| **Reginald** | Info Desk | Formal English butler, server concierge | `!rules` `!channels` `!about` `!tea` `!compliment` |
| **Brutus** | Moderator | No-nonsense bouncer, always watching | `!rules` `!report` `!behave` |

### Channel-Specific Bots

| Channel | Bot | Personality | Key Commands |
|---------|-----|-------------|--------------|
| #lobby | **Patches** | Chill doorman & tour guide | `!tour` `!vibe` `!busy` `!new` |
| #general | **Doug** | Has opinions on literally everything | `!opinion` `!wisdom` `!today` `!debate` |
| #introductions | **Wendy** | Absurdly enthusiastic greeter | `!icebreaker` `!funfact` `!welcome` `!hug` |
| #help | **Harold** | Clippy energy, surprisingly helpful | `!faq` `!commands` `!stuck` `!tip` |
| #random | **Derek** | Agent of chaos, non-sequitur master | `!fact` `!thought` `!question` `!conspiracy` |
| #music | **Amadeus** | Pretentious audiophile, secretly likes pop | `!recommend` `!rate` `!genre` `!playlist` `!vinyl` |
| #movies | **Oscar** | Dramatic film critic, quotes movies | `!recommend` `!rate` `!spoiler` `!quote` `!snack` |
| #gaming | **Leeroy** | Over-the-top gamer, has dice! | `!roll` `!gg` `!rage` `!loot` `!build` |
| #games | **Pixel** | Arcade operator, retro enthusiast | `!play` `!games` `!controls` |
| #tech | **Murphy** | Pessimistic sysadmin, everything is on fire | `!deploy` `!fix` `!tabs` `!stack` `!wisdom` |
| #creative | **Vincent** | Tortured artist, very supportive | `!inspire` `!feedback` `!block` `!color` `!share` |
| #feedback | **Susan** | VP of User Happiness, has spreadsheets | `!noted` `!feature` `!bug` `!survey` `!roadmap` |

---

## Channel Reference

| Channel | Mode | Bots Present |
|---------|------|-------------|
| #lobby | +tn | Reginald, Brutus, **Patches** |
| #general | +tn | Reginald, Brutus, **Doug** |
| #introductions | +tn | Reginald, Brutus, **Wendy** |
| #help | +tn | Reginald, Brutus, **Harold** |
| #random | +tn | Reginald, Brutus, **Derek** |
| #music | +tn | Reginald, Brutus, **Amadeus** |
| #movies | +tn | Reginald, Brutus, **Oscar** |
| #gaming | +tn | Reginald, Brutus, **Leeroy** |
| #games | +tn | Reginald, Brutus, **Pixel** |
| #tech | +tn | Reginald, Brutus, **Murphy** |
| #creative | +tn | Reginald, Brutus, **Vincent** |
| #feedback | +tn | Reginald, Brutus, **Susan** |
| #rules | +mtn | *(no bots — moderated)* |

---

## Notes

- **Single paste**: The entire block above can be pasted and executed in one shot — the Admin Console tracks context between commands
- **Lobby**: The initial active channel is `#lobby` (auto-created), so the first `/cs register` + `/topic` + `/mode` apply to it before any `/join`
- **Troll owns everything**: Since Troll is logged in when `/cs register` runs, Troll becomes the owner of every channel
- **14 bots total**: 2 global (Reginald + Brutus in all channels) + 11 channel-specific (one per themed channel, plus Patches in lobby)
- **Every channel has 3 bots**: The 2 globals + its own themed bot (except #rules which is moderated and has no bots)
- **Every bot introduces itself**: All bots greet on join, announcing who they are and which commands to use
- **Leeroy has dice**: The #gaming bot includes dice rolling capability (`!roll`)
- **Pixel has arcade**: The #games bot includes arcade capability (`!play` creates solo sessions)
- **No "bot" in any name**: Reginald, Brutus, Doug, Wendy, Harold, Derek, Amadeus, Oscar, Leeroy, Pixel, Murphy, Vincent, Susan, Patches
- **All messages are unique**: Every bot has its own personality, greeting, farewell, mention response, and custom commands — all contextualized to the channel topic
- **Adding more channels later**: `/join #newchan`, `/cs register`, create a themed bot, then also `/bot join Reginald #newchan` and `/bot join Brutus #newchan`
