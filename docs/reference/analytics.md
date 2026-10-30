# Google Analytics

The site reports to GA4 when `GA_MEASUREMENT_ID` is set (infra `deployex_apps`
env; off when empty, and always off on localhost). The id reaches the browser
through `Layouts.head_meta/1`, so only the `desktop` and `surface` layouts are
measured; the showcase and error pages are not.

- **Page views:** GA4's enhanced measurement, "page changes based on browser
  history events". LiveView navigates with `pushState`, so there is no code for
  it here. That setting must stay on.
- **Everything else:** `RetroHexChatWeb.Analytics.track/4` from the server,
  received by `assets/js/lib/analytics/google_analytics.js`.

To report something new, add its name to `@events` and call `track/4` where the
fact happens. A parameter only appears in GA reports once it is registered as a
custom dimension in the property. Use `across_navigation: true` when the browser
is about to leave the page, as a form POST or a redirect would drop the hit.

A command is reported by name alone: its arguments can hold a password.

| Stage | Events | Parameters |
|---|---|---|
| Visitor | `channel_watch`, `signup_prompt` | `channel`; `feature` |
| Sign-up | `signup_start`, `signup_error`, `sign_up` | `reason`; `method` |
| Login | `login_start`, `login`, `logout` | `method` |
| Chat | `channel_view`, `channel_join`, `pm_open`, `message_send`, `command_use` | `channel`, `mode`, `private`, `command` |
| Play | `game_start`, `game_end`, `arcade_start` | `game`, `seconds` |
| Together | `call_join`, `space_enter`, `p2p_start`, `share` | `channel`, `space`, `role`, `content_type` |
| Desktop | `window_open`, `tool_open` | `window`, `tool` |

Who is visiting travels as the `user_id` (the account id) and the `member` user
property, set by `Analytics.identify/2`.
