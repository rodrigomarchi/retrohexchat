# Contract: Chat.LinkPreview

**Module**: `RetroHexChat.Chat.LinkPreview`
**Layer**: Domain (`retro_hex_chat`)
**Dependencies**: `Req` (HTTP client), ETS (cache)

## Behaviour

```elixir
@callback fetch_title(String.t()) :: {:ok, String.t()} | {:error, atom()}
```

### Implementations

- `Chat.LinkPreview.HTTP` — Production implementation using Req
- Test mock via Mox (`Chat.LinkPreviewMock`)

## Public API

### `fetch_title/1`

Fetches the page title from a URL.

```elixir
@spec fetch_title(String.t()) :: {:ok, String.t()} | {:error, atom()}
```

**Input**: Full URL string (must start with `http://` or `https://`).
**Output**: `{:ok, title}` where title is an HTML-escaped plain text string, or `{:error, reason}`.

**Behavior**:
- HTTP GET with 5-second timeout
- Follows up to 3 redirects
- Parses `<title>` tag from HTML response
- HTML-escapes the extracted title (prevents XSS)
- Strips leading/trailing whitespace from title
- Truncates title to 200 characters
- Returns `{:error, :timeout}` on timeout
- Returns `{:error, :not_found}` on 4xx responses
- Returns `{:error, :server_error}` on 5xx responses
- Returns `{:error, :no_title}` if page has no `<title>` tag
- Returns `{:error, :not_html}` if response content-type is not HTML
- Only reads first 50KB of response body (avoids downloading large files)

## Cache API

### `Chat.LinkPreview.Cache`

ETS-based cache for fetched titles. Started as a named GenServer in the supervision tree.

```elixir
@spec get(String.t()) :: {:ok, String.t() | nil} | :miss
@spec put(String.t(), String.t() | nil) :: :ok
@spec pending?(String.t()) :: boolean()
@spec mark_pending(String.t()) :: :ok
```

**Behavior**:
- `get/1`: Returns `{:ok, title}` if cached and not expired, `:miss` otherwise
- `put/2`: Stores title with current timestamp, clears pending flag
- `pending?/1`: Returns true if a fetch is in progress for this URL
- `mark_pending/1`: Marks URL as being fetched (prevents duplicate fetches)
- TTL: 1 hour
- Error results are cached for 5 minutes (prevents hammering unreachable URLs)
