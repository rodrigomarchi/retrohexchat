defmodule RetroHexChatWeb.ChatLive.MenuToolbarEvents do
  @moduledoc """
  Handle toolbar events.

  Covers: quit_chat, restore_session, open_search,
  toggle_conversations, toggle_strip_formatting, show_about,
  autocomplete_query, autocomplete_close,
  autocomplete_select, autocomplete_navigate, autocomplete_select_current,
  recent_commands_loaded, disconnect.

  Attached as `attach_hook(:menu_toolbar_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, push_navigate: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      cleanup_channels: 2,
      restore_session: 2,
      load_channel_messages_with_pagination: 2
    ]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Commands.Autocomplete
  alias RetroHexChatWeb.ChatLive.Helpers.PathHelpers

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
    {:halt, assign(socket, search_visible: true)}
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

  def handle_event("show_about", _params, socket) do
    {:halt, assign(socket, show_about: true)}
  end

  def handle_event("autocomplete_query", %{"type" => "command", "partial" => partial}, socket) do
    results =
      Autocomplete.search_commands(
        partial,
        socket.assigns.recent_commands
      )

    {:halt,
     assign(socket,
       autocomplete_visible: true,
       autocomplete_mode: :command,
       autocomplete_results: results,
       autocomplete_filter: partial,
       autocomplete_selected: 0
     )}
  end

  def handle_event("autocomplete_query", %{"type" => "nick", "partial" => partial}, socket) do
    session = socket.assigns.session

    if session.active_channel && !socket.assigns.show_status_tab do
      channel_users = socket.assigns.channel_users

      results =
        Autocomplete.search_nicks(partial, channel_users, session.nickname)

      {:halt,
       assign(socket,
         autocomplete_visible: true,
         autocomplete_mode: :nick,
         autocomplete_results: results,
         autocomplete_filter: partial,
         autocomplete_selected: 0
       )}
    else
      {:halt, socket}
    end
  end

  def handle_event("autocomplete_query", %{"type" => "channel", "partial" => partial}, socket) do
    session = socket.assigns.session

    results =
      Autocomplete.search_channels(partial, session.channels)

    {:halt,
     assign(socket,
       autocomplete_visible: true,
       autocomplete_mode: :channel,
       autocomplete_results: results,
       autocomplete_filter: partial,
       autocomplete_selected: 0
     )}
  end

  def handle_event(
        "autocomplete_query",
        %{"type" => "arg_nick", "partial" => partial, "command" => command},
        socket
      ) do
    session = socket.assigns.session

    case Autocomplete.argument_context(command) do
      {:nick, :current_channel} ->
        channel_users = socket.assigns.channel_users
        results = Autocomplete.search_nicks(partial, channel_users, session.nickname)

        {:halt,
         assign(socket,
           autocomplete_visible: true,
           autocomplete_mode: :nick,
           autocomplete_results: results,
           autocomplete_filter: partial,
           autocomplete_selected: 0
         )}

      {:nick, :all_channels} ->
        channel_users = socket.assigns.channel_users
        results = Autocomplete.search_nicks(partial, channel_users, session.nickname)

        {:halt,
         assign(socket,
           autocomplete_visible: true,
           autocomplete_mode: :nick,
           autocomplete_results: results,
           autocomplete_filter: partial,
           autocomplete_selected: 0
         )}

      _ ->
        {:halt, socket}
    end
  end

  def handle_event(
        "autocomplete_query",
        %{"type" => "arg_channel", "partial" => partial},
        socket
      ) do
    session = socket.assigns.session
    results = Autocomplete.search_channels(partial, session.channels)

    {:halt,
     assign(socket,
       autocomplete_visible: true,
       autocomplete_mode: :channel,
       autocomplete_results: results,
       autocomplete_filter: partial,
       autocomplete_selected: 0
     )}
  end

  def handle_event(
        "autocomplete_query",
        %{"type" => "arg_subcommand", "partial" => partial, "command" => command},
        socket
      ) do
    results = Autocomplete.search_subcommands(command, partial)

    {:halt,
     assign(socket,
       autocomplete_visible: true,
       autocomplete_mode: :subcommand,
       autocomplete_command: command,
       autocomplete_results: results,
       autocomplete_filter: partial,
       autocomplete_selected: 0
     )}
  end

  def handle_event("autocomplete_query", _params, socket) do
    {:halt, socket}
  end

  def handle_event("autocomplete_close", _params, socket) do
    {:halt,
     socket
     |> assign(
       autocomplete_visible: false,
       autocomplete_mode: nil,
       autocomplete_command: nil,
       autocomplete_results: [],
       autocomplete_filter: "",
       autocomplete_selected: 0
     )
     |> push_event("autocomplete_closed", %{})}
  end

  def handle_event("autocomplete_select", %{"type" => "command", "value" => command}, socket) do
    {:halt,
     socket
     |> assign(
       input: "/#{command} ",
       autocomplete_visible: false,
       autocomplete_mode: nil,
       autocomplete_results: [],
       autocomplete_filter: "",
       autocomplete_selected: 0
     )
     |> push_event("set_input", %{value: "/#{command} "})}
  end

  def handle_event("autocomplete_select", %{"type" => "nick", "value" => nickname}, socket) do
    {:halt,
     socket
     |> assign(
       autocomplete_visible: false,
       autocomplete_mode: nil,
       autocomplete_results: [],
       autocomplete_filter: "",
       autocomplete_selected: 0
     )
     |> push_event("set_input", %{value: "@#{nickname} "})}
  end

  def handle_event("autocomplete_select", %{"type" => "channel", "value" => channel_name}, socket) do
    {:halt,
     socket
     |> assign(
       autocomplete_visible: false,
       autocomplete_mode: nil,
       autocomplete_results: [],
       autocomplete_filter: "",
       autocomplete_selected: 0
     )
     |> push_event("set_input", %{value: channel_name <> " "})}
  end

  def handle_event(
        "autocomplete_select",
        %{"type" => "subcommand", "value" => subcommand, "command" => command},
        socket
      ) do
    value = "/#{command} #{subcommand} "

    {:halt,
     socket
     |> assign(
       input: value,
       autocomplete_visible: false,
       autocomplete_mode: nil,
       autocomplete_command: nil,
       autocomplete_results: [],
       autocomplete_filter: "",
       autocomplete_selected: 0
     )
     |> push_event("set_input", %{value: value})}
  end

  def handle_event("autocomplete_select", _params, socket) do
    {:halt, socket}
  end

  def handle_event("autocomplete_select_current", _params, socket) do
    results = socket.assigns.autocomplete_results
    selected = socket.assigns.autocomplete_selected
    mode = socket.assigns.autocomplete_mode

    selectable = Enum.reject(results, &is_binary/1)

    case Enum.at(selectable, selected) do
      nil ->
        {:halt, socket}

      item ->
        {type, value} = select_item_params(mode, item)

        params = %{"type" => type, "value" => value}

        params =
          if mode == :subcommand do
            Map.put(params, "command", socket.assigns.autocomplete_command)
          else
            params
          end

        handle_event("autocomplete_select", params, socket)
    end
  end

  def handle_event("autocomplete_navigate", %{"direction" => direction}, socket) do
    results = socket.assigns.autocomplete_results
    selectable_count = Enum.count(results, &(not is_binary(&1)))
    current = socket.assigns.autocomplete_selected

    new_selected =
      case direction do
        "up" -> rem(current - 1 + selectable_count, max(selectable_count, 1))
        "down" -> rem(current + 1, max(selectable_count, 1))
      end

    {:halt, assign(socket, autocomplete_selected: new_selected)}
  end

  def handle_event("recent_commands_loaded", %{"commands" => commands}, socket) do
    {:halt, assign(socket, recent_commands: commands)}
  end

  def handle_event("disconnect", _params, socket) do
    {:halt, assign(socket, show_disconnect_confirm: true)}
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
    {:halt, assign(socket, show_disconnect_confirm: false)}
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

  defp select_item_params(:command, %{name: name}), do: {"command", name}
  defp select_item_params(:nick, %{nickname: nick}), do: {"nick", nick}
  defp select_item_params(:channel, %{name: name}), do: {"channel", name}
  defp select_item_params(:subcommand, %{name: name}), do: {"subcommand", name}
  defp select_item_params(_, %{name: name}), do: {"command", name}
end
