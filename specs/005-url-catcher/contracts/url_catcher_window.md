# Contract: URLCatcherWindow Component

**Module**: `RetroHexChatWeb.Components.URLCatcherWindow`
**Layer**: Web (`retro_hex_chat_web`)
**Type**: Function component (98.css styled)

## Component Attributes

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `visible` | `boolean()` | Yes | Controls window visibility |
| `entries` | `list(CapturedURL.t())` | Yes | URL entries to display (already filtered/sorted) |
| `sort_column` | `atom()` | Yes | Current sort column (`:url`, `:source`, `:posted_by`, `:timestamp`) |
| `sort_direction` | `:asc \| :desc` | Yes | Current sort direction |
| `filter_channel` | `String.t() \| nil` | Yes | Active channel filter (nil = all channels) |
| `search_query` | `String.t()` | Yes | Current search text |
| `channels` | `list(String.t())` | Yes | List of channel names for filter dropdown |
| `entry_count` | `non_neg_integer()` | Yes | Total entry count (for status bar) |

## Events Emitted

| Event | Params | Description |
|-------|--------|-------------|
| `toggle_url_catcher` | `%{}` | Close button clicked |
| `url_catcher_sort` | `%{"column" => String.t()}` | Column header clicked |
| `url_catcher_filter` | `%{"channel" => String.t()}` | Channel filter changed |
| `url_catcher_search` | `%{"query" => String.t()}` | Search text changed |
| `url_catcher_open` | `%{"url" => String.t()}` | Entry double-clicked |

## Layout

```text
┌─ URL Catcher ──────────────────────────────── [X] ┐
│ Filter: [All Channels ▼] Search: [_________]      │
│                                                     │
│ URL          │ Channel │ Posted By │ Time     ▼    │
│──────────────┼─────────┼───────────┼──────────     │
│ https://e... │ #elixir │ Alice     │ 14:32         │
│ https://g... │ #general│ Bob       │ 14:28         │
│ https://h... │ PM:Carol│ Carol     │ 14:15         │
│              │         │           │                │
│                                                     │
├─────────────────────────────────────────────────────┤
│ 3 URLs captured                                     │
└─────────────────────────────────────────────────────┘
```

## Styling

- Window type: Floating (like NotifyListWindow)
- Position: `position: absolute; bottom: 40px; right: 10px;`
- Size: `width: 500px; height: 350px;`
- Z-index: 150 (same level as NotifyListWindow)
- Table: 98.css table with sortable column headers
- Status bar: Entry count at bottom
- Row hover: Highlighted background
- Double-click: Opens URL in new tab (via JS hook)

## JS Hook

`URLCatcherHook` — Handles double-click on table rows to open URLs.

```javascript
// Listens for dblclick on rows with data-url attribute
// Calls window.open(url, '_blank', 'noopener,noreferrer')
// Also pushes "url_catcher_open" event to server for tracking
```
