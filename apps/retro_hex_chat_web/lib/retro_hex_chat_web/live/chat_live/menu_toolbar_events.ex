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
  alias RetroHexChatWeb.ChatLive.Components.DisconnectConfirmDialog
  alias RetroHexChatWeb.ChatLive.Helpers.PathHelpers
  alias RetroHexChatWeb.ChatLive.SearchEvents
  alias RetroHexChatWeb.ChatLive.Windows

  use Phoenix.VerifiedRoutes, endpoint: RetroHexChatWeb.Endpoint, router: RetroHexChatWeb.Router

  @mobile_breakpoint 768

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

  # Composer keyboard events (autocomplete/history/tab/syntax) are relayed to the
  # Composer by the shared `RetroHexChatWeb.App.ComposerEvents` hook.

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
    {:halt, Windows.open(socket, "cheatsheet")}
  end

  def handle_event("viewport_info", %{"width" => width} = params, socket) do
    mobile? =
      case mobile_param(params) do
        nil -> viewport_width(width) < @mobile_breakpoint
        value -> value
      end

    {:halt, apply_viewport_mode(socket, mobile?)}
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

  defp apply_viewport_mode(socket, true) do
    if socket.assigns[:mobile_viewport] == true do
      assign(socket, mobile_viewport: true)
    else
      restore = %{
        show_conversations: Map.get(socket.assigns, :show_conversations, true),
        show_nicklist: Map.get(socket.assigns, :show_nicklist, true)
      }

      assign(socket,
        mobile_viewport: true,
        mobile_panel_restore: restore,
        show_conversations: false,
        show_nicklist: false
      )
    end
  end

  defp apply_viewport_mode(socket, false) do
    restore = Map.get(socket.assigns, :mobile_panel_restore)

    socket =
      socket
      |> assign(mobile_viewport: false, mobile_panel_restore: nil)

    if is_map(restore) do
      assign(socket, restore)
    else
      socket
    end
  end

  defp viewport_width(width) when is_integer(width), do: width
  defp viewport_width(width) when is_float(width), do: round(width)

  defp viewport_width(width) when is_binary(width) do
    case Integer.parse(width) do
      {value, _rest} -> value
      :error -> @mobile_breakpoint
    end
  end

  defp viewport_width(_width), do: @mobile_breakpoint

  defp mobile_param(%{"mobile" => value}), do: boolean_param(value)
  defp mobile_param(_params), do: nil

  defp boolean_param(value) when is_boolean(value), do: value
  defp boolean_param("true"), do: true
  defp boolean_param("false"), do: false
  defp boolean_param(_value), do: nil
end
