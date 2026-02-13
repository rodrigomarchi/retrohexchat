defmodule RetroHexChatWeb.ChatLive.HelpEvents do
  @moduledoc """
  Handle events for the Help dialog (F1 / Help menu > Help Topics).

  Covers: toggle_help_dialog, close_help, help_tab, help_select_topic,
  help_index_filter, help_search_input, help_search, help_content_click.

  Attached as an `attach_hook(:help_events, :handle_event, ...)` in ChatLive.mount/3.
  Returns `{:halt, socket}` when the event is handled, `{:cont, socket}` otherwise.
  """

  import Phoenix.Component, only: [assign: 2]

  alias RetroHexChat.Chat.HelpTopics

  # ── Handled events ─────────────────────────────────────────

  def handle_event("toggle_help_dialog", _params, socket) do
    if socket.assigns.show_help_dialog do
      {:halt, close_help_dialog(socket)}
    else
      {:halt, open_help_dialog(socket)}
    end
  end

  def handle_event("close_help", _params, socket) do
    {:halt, close_help_dialog(socket)}
  end

  def handle_event("help_tab", %{"tab" => tab}, socket) do
    {:halt, assign(socket, help_active_tab: tab)}
  end

  def handle_event("help_select_topic", %{"id" => id}, socket) do
    {:halt, assign(socket, help_selected_topic: HelpTopics.get_topic(id))}
  end

  def handle_event("help_index_filter", %{"value" => filter}, socket) do
    {:halt, assign(socket, help_index_filter: filter)}
  end

  def handle_event("help_search_input", %{"key" => "Enter", "value" => query}, socket) do
    {:halt,
     assign(socket, help_search_query: query, help_search_results: HelpTopics.search(query))}
  end

  def handle_event("help_search_input", %{"value" => query}, socket) do
    {:halt, assign(socket, help_search_query: query)}
  end

  def handle_event("help_search", %{"query" => query}, socket) do
    {:halt, assign(socket, help_search_results: HelpTopics.search(query))}
  end

  def handle_event("help_content_click", %{"data-help-topic" => topic_id}, socket) do
    {:halt, assign(socket, help_selected_topic: HelpTopics.get_topic(topic_id))}
  end

  def handle_event("help_content_click", _params, socket) do
    {:halt, socket}
  end

  def handle_event("open_help_at_topic", %{"topic" => topic_id}, socket) do
    {:halt,
     assign(socket,
       show_help_dialog: true,
       help_active_tab: "contents",
       help_selected_topic: HelpTopics.get_topic(topic_id),
       help_index_filter: "",
       help_search_query: "",
       help_search_results: []
     )}
  end

  # ── Catch-all: pass unhandled events to next hook ──────────

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── Private helpers ────────────────────────────────────────

  defp open_help_dialog(socket) do
    assign(socket,
      show_help_dialog: true,
      help_active_tab: "contents",
      help_selected_topic: nil,
      help_index_filter: "",
      help_search_query: "",
      help_search_results: []
    )
  end

  defp close_help_dialog(socket) do
    assign(socket,
      show_help_dialog: false,
      help_selected_topic: nil,
      help_index_filter: "",
      help_search_query: "",
      help_search_results: []
    )
  end
end
