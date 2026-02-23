# RetroHexChat — Server Provisioning Script

Paste the **entire block below** into the **Admin Console** and click **Execute**.

> **Prerequisite**: Start the server with `ROOT_ADMINS=Troll mix phx.server`.
> Login as Troll, `/identify`, open Admin Console from toolbar.

---

## Full Script (paste everything below into Admin Console)

```
# ── 1. Server Settings ───────────────────────────────────
/admin server set server_name RetroHexChat
/admin server set server_description A retro community chat — welcome home.
/admin server set welcome_message Welcome to RetroHexChat! Type /help to get started.
/admin server set registration open

# ── 2. Core Channels ─────────────────────────────────────

# Main lobby (auto-created, just register + configure)
/cs register
/topic Welcome to #lobby — the main hangout. Be cool.
/mode +tn

# General chat
/join #general
/cs register
/topic General discussion — anything goes (within reason).
/mode +tn

# Introductions
/join #introductions
/cs register
/topic New here? Say hi and tell us about yourself!
/mode +tn

# Help & support
/join #help
/cs register
/topic Need help? Ask away. Check /help for commands.
/mode +tn

# Off-topic / random
/join #random
/cs register
/topic Off-topic — memes, links, whatever.
/mode +tn

# Music
/join #music
/cs register
/topic Share what you're listening to.
/mode +tn

# Movies & TV
/join #movies
/cs register
/topic Movies, TV shows, anime — no spoilers without warning!
/mode +tn

# Gaming
/join #gaming
/cs register
/topic PC, console, retro — all gaming welcome.
/mode +tn

# Tech & programming
/join #tech
/cs register
/topic Programming, hardware, software, sysadmin.
/mode +tn

# Creative / art / design
/join #creative
/cs register
/topic Art, design, photography, writing — share your work.
/mode +tn

# Feedback & suggestions
/join #feedback
/cs register
/topic Ideas and suggestions for RetroHexChat.
/mode +tn

# Rules / read-only info channel
/join #rules
/cs register
/topic Server rules — read before chatting. Moderated channel.
/mode +mtn

# ── 3. Create Bots ───────────────────────────────────────

# GreeterBot — welcomes users, provides basic help
/bot create GreeterBot Welcomes new users and provides server info
/bot set GreeterBot prefix !
/bot set GreeterBot cooldown 2000
/bot set GreeterBot greeting Welcome to RetroHexChat, {nickname}! Type !help for commands or visit #help.
/bot set GreeterBot farewell See you later, {nickname}!
/bot set GreeterBot mention_response Hey! Need help? Try !rules or !channels.

# ModBot — moderation across all channels
/bot create ModBot Moderation bot — keeps things clean
/bot set ModBot prefix !
/bot set ModBot cooldown 1000
/bot set ModBot mod_action warn
/bot set ModBot mod_spam 5
/bot set ModBot mod_flood 8
/bot set ModBot mod_warn Please keep it friendly. Repeated violations may result in a mute.
/bot set ModBot mention_response I'm the moderation bot. Behave and we'll get along fine.

# DiceBot — dice rolling and fun
/bot create DiceBot Roll dice for games and decisions
/bot set DiceBot prefix !
/bot set DiceBot cooldown 1000
/bot set DiceBot dice_max_dice 50
/bot set DiceBot dice_max_sides 1000
/bot set DiceBot dice_default 1d20
/bot set DiceBot mention_response Try !roll 2d6 or !roll 1d20 to roll dice!

# TriviaBot — trivia games
/bot create TriviaBot Trivia game bot — test your knowledge
/bot set TriviaBot prefix !
/bot set TriviaBot cooldown 1000
/bot set TriviaBot trivia_time 30
/bot set TriviaBot trivia_questions 10
/bot set TriviaBot trivia_points 10
/bot set TriviaBot mention_response Want to play? Try !trivia start in a channel!

# ── 4. Custom Bot Commands ───────────────────────────────

# GreeterBot commands
/bot addcmd GreeterBot rules Check out #rules for the full server rules.
/bot addcmd GreeterBot channels Our channels: #general #help #random #music #movies #gaming #tech #creative #feedback
/bot addcmd GreeterBot website Visit us at https://retrohexchat.com
/bot addcmd GreeterBot about RetroHexChat is a retro-styled community chat. Built with Elixir + Phoenix LiveView.
/bot addcmd GreeterBot commands Available: !rules !channels !website !about !help

# DiceBot commands
/bot addcmd DiceBot coinflip The coin lands on... heads! (just kidding, try !roll 1d2 — 1=heads, 2=tails)
/bot addcmd DiceBot d20 Rolling a d20 for you... use !roll 1d20

# TriviaBot commands
/bot addcmd TriviaBot scores Check the scoreboard after a trivia round with !trivia scores

# ── 5. Deploy Bots to Channels ───────────────────────────

# GreeterBot — all main channels
/bot join GreeterBot #lobby
/bot join GreeterBot #general
/bot join GreeterBot #introductions
/bot join GreeterBot #help
/bot join GreeterBot #random

# ModBot — all public channels
/bot join ModBot #lobby
/bot join ModBot #general
/bot join ModBot #introductions
/bot join ModBot #help
/bot join ModBot #random
/bot join ModBot #music
/bot join ModBot #movies
/bot join ModBot #gaming
/bot join ModBot #tech
/bot join ModBot #creative
/bot join ModBot #feedback

# DiceBot — gaming + random
/bot join DiceBot #gaming
/bot join DiceBot #random

# TriviaBot — gaming + random + general
/bot join TriviaBot #gaming
/bot join TriviaBot #random
/bot join TriviaBot #general
```

---

## Quick Verification

After running the script, verify with:

```
/bot list
/admin channel list
/admin server info
```

---

## Notes

- **Single paste**: The entire block above can be pasted and executed in one shot — the Admin Console tracks context between commands (e.g. `/join` updates the active channel for subsequent `/cs register`, `/topic`, `/mode`)
- **Lobby**: The initial active channel is `#lobby` (auto-created), so the first `/cs register` + `/topic` + `/mode` apply to it before any `/join`
- **Bot capabilities**: Bots are created with core capabilities enabled by default. Dice/moderation/trivia are enabled when you configure their settings
- **Adding more channels later**: `/join #newchan`, `/cs register`, then `/bot join BotName #newchan`
