defmodule RetroHexChatWeb.ChatLive.MenuToolbarEvents do
  @moduledoc """
  Handle menu bar and toolbar events.

  Covers: quit_chat, restore_session, open_search, settings,
  toggle_treebar, toggle_nicklist, toggle_strip_formatting, show_about,
  open/close_command_palette, filter_command_palette, select_command,
  disconnect, channel_list.

  Attached as `attach_hook(:menu_toolbar_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, push_navigate: 2]

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      cleanup_channels: 1,
      restore_session: 2,
      load_channel_messages_with_pagination: 2
    ]

  alias RetroHexChat.Accounts.Session

  use Phoenix.VerifiedRoutes, endpoint: RetroHexChatWeb.Endpoint, router: RetroHexChatWeb.Router

  def handle_event("quit_chat", _params, socket) do
    cleanup_channels(socket.assigns.session)

    {:halt,
     socket
     |> push_event("intentional_disconnect", %{})
     |> push_navigate(to: ~p"/")}
  end

  def handle_event("restore_session", params, socket) do
    {:halt, restore_session(socket, params)}
  end

  def handle_event("open_search", _params, socket) do
    {:halt, assign(socket, search_visible: true)}
  end

  def handle_event("settings", _params, socket) do
    {:halt, socket}
  end

  def handle_event("toggle_treebar", _params, socket) do
    {:halt, assign(socket, show_treebar: !socket.assigns.show_treebar)}
  end

  def handle_event("toggle_nicklist", _params, socket) do
    {:halt, assign(socket, show_nicklist: !socket.assigns.show_nicklist)}
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

  def handle_event("show_about", _params, socket) do
    {:halt, assign(socket, show_about: true)}
  end

  def handle_event("open_command_palette", _params, socket) do
    {:halt, assign(socket, command_palette_visible: true, command_palette_filter: "")}
  end

  def handle_event("close_command_palette", _params, socket) do
    {:halt, assign(socket, command_palette_visible: false, command_palette_filter: "")}
  end

  def handle_event("filter_command_palette", %{"filter" => filter}, socket) do
    {:halt, assign(socket, command_palette_filter: filter)}
  end

  def handle_event("select_command", %{"command" => command}, socket) do
    {:halt,
     assign(socket,
       input: "/#{command} ",
       command_palette_visible: false,
       command_palette_filter: ""
     )}
  end

  def handle_event("disconnect", _params, socket) do
    cleanup_channels(socket.assigns.session)
    {:halt, push_navigate(socket, to: ~p"/")}
  end

  def handle_event("channel_list", _params, socket) do
    {:halt, push_navigate(socket, to: ~p"/channels")}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}
end
