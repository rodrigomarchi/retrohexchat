# Contracts: Sound Settings

**Feature**: 014-sounds-notifications

## Domain Module: `RetroHexChat.Chat.SoundSettings`

### Behaviourless API (follows existing settings pattern)

```elixir
# In-memory CRUD
@spec new() :: map()
@spec get_sound(map(), atom()) :: String.t()
@spec set_sound(map(), atom(), String.t()) :: map()
@spec get_flash(map(), atom()) :: boolean()
@spec set_flash(map(), atom(), boolean()) :: map()
@spec get_sound_mappings(map()) :: map()
@spec get_flash_settings(map()) :: map()

# Persistence (registered users only)
@spec save(String.t(), map()) :: :ok | {:error, term()}
@spec load(String.t()) :: {:ok, map()} | {:error, :not_found}

# Catalog
@spec available_sounds() :: [{String.t(), String.t()}]  # [{name, label}, ...]
@spec event_types() :: [atom()]  # [:message, :pm, :highlight, ...]
@spec valid_sound?(String.t()) :: boolean()
```

### Event Types (atoms)

```elixir
[:message, :pm, :highlight, :join, :part, :kick,
 :connect, :disconnect, :buddy_online, :buddy_offline]
```

### Sound Catalog (name → label)

```elixir
[
  {"none", "None"},
  {"beep", "Beep"},
  {"ding_low", "Ding Low"},
  {"ding_high", "Ding High"},
  {"chime_short", "Chime Short"},
  {"chime_long", "Chime Long"},
  {"chime_high", "Chime High"},
  {"chime_low", "Chime Low"},
  {"alert", "Alert"},
  {"buzz", "Buzz"},
  {"click", "Click"},
  {"ring", "Ring"},
  {"notify", "Notify"},
  {"blip", "Blip"},
  {"whoosh", "Whoosh"}
]
```

## Ecto Schema: `RetroHexChat.Chat.Schemas.SoundSetting`

```elixir
@primary_key {:owner_nickname, :string, autogenerate: false}
schema "sound_settings" do
  field :sound_mappings, :map, default: %{}
  field :flash_settings, :map, default: %{}
  timestamps(type: :utc_datetime_usec)
end
```

## Session Integration

```elixir
# Session struct field
sound_settings: map()  # SoundSettings.new() default

# Getter/Setter
@spec get_sound_settings(t()) :: map()
@spec set_sound_settings(t(), map()) :: t()
```

## LiveView Events

### Dialog Events (chat_live.ex)

| Event | Direction | Params | Description |
|-------|-----------|--------|-------------|
| `open_sound_settings_dialog` | User → Server | — | Opens dialog, initializes draft |
| `close_sound_settings_dialog` | User → Server | — | Closes dialog, discards draft |
| `sound_settings_change` | User → Server | `%{"event_type" => ..., "sound" => ...}` | Updates draft sound mapping |
| `sound_flash_toggle` | User → Server | `%{"event_type" => ..., "enabled" => ...}` | Toggles flash in draft |
| `sound_settings_apply` | User → Server | — | Commits draft to session + DB |
| `sound_settings_ok` | User → Server | — | Commits draft + closes dialog |
| `sound_preview` | User → Server | `%{"sound" => "ding_low"}` | Plays preview sound |

### Sound Playback Events (push_event to JS)

| Event | Direction | Payload | Description |
|-------|-----------|---------|-------------|
| `play_sound` | Server → Client | `%{type: "ding_low"}` | Play a specific named sound |
| `toggle_mute` | Server → Client | — | Toggle mute state (existing) |

### Typing Indicator Events

| Event | Direction | Params | Description |
|-------|-----------|--------|-------------|
| `pm_typing` | Client → Server | — | User is typing in PM input |
| `pm_stop_typing` | Client → Server | — | User sent message / stopped |

### PubSub Messages

| Topic | Event | Payload | Description |
|-------|-------|---------|-------------|
| `pm:#{sorted_nicks}` | `"typing"` | `%{nickname: "Alice"}` | Typing indicator broadcast |
| `pm:#{sorted_nicks}` | `"stop_typing"` | `%{nickname: "Alice"}` | Stop typing broadcast |

### Title Flash Events (push_event to JS)

| Event | Direction | Payload | Description |
|-------|-----------|---------|-------------|
| `title_flash_start` | Server → Client | `%{message: "* New activity"}` | Start title bar alternation |
| `title_flash_stop` | Server → Client | — | Stop title bar alternation |
