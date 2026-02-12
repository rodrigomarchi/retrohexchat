# LiveView Events Contract: Log Viewer

## ChatLive Event Handlers

### Dialog Open/Close

| Event | Params | Action |
|-------|--------|--------|
| `open_log_viewer` | `%{}` | Open dialog, populate channel/PM dropdown, show empty state |
| `close_log_viewer` | `%{}` | Close dialog, reset all log viewer assigns |
| `window_keydown` (Escape) | `%{"key" => "Escape"}` | Close log viewer if open (existing handler extended) |
| `window_keydown` (Alt+L) | `%{"key" => "l", "altKey" => true}` | Toggle log viewer |

### Filter & Search

| Event | Params | Action |
|-------|--------|--------|
| `log_set_source` | `%{"source" => string, "source_type" => "channel"\|"pm"}` | Set channel/PM filter, trigger search |
| `log_set_date_from` | `%{"date" => "YYYY-MM-DD"}` | Set start date, validate, trigger search |
| `log_set_date_to` | `%{"date" => "YYYY-MM-DD"}` | Set end date, validate, trigger search |
| `log_search` | `%{"nickname" => string, "text" => string}` | Set nickname+text filter, trigger search from page 1 |
| `log_page` | `%{"page" => "2"}` | Navigate to specific page |
| `log_refresh` | `%{}` | Re-run current filter query |

### Display Preferences

| Event | Params | Action |
|-------|--------|--------|
| `log_toggle_event` | `%{"event_type" => "show_joins"\|...}` | Toggle event visibility, refresh display |
| `log_set_timestamp_format` | `%{"format" => "hh_mm"\|"hh_mm_ss"\|"dd_mm_hh_mm"}` | Set timestamp format, refresh display |

### Export

| Event | Params | Action |
|-------|--------|--------|
| `log_export` | `%{"format" => "txt"\|"html"}` | Generate export content, push download event |

### Push Events (Server → Client)

| Event | Payload | JS Handler |
|-------|---------|------------|
| `download_file` | `%{content: base64_string, filename: string, mime_type: string}` | DownloadHook: create Blob, trigger download |

## Socket Assigns (Log Viewer State)

```elixir
# Dialog visibility
show_log_viewer: false

# Filter state
log_filter: %LogFilter{}           # Current filter criteria
log_source_options: []              # [{label, value}] for channel/PM dropdown

# Results
log_page: nil                       # %LogPage{} or nil when no search performed
log_loading: false                  # Loading indicator

# Display preferences
log_preferences: %DisplayPreferences{}  # Event toggles + timestamp format

# Export state
log_exporting: false                # Export progress indicator

# Validation
log_error: nil                      # Validation error message (e.g., future date)
```

## LogViewerDialog Component Attrs

```elixir
attr :visible, :boolean, default: false
attr :filter, :map, default: nil              # %LogFilter{}
attr :page, :map, default: nil                # %LogPage{}
attr :preferences, :map, default: nil         # %DisplayPreferences{}
attr :source_options, :list, default: []      # [{label, value}]
attr :loading, :boolean, default: false
attr :exporting, :boolean, default: false
attr :error, :string, default: nil
```
