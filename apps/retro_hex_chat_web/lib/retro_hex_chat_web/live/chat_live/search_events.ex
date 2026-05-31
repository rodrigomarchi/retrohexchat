defmodule RetroHexChatWeb.ChatLive.SearchEvents do
  @moduledoc """
  Handle events for the in-channel search feature.

  Covers: toggle_search, search_input, search_next, search_prev, close_search,
  search_highlight_count, and search_navigate (arrow key navigation from input).

  Attached as `attach_hook(:search_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Chat.Search

  def handle_event("toggle_search", _params, socket) do
    visible = !socket.assigns.search_visible

    if visible do
      socket =
        socket
        |> assign(search_visible: true, search_query: socket.assigns.search_last_query)
        |> maybe_restore_highlights()

      {:halt, socket}
    else
      {:halt, close_and_save_search(socket)}
    end
  end

  def handle_event("search_input", %{"query" => query}, socket) do
    {:halt, do_search(socket, query)}
  end

  def handle_event("search_next", _params, socket) do
    %{search_current_index: idx, search_result_count: count} = socket.assigns

    if count > 0 do
      new_index = if idx >= count, do: 1, else: idx + 1

      socket =
        socket
        |> assign(search_current_index: new_index)
        |> push_event("search_scroll_to", %{index: new_index})

      {:halt, socket}
    else
      {:halt, socket}
    end
  end

  def handle_event("search_prev", _params, socket) do
    %{search_current_index: idx, search_result_count: count} = socket.assigns

    if count > 0 do
      new_index = if idx <= 1, do: count, else: idx - 1

      socket =
        socket
        |> assign(search_current_index: new_index)
        |> push_event("search_scroll_to", %{index: new_index})

      {:halt, socket}
    else
      {:halt, socket}
    end
  end

  def handle_event("search_navigate", %{"key" => "ArrowDown"}, socket) do
    handle_event("search_next", %{}, socket)
  end

  def handle_event("search_navigate", %{"key" => "ArrowUp"}, socket) do
    handle_event("search_prev", %{}, socket)
  end

  def handle_event("search_navigate", _params, socket) do
    {:halt, socket}
  end

  def handle_event("search_toggle_filter", %{"filter" => filter}, socket) do
    {:halt, toggle_filter(socket, filter)}
  end

  def handle_event("close_search", _params, socket) do
    {:halt, close_and_save_search(socket)}
  end

  def handle_event("search_highlight_count", %{"count" => count} = params, socket) do
    error = params["error"]
    history_count = socket.assigns.search_history_count
    total = if history_count > 0, do: max(count, history_count), else: count

    socket =
      assign(socket,
        search_result_count: total,
        search_current_index: min(1, total),
        search_error: error
      )

    {:halt, socket}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # -- Private helpers -------------------------------------------------------

  defp do_search(socket, "") do
    socket
    |> assign(
      search_query: "",
      search_results: [],
      search_result_count: 0,
      search_history_count: 0,
      search_current_index: 0,
      search_error: nil
    )
    |> push_event("search_clear_highlights", %{})
  end

  defp do_search(socket, query) do
    assigns = socket.assigns
    channel = assigns.session.active_channel
    search_opts = build_search_opts(assigns)
    invalid_regex? = assigns.search_regex and not Search.valid_regex?(query)

    socket =
      if channel do
        {history_count, results} =
          maybe_search_history(channel, query, search_opts, assigns, invalid_regex?)

        assign(socket,
          search_query: query,
          search_results: results,
          search_history_count: history_count,
          search_result_count: 0,
          search_current_index: 0,
          search_error: if(invalid_regex?, do: invalid_regex_error(), else: nil)
        )
      else
        assign(socket,
          search_query: query,
          search_results: [],
          search_history_count: 0,
          search_result_count: 0,
          search_error: if(invalid_regex?, do: invalid_regex_error(), else: nil)
        )
      end

    push_event(socket, "search_highlight", %{
      query: query,
      case_sensitive: assigns.search_case_sensitive,
      regex: assigns.search_regex,
      mention_nick: if(assigns.search_my_mentions, do: assigns.session.nickname, else: nil),
      history_count: socket.assigns.search_history_count
    })
  end

  defp maybe_search_history(_channel, _query, _opts, _assigns, true), do: {0, []}

  defp maybe_search_history(channel, query, opts, assigns, false) do
    if assigns.search_history do
      count = Search.count_matches(channel, query, opts)
      results = Search.search_messages(channel, query, opts)
      {count, results}
    else
      {0, []}
    end
  end

  defp close_and_save_search(socket) do
    socket
    |> assign(
      search_visible: false,
      search_last_query: socket.assigns.search_query,
      search_query: "",
      search_results: [],
      search_result_count: 0,
      search_history_count: 0,
      search_current_index: 0,
      search_error: nil
    )
    |> push_event("search_clear_highlights", %{})
  end

  defp maybe_restore_highlights(socket) do
    query = socket.assigns.search_query

    if query != "" do
      do_search(socket, query)
    else
      socket
    end
  end

  defp toggle_filter(socket, "case_sensitive") do
    socket
    |> assign(search_case_sensitive: !socket.assigns.search_case_sensitive)
    |> re_search()
  end

  defp toggle_filter(socket, "regex") do
    new_val = !socket.assigns.search_regex
    socket = assign(socket, search_regex: new_val)

    socket =
      if new_val and socket.assigns.search_query != "" do
        validate_and_assign_regex(socket)
      else
        assign(socket, search_error: nil)
      end

    re_search(socket)
  end

  defp toggle_filter(socket, "my_mentions") do
    socket
    |> assign(search_my_mentions: !socket.assigns.search_my_mentions)
    |> re_search()
  end

  defp toggle_filter(socket, "mentions"), do: toggle_filter(socket, "my_mentions")

  defp toggle_filter(socket, "history") do
    socket
    |> assign(search_history: !socket.assigns.search_history)
    |> re_search()
  end

  defp toggle_filter(socket, _unknown), do: socket

  defp re_search(socket) do
    query = socket.assigns.search_query

    if query != "" and socket.assigns.search_error == nil do
      do_search(socket, query)
    else
      socket
    end
  end

  defp validate_and_assign_regex(socket) do
    if Search.valid_regex?(socket.assigns.search_query) do
      assign(socket, search_error: nil)
    else
      assign(socket, search_error: invalid_regex_error())
    end
  end

  defp invalid_regex_error, do: gettext("Invalid regex")

  defp build_search_opts(assigns) do
    opts = [
      case_sensitive: assigns.search_case_sensitive,
      regex: assigns.search_regex
    ]

    if assigns.search_my_mentions do
      Keyword.put(opts, :mention_nick, assigns.session.nickname)
    else
      opts
    end
  end
end
