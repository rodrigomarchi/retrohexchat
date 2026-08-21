defmodule RetroHexChatWeb.Components.UI.ConnectStatusBar do
  @moduledoc """
  The logon window's own status bar fields.

  The pre-auth counterpart to `StatusBarApp`'s zones: `window_status_bar_field`
  elements limited to what exists before a session — the connection state and
  the current sign-in step. Fields only, no frame: the window draws that itself
  from `desktop_window/1`'s `:status` slot. No clock either — the desktop tray
  owns it.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChatWeb.Icons

  attr :step, :atom, default: :nickname, values: [:nickname, :password, :register]

  @spec connect_status_zones(map()) :: Phoenix.LiveView.Rendered.t()
  def connect_status_zones(assigns) do
    ~H"""
    <%!-- A phone reads these as icons: the labels drop below md and the title
          carries the meaning, exactly as `StatusBarApp` does in the chat. The
          menu strip folds to a rail of icons at that width too, and a zone
          spelling out "Not connected" beside it was the one piece of chrome
          still spending its width on prose. --%>
    <%!-- Connection state --%>
    <.window_status_bar_field
      class="flex items-center gap-retro-2 min-w-0"
      title={dgettext("connect", "Not connected")}
      data-testid="connect-status-connection"
    >
      <Icons.icon_status_signal class="h-3 w-3 shrink-0" />
      <span class="hidden truncate text-xs md:inline">
        {dgettext("connect", "Not connected")}
      </span>
    </.window_status_bar_field>

    <%!-- Current sign-in step --%>
    <.window_status_bar_field
      grow
      class="flex items-center gap-retro-2 min-w-0"
      title={step_text(@step)}
      data-testid="connect-status-step"
    >
      <Icons.icon_connect class="h-3 w-3 shrink-0" />
      <span class="hidden truncate text-xs md:inline">{step_text(@step)}</span>
    </.window_status_bar_field>
    """
  end

  # ── Private helpers ───────────────────────────────────

  @spec step_text(atom()) :: String.t()
  defp step_text(:password), do: dgettext("connect", "Authentication")
  defp step_text(:register), do: dgettext("connect", "Registration")
  defp step_text(_step), do: dgettext("connect", "User Information")
end
