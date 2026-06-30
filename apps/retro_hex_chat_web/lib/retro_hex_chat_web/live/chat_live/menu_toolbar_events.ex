defmodule RetroHexChatWeb.ChatLive.MenuToolbarEvents do
  @moduledoc """
  Handle toolbar events.

  Covers: quit_chat, restore_session, open_search,
  toggle_conversations, toggle_strip_formatting,
  autocomplete_query, autocomplete_close,
  autocomplete_select, autocomplete_navigate, autocomplete_select_current,
  recent_commands_loaded, disconnect.

  Attached as `attach_hook(:menu_toolbar_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, push_navigate: 2, send_update: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      cleanup_channels: 2,
      restore_session: 2,
      load_channel_messages_with_pagination: 2
    ]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChatWeb.ChatLive.CommandDispatch
  alias RetroHexChatWeb.ChatLive.Components.{Composer, DisconnectConfirmDialog}
  alias RetroHexChatWeb.ChatLive.Helpers.PathHelpers
  alias RetroHexChatWeb.ChatLive.SearchEvents

  use Phoenix.VerifiedRoutes, endpoint: RetroHexChatWeb.Endpoint, router: RetroHexChatWeb.Router

  def handle_event("quit_chat", _params, socket) do
    session = socket.assigns.session
    cleanup_channels(session, dgettext("chat", "Leaving"))

    {:halt,
     socket
     |> push_event("intentional_disconnect", %{})
     |> push_navigate(to: PathHelpers.connect_path(socket))}
  end

  def handle_event("restore_session", params, socket) do
    {:halt, restore_session(socket, params)}
  end

  def handle_event("open_search", _params, socket) do
    {:halt, SearchEvents.open(socket)}
  end

  def handle_event("clear_window", _params, socket) do
    {:halt, CommandDispatch.dispatch_command(socket, socket.assigns.session, "clear", [])}
  end

  def handle_event("show_motd", _params, socket) do
    {:halt, CommandDispatch.dispatch_command(socket, socket.assigns.session, "motd", [])}
  end

  def handle_event("toggle_conversations", _params, socket) do
    {:halt, assign(socket, show_conversations: !socket.assigns.show_conversations)}
  end

  def handle_event("toggle_strip_formatting", _params, socket) do
    session = Session.toggle_strip_formatting(socket.assigns.session)
    socket = assign(socket, session: session)

    socket =
      if session.active_channel do
        load_channel_messages_with_pagination(socket, session.active_channel)
      else
        socket
      end

    {:halt, socket}
  end

  def handle_event("autocomplete_query", params, socket) do
    {:halt, put_composer(socket, autocomplete_query: params)}
  end

  def handle_event("autocomplete_close", _params, socket) do
    {:halt, put_composer(socket, autocomplete_close: true)}
  end

  def handle_event("autocomplete_select", params, socket) do
    {:halt, put_composer(socket, autocomplete_select: params)}
  end

  def handle_event("autocomplete_select_current", _params, socket) do
    {:halt, put_composer(socket, autocomplete_select_current: true)}
  end

  def handle_event("autocomplete_navigate", %{"direction" => direction}, socket) do
    {:halt, put_composer(socket, autocomplete_navigate: direction)}
  end

  def handle_event("recent_commands_loaded", %{"commands" => commands}, socket) do
    {:halt, put_composer(socket, recent_commands_loaded: commands)}
  end

  def handle_event("disconnect", _params, socket) do
    send_update(DisconnectConfirmDialog, id: DisconnectConfirmDialog.id(), action: :open)
    {:halt, socket}
  end

  def handle_event("confirm_disconnect", _params, socket) do
    session = socket.assigns.session
    cleanup_channels(session, dgettext("chat", "Leaving"))

    {:halt,
     socket
     |> push_event("intentional_disconnect", %{})
     |> push_navigate(to: PathHelpers.connect_path(socket))}
  end

  def handle_event("cancel_disconnect", _params, socket) do
    send_update(DisconnectConfirmDialog, id: DisconnectConfirmDialog.id(), action: :close)
    {:halt, socket}
  end

  def handle_event("toggle_cheatsheet", _params, socket) do
    {:halt, assign(socket, cheatsheet_visible: !socket.assigns.cheatsheet_visible)}
  end

  def handle_event("viewport_info", %{"width" => width}, socket) when width < 768 do
    {:halt, assign(socket, show_conversations: false, show_nicklist: false)}
  end

  def handle_event("viewport_info", _params, socket), do: {:halt, socket}

  def handle_event("toggle_nicklist", _params, socket) do
    current = Map.get(socket.assigns, :show_nicklist, true)
    {:halt, assign(socket, show_nicklist: !current)}
  end

  def handle_event("help_topics", _params, socket) do
    {:halt, push_navigate(socket, to: ~p"/chat/help")}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  defp put_composer(socket, attrs) do
    send_update(Composer, [id: Composer.id()] ++ attrs)
    socket
  end
end
