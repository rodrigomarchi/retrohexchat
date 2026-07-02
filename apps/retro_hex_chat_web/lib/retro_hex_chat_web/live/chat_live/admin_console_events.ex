defmodule RetroHexChatWeb.ChatLive.AdminConsoleEvents do
  @moduledoc """
  Routes the Admin Console open/close triggers to the stateful island.

  All Admin Console state, events and privileged `Admin`/`Dispatcher`/`Server`
  work live in `RetroHexChatWeb.ChatLive.Components.AdminConsoleDialog`. This hook
  gates the open action on the viewer's admin role — the gate is the server-side
  authorization for a forged `window_open`, since the console is a managed desktop
  window opened via `Windows.open/2`. A fresh mount seeds the island's clean state,
  so no open-directive is needed. Closing is the window manager's title-bar X.

  Attached as `attach_hook(:admin_console_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import RetroHexChatWeb.ChatLive.Helpers, only: [error_event: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.ServerRoles
  alias RetroHexChatWeb.ChatLive.Components.AdminConsoleDialog
  alias RetroHexChatWeb.ChatLive.Windows

  def handle_event("open_admin_console", _params, socket) do
    if admin?(socket) do
      {:halt, Windows.open(socket, AdminConsoleDialog.id())}
    else
      {:halt,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  defp admin?(socket) do
    session = socket.assigns.session

    ServerRoles.admin?(session.nickname, session.identified) or
      ServerRoles.server_operator?(session.nickname, session.identified)
  end
end
