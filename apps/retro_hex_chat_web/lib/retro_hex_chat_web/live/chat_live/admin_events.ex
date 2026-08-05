defmodule RetroHexChatWeb.ChatLive.AdminEvents do
  @moduledoc """
  Routes the privileged windows' open triggers to their server-managed windows.

  Each window's state, events and privileged work live in its own island under
  `RetroHexChatWeb.ChatLive.Components`; this hook only decides whether the
  caller may open one. That gate is the server-side authorization against a
  forged `window_open`, and the render guards in `chat_live.html.heex` are the
  second line of defense.

  Which events it answers comes from `WindowRegistry` rather than a list kept
  here. A privileged window whose opener was declared in one place and forgotten
  in the other would either be unreachable or — far worse — reachable without
  passing this gate at all.

  A fresh mount seeds each island's clean state, so no open-directive is needed.
  Closing is the window manager's title-bar X.

  Attached as `attach_hook(:admin_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import RetroHexChatWeb.ChatLive.Helpers, only: [error_event: 2]

  alias RetroHexChatWeb.ChatLive.{AdminOps, WindowRegistry, Windows}

  def handle_event(event, _params, socket) do
    case Map.fetch(WindowRegistry.openers(), event) do
      {:ok, window} -> {:halt, open(socket, window)}
      :error -> {:cont, socket}
    end
  end

  defp open(socket, window) do
    if AdminOps.admin?(socket) do
      Windows.open(socket, window)
    else
      error_event(socket, AdminOps.restricted_message())
    end
  end
end
