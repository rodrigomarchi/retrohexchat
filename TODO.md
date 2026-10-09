# TODO

Places where the app contradicts itself, found while scripting EP02 (`retro_hex_chat_videos`,
`episodes/02-how-irc-works`). Delete this file once every item is fixed.

- [ ] **Nickname case is a policy the app does not hold to.** Registration is case sensitive
      ("Alice" and "alice" are two registrations; `registered_nicks.nickname` has a plain unique
      index), but a nickname in use is matched without case (`command_dispatch.ex`,
      `core_events.ex`), and the connect window and the NickServ banner say "case sensitive".
      Needs a decision: one rule for both, then the texts follow it.
