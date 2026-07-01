defmodule RetroHexChatWeb.App.ComposerEvents do
  @moduledoc """
  Shared `attach_hook` layer forwarding the composer's keyboard-driven events
  into the `Composer` LiveComponent.

  `AutocompleteHook` and `CharCounterHook` push their events (autocomplete,
  history, tab-completion, syntax tooltip) to the root LiveView; this hook relays
  each one to the Composer via `send_update`. It is context-agnostic, so every
  host that mounts the Composer — the main chat and the P2P lobby — attaches it
  and the event-name contract lives in one place instead of being duplicated per
  surface.
  """

  import Phoenix.LiveView, only: [send_update: 2]

  alias RetroHexChatWeb.ChatLive.Components.Composer

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt | :cont, Phoenix.LiveView.Socket.t()}
  def handle_event("autocomplete_query", params, socket),
    do: {:halt, put_composer(socket, autocomplete_query: params)}

  def handle_event("autocomplete_close", _params, socket),
    do: {:halt, put_composer(socket, autocomplete_close: true)}

  def handle_event("autocomplete_select", params, socket),
    do: {:halt, put_composer(socket, autocomplete_select: params)}

  def handle_event("autocomplete_select_current", _params, socket),
    do: {:halt, put_composer(socket, autocomplete_select_current: true)}

  def handle_event("autocomplete_navigate", %{"direction" => direction}, socket),
    do: {:halt, put_composer(socket, autocomplete_navigate: direction)}

  def handle_event("recent_commands_loaded", %{"commands" => commands}, socket),
    do: {:halt, put_composer(socket, recent_commands_loaded: commands)}

  def handle_event("history_navigate", %{"direction" => direction}, socket),
    do: {:halt, put_composer(socket, history_navigate: direction)}

  def handle_event("tab_complete", params, socket),
    do: {:halt, put_composer(socket, tab_complete: params)}

  def handle_event("syntax_tooltip_query", %{"command" => command, "args" => args}, socket),
    do: {:halt, put_composer(socket, syntax_query: %{command: command, args: args})}

  def handle_event("syntax_tooltip_dismiss", _params, socket),
    do: {:halt, put_composer(socket, syntax_dismiss: true)}

  def handle_event(_event, _params, socket), do: {:cont, socket}

  defp put_composer(socket, attrs) do
    send_update(Composer, [id: Composer.id()] ++ attrs)
    socket
  end
end
