defmodule RetroHexChatWeb.ChatLive.AdminEvents do
  @moduledoc """
  Routes the admin windows' open triggers to their server-managed windows.

  Each window's state, events and privileged work live in its own island under
  `RetroHexChatWeb.ChatLive.Components`; this hook only decides whether the
  caller may open one. That gate is the server-side authorization against a
  forged `window_open`, and the render guards in `chat_live.html.heex` are the
  second line of defense.

  A fresh mount seeds each island's clean state, so no open-directive is needed.
  Closing is the window manager's title-bar X.

  Attached as `attach_hook(:admin_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import RetroHexChatWeb.ChatLive.Helpers, only: [error_event: 2]

  alias RetroHexChatWeb.ChatLive.{AdminOps, Windows}

  @windows %{
    "open_admin_console" => "admin-console",
    "open_admin_users" => "admin-users",
    "open_admin_channels" => "admin-channels",
    "open_admin_server_settings" => "admin-server-settings",
    "open_admin_audit_log" => "admin-audit-log",
    "open_admin_motd" => "admin-motd",
    "open_admin_turn" => "admin-turn",
    "open_admin_broadcast" => "admin-broadcast",
    "open_admin_danger_zone" => "admin-danger-zone"
  }

  def handle_event(event, _params, socket) when is_map_key(@windows, event) do
    if AdminOps.admin?(socket) do
      {:halt, Windows.open(socket, Map.fetch!(@windows, event))}
    else
      {:halt, error_event(socket, AdminOps.restricted_message())}
    end
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}
end
