defmodule RetroHexChatWeb.ChatLive.Components.SearchBar do
  @moduledoc """
  The in-channel search bar. Owns the search content state: query, filters
  (case/regex/mentions/history), current index, result count (live DOM matches +
  async persisted-history matches) and regex error.

  The parent `ChatLive` keeps `search_visible` because the Escape-dismissal map
  and overlay stacking in `KeyboardEvents` coordinate over parent assigns. This
  component owns everything *inside* the search bar and survives open/close (it
  is always mounted; only its rendered body is gated by `@visible`), which is
  what lets `last_query` persist across reopen.

  It also hosts the `SearchHighlightHook` (an always-mounted hidden element in its
  root): this component emits the `search_highlight` / `search_scroll_to` /
  `search_clear_highlights` push events, and the hook applies them to the
  `#chat-messages` DOM and reports the live match count back.

  `SearchEvents` forwards the search events to this component via `send_update/2`
  with an `:action`. See `dispatch/2` for the action protocol.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.SearchBar
  import RetroHexChatWeb.Components.UI.SearchHighlightAnchor

  alias RetroHexChat.Chat.Search

  @id "chat-search-bar"

  @doc "Stable DOM/component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       visible: false,
       nickname: nil,
       active_channel: nil,
       query: "",
       last_query: "",
       result_count: 0,
       dom_count: 0,
       history_count: 0,
       current_index: 0,
       case_sensitive: false,
       regex: false,
       my_mentions: false,
       history: false,
       error: nil
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: action} = assigns, socket) do
    {:ok, socket |> assign_context(assigns) |> dispatch(action)}
  end

  def update(assigns, socket) do
    {:ok, assign_context(socket, assigns)}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <%!-- Always mounted, even while the bar is hidden: the JS hook owns the DOM
           highlighting/scroll over `#chat-messages` and reports match counts back. --%>
      <.search_highlight_anchor />
      <.search_bar
        :if={@visible}
        query={@query}
        result_count={@result_count}
        current_result={@current_index}
        error={@error}
        case_sensitive={@case_sensitive}
        regex={@regex}
        mentions_only={@my_mentions}
        search_history={@history}
        on_search="search_input"
        on_next="search_next"
        on_prev="search_prev"
        on_navigate="search_navigate"
        on_close="close_search"
        on_toggle_filter="search_toggle_filter"
      />
    </div>
    """
  end

  # -- Context (re-assigned on every parent render) --------------------------

  @spec assign_context(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  defp assign_context(socket, assigns) do
    was_visible = socket.assigns.visible
    now_visible = Map.get(assigns, :visible, was_visible)

    socket =
      assign(socket,
        id: Map.get(assigns, :id, socket.assigns[:id] || @id),
        visible: now_visible,
        nickname: Map.get(assigns, :nickname, socket.assigns.nickname),
        active_channel: Map.get(assigns, :active_channel, socket.assigns.active_channel)
      )

    # Restore the last query in the SAME render the bar becomes visible. The input
    # is value-bound and `phx-mounted`-focused, so restoring it in a later async
    # `:open` action would not patch the (now focused) input — it must be set
    # before the input is first mounted.
    if now_visible and not was_visible do
      assign(socket, query: socket.assigns.last_query)
    else
      socket
    end
  end

  # -- Action protocol (driven by parent `send_update`) ----------------------
  #
  #   :open                       — restore last query, re-highlight if present
  #   :close                      — save last query, clear, drop highlights
  #   {:input, query}             — run search for `query`
  #   :next / :prev               — move highlight cursor, scroll to it
  #   {:navigate, key}            — ArrowDown/ArrowUp -> next/prev, else no-op
  #   {:toggle_filter, filter}    — flip a filter and re-search
  #   {:highlight_count, count, error} — JS hook reports DOM match count

  @spec dispatch(Phoenix.LiveView.Socket.t(), term()) :: Phoenix.LiveView.Socket.t()
  defp dispatch(socket, :open) do
    socket
    |> assign(query: socket.assigns.last_query)
    |> maybe_restore_highlights()
  end

  defp dispatch(socket, :close), do: close_and_save(socket)

  defp dispatch(socket, {:input, query}), do: do_search(socket, query)

  defp dispatch(socket, :next), do: navigate(socket, :next)
  defp dispatch(socket, :prev), do: navigate(socket, :prev)

  defp dispatch(socket, {:navigate, "ArrowDown"}), do: navigate(socket, :next)
  defp dispatch(socket, {:navigate, "ArrowUp"}), do: navigate(socket, :prev)
  defp dispatch(socket, {:navigate, _key}), do: socket

  defp dispatch(socket, {:toggle_filter, filter}), do: toggle_filter(socket, filter)

  defp dispatch(socket, {:highlight_count, count, error}) do
    socket
    |> assign(dom_count: count, error: error)
    |> recount()
  end

  defp dispatch(socket, _unknown), do: socket

  @impl true
  @spec handle_async(term(), term(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_async(:history_count, {:ok, {query, count}}, socket) do
    # Apply only if still relevant: a newer query or a disabled history filter
    # supersedes a slow result (stale-result guard, no socket captured in task).
    socket =
      if socket.assigns.history and socket.assigns.query == query do
        socket |> assign(history_count: count) |> recount()
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_async(:history_count, {:exit, _reason}, socket), do: {:noreply, socket}

  # The displayed total is the larger of the live DOM match count (from the JS
  # hook) and the persisted-history match count (from the async DB lookup).
  @spec recount(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp recount(socket) do
    total = max(socket.assigns.dom_count, socket.assigns.history_count)
    assign(socket, result_count: total, current_index: min(1, total))
  end

  # -- Search core (ported from SearchEvents) --------------------------------

  @spec navigate(Phoenix.LiveView.Socket.t(), :next | :prev) :: Phoenix.LiveView.Socket.t()
  defp navigate(socket, direction) do
    %{current_index: idx, result_count: count} = socket.assigns

    if count > 0 do
      new_index = step_index(direction, idx, count)

      socket
      |> assign(current_index: new_index)
      |> push_event("search_scroll_to", %{index: new_index})
    else
      socket
    end
  end

  @spec step_index(:next | :prev, non_neg_integer(), pos_integer()) :: pos_integer()
  defp step_index(:next, idx, count), do: if(idx >= count, do: 1, else: idx + 1)
  defp step_index(:prev, idx, count), do: if(idx <= 1, do: count, else: idx - 1)

  @spec do_search(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  defp do_search(socket, "") do
    socket
    |> assign(
      query: "",
      result_count: 0,
      dom_count: 0,
      history_count: 0,
      current_index: 0,
      error: nil
    )
    |> push_event("search_clear_highlights", %{})
  end

  defp do_search(socket, query) do
    assigns = socket.assigns
    invalid_regex? = assigns.regex and not Search.valid_regex?(query)

    socket =
      socket
      |> assign(
        query: query,
        result_count: 0,
        dom_count: 0,
        history_count: 0,
        current_index: 0,
        error: if(invalid_regex?, do: invalid_regex_error(), else: nil)
      )
      |> maybe_start_history_search(assigns.active_channel, query, invalid_regex?)

    # DOM highlighting (fast, client-side) fires immediately; the persisted
    # history match count is resolved asynchronously via handle_async.
    push_event(socket, "search_highlight", %{
      query: query,
      case_sensitive: assigns.case_sensitive,
      regex: assigns.regex,
      mention_nick: if(assigns.my_mentions, do: assigns.nickname, else: nil)
    })
  end

  @spec maybe_start_history_search(
          Phoenix.LiveView.Socket.t(),
          String.t() | nil,
          String.t(),
          boolean()
        ) :: Phoenix.LiveView.Socket.t()
  defp maybe_start_history_search(socket, channel, query, false = _invalid_regex?)
       when is_binary(channel) do
    if socket.assigns.history do
      opts = build_search_opts(socket.assigns)

      start_async(socket, :history_count, fn ->
        {query, Search.count_matches(channel, query, opts)}
      end)
    else
      socket
    end
  end

  defp maybe_start_history_search(socket, _channel, _query, _invalid_regex?), do: socket

  @spec close_and_save(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp close_and_save(socket) do
    socket
    |> assign(
      last_query: socket.assigns.query,
      query: "",
      result_count: 0,
      dom_count: 0,
      history_count: 0,
      current_index: 0,
      error: nil
    )
    |> push_event("search_clear_highlights", %{})
  end

  @spec maybe_restore_highlights(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp maybe_restore_highlights(socket) do
    query = socket.assigns.query

    if query != "" do
      do_search(socket, query)
    else
      socket
    end
  end

  @spec toggle_filter(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  defp toggle_filter(socket, "case_sensitive") do
    socket
    |> assign(case_sensitive: !socket.assigns.case_sensitive)
    |> re_search()
  end

  defp toggle_filter(socket, "regex") do
    new_val = !socket.assigns.regex
    socket = assign(socket, regex: new_val)

    socket =
      if new_val and socket.assigns.query != "" do
        validate_and_assign_regex(socket)
      else
        assign(socket, error: nil)
      end

    re_search(socket)
  end

  defp toggle_filter(socket, "my_mentions") do
    socket
    |> assign(my_mentions: !socket.assigns.my_mentions)
    |> re_search()
  end

  defp toggle_filter(socket, "mentions"), do: toggle_filter(socket, "my_mentions")

  defp toggle_filter(socket, "history") do
    socket
    |> assign(history: !socket.assigns.history)
    |> re_search()
  end

  defp toggle_filter(socket, _unknown), do: socket

  @spec re_search(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp re_search(socket) do
    query = socket.assigns.query

    if query != "" and socket.assigns.error == nil do
      do_search(socket, query)
    else
      socket
    end
  end

  @spec validate_and_assign_regex(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp validate_and_assign_regex(socket) do
    if Search.valid_regex?(socket.assigns.query) do
      assign(socket, error: nil)
    else
      assign(socket, error: invalid_regex_error())
    end
  end

  @spec build_search_opts(map()) :: keyword()
  defp build_search_opts(assigns) do
    opts = [case_sensitive: assigns.case_sensitive, regex: assigns.regex]

    if assigns.my_mentions do
      Keyword.put(opts, :mention_nick, assigns.nickname)
    else
      opts
    end
  end

  @spec invalid_regex_error() :: String.t()
  defp invalid_regex_error, do: dgettext("chat", "Invalid regex")
end
