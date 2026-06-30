defmodule RetroHexChatWeb.ChatLive.AdminConsoleEvents do
  @moduledoc """
  Routes the Admin Console open/close triggers to the stateful island.

  All Admin Console state, events and privileged `Admin`/`Dispatcher`/`Server`
  work live in `RetroHexChatWeb.ChatLive.Components.AdminConsoleDialog`. This hook
  only gates the open action on the viewer's admin role and drives the component
  via `send_update`; close fires from the dialog's own Close button / title-bar X
  / Escape `JS.push`.

  Attached as `attach_hook(:admin_console_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.LiveView, only: [send_update: 2]
  import RetroHexChatWeb.ChatLive.Helpers, only: [error_event: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.ServerRoles
  alias RetroHexChatWeb.ChatLive.Components.AdminConsoleDialog

  def handle_event("open_admin_console", _params, socket) do
    if admin?(socket) do
      send_update(AdminConsoleDialog, id: AdminConsoleDialog.id(), open: true)
      {:halt, socket}
    else
      {:halt,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("close_admin_console", _params, socket) do
    send_update(AdminConsoleDialog, id: AdminConsoleDialog.id(), close: true)
    {:halt, socket}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  defp admin?(socket) do
    session = socket.assigns.session

    ServerRoles.admin?(session.nickname, session.identified) or
      ServerRoles.server_operator?(session.nickname, session.identified)
  end
end
