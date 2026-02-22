defmodule RetroHexChatWeb.ChatLive.LogViewerEvents do
  @moduledoc """
  Handle events for the Log Viewer window.

  Covers: open_log_viewer, close_log_viewer, log_set_source, log_set_date_from,
  log_set_date_to, log_search, log_page, log_refresh, log_toggle_event,
  log_set_timestamp_format, log_export.

  Attached as an `attach_hook(:log_viewer_events, :handle_event, ...)` in ChatLive.mount/3.
  Returns `{:halt, socket}` when the event is handled, `{:cont, socket}` otherwise.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.{DisplayPreferences, LogExporter, LogFilter, LogQueries}

  # ── Handled events ─────────────────────────────────────────

  def handle_event("open_log_viewer", _params, socket) do
    {:halt, open_log_viewer(socket)}
  end

  def handle_event("close_log_viewer", _params, socket) do
    {:halt, close_log_viewer(socket)}
  end

  def handle_event("log_set_source", %{"source" => ""}, socket) do
    filter = %{socket.assigns.log_filter | source: nil, source_type: nil}
    {:halt, assign(socket, log_filter: filter)}
  end

  def handle_event("log_set_source", %{"source" => "pm:" <> nick}, socket) do
    filter = %{socket.assigns.log_filter | source: nick, source_type: :pm, page: 1}
    {:halt, run_log_search(assign(socket, log_filter: filter))}
  end

  def handle_event("log_set_source", %{"source" => channel}, socket) do
    filter = %{socket.assigns.log_filter | source: channel, source_type: :channel, page: 1}
    {:halt, run_log_search(assign(socket, log_filter: filter))}
  end

  def handle_event("log_set_date_from", %{"date" => ""}, socket) do
    filter = %{socket.assigns.log_filter | date_from: nil}
    {:halt, assign(socket, log_filter: filter)}
  end

  def handle_event("log_set_date_from", %{"date" => date_str}, socket) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        filter = %{socket.assigns.log_filter | date_from: date}

        case LogFilter.validate(filter) do
          :ok -> {:halt, assign(socket, log_filter: filter, log_error: nil)}
          {:error, msg} -> {:halt, assign(socket, log_error: msg)}
        end

      _ ->
        {:halt, assign(socket, log_error: "Invalid date format")}
    end
  end

  def handle_event("log_set_date_to", %{"date" => ""}, socket) do
    filter = %{socket.assigns.log_filter | date_to: nil}
    {:halt, assign(socket, log_filter: filter)}
  end

  def handle_event("log_set_date_to", %{"date" => date_str}, socket) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        filter = %{socket.assigns.log_filter | date_to: date}

        case LogFilter.validate(filter) do
          :ok -> {:halt, assign(socket, log_filter: filter, log_error: nil)}
          {:error, msg} -> {:halt, assign(socket, log_error: msg)}
        end

      _ ->
        {:halt, assign(socket, log_error: "Invalid date format")}
    end
  end

  def handle_event("log_search", %{"nickname" => nick, "text" => text}, socket) do
    filter = %{
      socket.assigns.log_filter
      | nickname: normalize_empty(nick),
        text: normalize_empty(text),
        page: 1
    }

    {:halt, run_log_search(assign(socket, log_filter: filter))}
  end

  def handle_event("log_page", %{"page" => page_str}, socket) do
    page = String.to_integer(page_str)
    filter = %{socket.assigns.log_filter | page: page}
    {:halt, run_log_search(assign(socket, log_filter: filter))}
  end

  def handle_event("log_refresh", _params, socket) do
    {:halt, run_log_search(socket)}
  end

  def handle_event("log_toggle_event", %{"event_type" => event_type}, socket) do
    session = socket.assigns.session
    field = String.to_existing_atom(event_type)
    prefs = DisplayPreferences.toggle_event(session.log_preferences, field)
    new_session = Session.set_log_preferences(session, prefs)
    {:halt, assign(socket, session: new_session, log_preferences: prefs)}
  end

  def handle_event("log_set_timestamp_format", %{"format" => format}, socket) do
    session = socket.assigns.session
    fmt = String.to_existing_atom(format)
    prefs = DisplayPreferences.set_timestamp_format(session.log_preferences, fmt)
    new_session = Session.set_log_preferences(session, prefs)
    {:halt, assign(socket, session: new_session, log_preferences: prefs)}
  end

  def handle_event("log_export", %{"format" => format}, socket) do
    page = socket.assigns.log_page

    if page && page.entries != [] do
      filter = socket.assigns.log_filter
      prefs = socket.assigns.log_preferences

      # Fetch ALL matching results (not just current page)
      all_filter = %{filter | page: 1, per_page: 10_000}

      entries = fetch_all_log_entries(socket, all_filter)

      timezone = socket.assigns[:timezone] || "Etc/UTC"
      content = LogExporter.export(entries, format, prefs, timezone)

      filename = LogExporter.generate_filename(filter, format)

      mime =
        if format == "html",
          do: "text/html",
          else: "text/plain"

      {:halt,
       socket
       |> assign(log_exporting: false)
       |> push_event("download_file", %{
         content: Base.encode64(content),
         filename: filename,
         mime_type: mime
       })}
    else
      {:halt, socket}
    end
  end

  # ── Catch-all: pass unhandled events to next hook ──────────

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── Private helpers ────────────────────────────────────────

  defp open_log_viewer(socket) do
    session = socket.assigns.session
    source_options = build_log_source_options(session)
    prefs = session.log_preferences

    assign(socket,
      show_log_viewer: true,
      log_source_options: source_options,
      log_preferences: prefs,
      log_filter: LogFilter.new(),
      log_page: nil,
      log_loading: false,
      log_exporting: false,
      log_error: nil
    )
  end

  defp close_log_viewer(socket) do
    assign(socket,
      show_log_viewer: false,
      log_filter: LogFilter.new(),
      log_source_options: [],
      log_page: nil,
      log_loading: false,
      log_exporting: false,
      log_error: nil
    )
  end

  defp build_log_source_options(session) do
    if session.identified do
      channels =
        LogQueries.list_user_channels(session.nickname)
        |> Enum.map(fn ch -> %{type: :channel, label: ch, value: ch} end)

      pms =
        LogQueries.list_user_pm_partners(session.nickname)
        |> Enum.map(fn nick -> %{type: :pm, label: nick, value: nick} end)

      channels ++ pms
    else
      channels =
        session.channels
        |> Enum.sort()
        |> Enum.map(fn ch -> %{type: :channel, label: ch, value: ch} end)

      pms =
        session.pm_conversations
        |> Enum.sort()
        |> Enum.map(fn nick -> %{type: :pm, label: nick, value: nick} end)

      channels ++ pms
    end
  end

  defp run_log_search(socket) do
    filter = socket.assigns.log_filter

    if filter.source == nil do
      assign(socket, log_page: nil, log_error: nil)
    else
      case LogFilter.validate(filter) do
        :ok ->
          page = fetch_log_page(socket, filter)
          assign(socket, log_page: page, log_loading: false, log_error: nil)

        {:error, msg} ->
          assign(socket, log_error: msg)
      end
    end
  end

  defp fetch_log_page(socket, filter) do
    case filter.source_type do
      :pm ->
        LogQueries.search_pm_log(socket.assigns.session.nickname, filter)

      _ ->
        LogQueries.search_channel_log(filter)
    end
  end

  defp fetch_all_log_entries(socket, filter) do
    page = fetch_log_page(socket, filter)
    page.entries
  end

  defp normalize_empty(""), do: nil
  defp normalize_empty(s), do: s
end
