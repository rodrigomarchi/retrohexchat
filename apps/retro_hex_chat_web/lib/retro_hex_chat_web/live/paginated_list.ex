defmodule RetroHexChatWeb.PaginatedList do
  @moduledoc """
  Wires `RetroHexChatWeb.PaginatedList.State` to a LiveComponent's stream.

  An island declares each of its lists in `mount/1` and then only ever speaks in
  whole pages:

      def mount(socket) do
        {:ok, PaginatedList.init(socket, :events, page_size: 50)}
      end

      def handle_event("load_more", _params, socket) do
        {:noreply, PaginatedList.load(socket, :events, &Bots.list_event_logs(bot_id, &1))}
      end

  The pagination state lives here, in the island — not in the parent LiveView.
  With one paginated list that distinction did not matter; with fourteen it is
  what keeps `load_more` from being routed through the root LiveView's event
  hooks fourteen times.

  ## Deltas

    * `reset/4`   — first page, or a context change (channel switch, new filter)
    * `append/3`  — a page after the current one (bottom-edge lists)
    * `prepend/3` — a page before the current one (top-edge lists, e.g. chat)

  `prepend/3` takes items in **display order** (oldest first) and inserts them
  above the existing rows, matching how the domain hands back a chronological
  page of older rows.

  The DOM is capped at `State.dom_limit/1` rows, so scrolling a long way back
  cannot grow the page without bound.
  """

  require Logger

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [stream: 4, stream_insert: 4]

  alias RetroHexChat.Page
  alias RetroHexChatWeb.PaginatedList.State

  @assign :paginated

  @doc """
  Declares a paginated list on this socket and initialises its stream.

  Accepts the `State` options (`:page_size`) plus any option `stream/4` takes,
  such as `:dom_id`.
  """
  @spec init(Phoenix.LiveView.Socket.t(), atom(), keyword()) :: Phoenix.LiveView.Socket.t()
  def init(socket, name, opts \\ []) do
    {state_opts, stream_opts} = Keyword.split(opts, [:page_size])
    state = State.new(state_opts)

    socket
    |> put_state(name, state)
    |> stream(name, [], Keyword.put(stream_opts, :limit, -State.dom_limit(state)))
  end

  @doc "The pagination state of one list."
  @spec state(Phoenix.LiveView.Socket.t(), atom()) :: State.t()
  def state(socket, name), do: Map.fetch!(socket.assigns[@assign], name)

  @doc "Whether another page may be requested right now."
  @spec can_load_more?(Phoenix.LiveView.Socket.t(), atom()) :: boolean()
  def can_load_more?(socket, name), do: socket |> state(name) |> State.can_load_more?()

  @doc "Marks a request in flight, so the UI can show it and the hook stops asking."
  @spec loading(Phoenix.LiveView.Socket.t(), atom()) :: Phoenix.LiveView.Socket.t()
  def loading(socket, name), do: update_state(socket, name, &State.loading/1)

  @doc """
  Fetches and appends the next page, or does nothing if there is nothing to fetch.

  `fetch` receives the query options (`[limit: …, cursor: …]`) and returns a
  `Page`. The guard here is the authoritative one — the hook's `data-has-more`
  is a courtesy that saves a round trip, not a permission check.
  """
  @spec load(Phoenix.LiveView.Socket.t(), atom(), (keyword() -> Page.t())) ::
          Phoenix.LiveView.Socket.t()
  def load(socket, name, fetch) when is_function(fetch, 1) do
    if can_load_more?(socket, name) do
      try do
        page = socket |> state(name) |> State.query_opts() |> fetch.()
        append(socket, name, page)
      rescue
        error ->
          # A page that fails must say so. Left to raise, the LiveView would be
          # torn down and rebuilt showing the first page again, which reads as
          # "there was nothing more" — the one conclusion that must never be
          # reached by accident.
          Logger.warning("Paginated list #{inspect(name)} failed to load: #{inspect(error)}")
          update_state(socket, name, &State.failed/1)
      end
    else
      socket
    end
  end

  @doc "Replaces the whole list with a page — first load, or a context change."
  @spec reset(Phoenix.LiveView.Socket.t(), atom(), Page.t(), keyword()) ::
          Phoenix.LiveView.Socket.t()
  def reset(socket, name, %Page{} = page, opts \\ []) do
    state = socket |> state(name) |> State.reset() |> State.from_page(page)

    socket
    |> put_state(name, state)
    |> stream(name, page.items, stream_opts(state, opts, reset: true))
  end

  @doc "Adds a page after the current rows."
  @spec append(Phoenix.LiveView.Socket.t(), atom(), Page.t()) :: Phoenix.LiveView.Socket.t()
  def append(socket, name, %Page{} = page) do
    socket
    |> update_state(name, &State.from_page(&1, page))
    |> insert_all(name, page.items, at: -1)
  end

  @doc """
  Adds a page before the current rows, preserving their order.

  Items arrive oldest-first; inserting them reversed at position 0 lands them in
  order above what is already there. A prepend must never reset the stream —
  ephemeral rows that are not in the database would vanish.
  """
  @spec prepend(Phoenix.LiveView.Socket.t(), atom(), Page.t()) :: Phoenix.LiveView.Socket.t()
  def prepend(socket, name, %Page{} = page) do
    socket
    |> update_state(name, &State.from_page(&1, page))
    |> insert_all(name, Enum.reverse(page.items), at: 0)
  end

  # ── Internals ────────────────────────────────────────────────────

  @spec insert_all(Phoenix.LiveView.Socket.t(), atom(), [term()], keyword()) ::
          Phoenix.LiveView.Socket.t()
  defp insert_all(socket, name, items, opts) do
    limit = -State.dom_limit(state(socket, name))
    opts = Keyword.put(opts, :limit, limit)

    Enum.reduce(items, socket, &stream_insert(&2, name, &1, opts))
  end

  @spec stream_opts(State.t(), keyword(), keyword()) :: keyword()
  defp stream_opts(state, caller_opts, extra) do
    caller_opts
    |> Keyword.merge(extra)
    |> Keyword.put(:limit, -State.dom_limit(state))
  end

  @spec put_state(Phoenix.LiveView.Socket.t(), atom(), State.t()) :: Phoenix.LiveView.Socket.t()
  defp put_state(socket, name, state) do
    all = Map.put(socket.assigns[@assign] || %{}, name, state)
    assign(socket, @assign, all)
  end

  @spec update_state(Phoenix.LiveView.Socket.t(), atom(), (State.t() -> State.t())) ::
          Phoenix.LiveView.Socket.t()
  defp update_state(socket, name, fun), do: put_state(socket, name, fun.(state(socket, name)))
end
