# TODO

Places where the app contradicts itself, found while scripting EP02 (`retro_hex_chat_videos`,
`episodes/02-how-irc-works`). The code is what the episode shows; delete this file once every
item is fixed.

- [ ] **ChanServ connect banner gives the wrong syntax.** The Status text says
      `/cs sop #channel add <nick>` and `/cs info #channel`; `/cs` acts on the current channel and
      takes `/cs sop add <nick>` — the advertised form is a usage error
      (`retro_hex_chat_web/live/app/chat_live.ex` `show_chanserv_announcement`,
      `retro_hex_chat/commands/handlers/cs.ex`).
- [ ] **`/cs register` help says it needs an operator; the code does not check.**
      (`chan_serv.ex` only requires being identified.)
- [ ] **+t help says half-operators can change a locked topic; the code requires operator.**
      Help topic `mode-t` vs `Channels.Policy.can_change_topic?/3`.
- [ ] **The ban dialog labels its field "Hostmask"; masks match the nickname only.**
      `Channels.Masks` compares the part before `!`; there is no user or host.
- [ ] **`/autorespond` help example uses `/say`, which does not exist.**
- [ ] **NickServ banner says nicknames are case sensitive; the in-use check ignores case.**
      (`command_dispatch.ex`, `core_events.ex`.)
- [ ] **+R error says "registered"; the check is "identified".**
- [ ] **`cmd-join` help says the first joiner becomes "its first operator"; they become owner.**
      The `channels` topic and `Channels.Server.determine_join_role/2` agree on owner.
- [ ] **`mode-p` help says +p hides the channel from /whois; only +s does.**
      `Channels.Visibility.channels_of/2` drops secret channels only; +p changes the Channel List
      row to "Prv" (proven by e2e H8c/H8d).
- [ ] **`/me` is refused in a private chat ("You are not in any channel").** The `/mirc-commands`
      table tells mIRC users to replace `/describe` with `/me` in the private conversation, and
      `Helpers.PM.handle_action_message/3` exists for it, but `Commands.Handlers.Me` rejects any
      context without an active channel first.
