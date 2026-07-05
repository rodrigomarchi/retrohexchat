defmodule RetroHexChatWeb.Components.UI.ConnectStatusBar do
  @moduledoc """
  Status bar for the connect desktop's top bar.

  The pre-auth counterpart to `StatusBarApp`, composed from the same
  `window_status_bar`/`window_status_bar_field` primitives but limited to what
  exists before a session: the connection state and the current sign-in step.
  No clock — the desktop tray owns it.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChatWeb.Icons

  attr :step, :atom, default: :nickname, values: [:nickname, :password, :register]
  attr :class, :any, default: nil
  attr :rest, :global

  @spec connect_status_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def connect_status_bar(assigns) do
    ~H"""
    <.window_status_bar class={@class} data-testid="connect-status-bar" {@rest}>
      <%!-- Connection state --%>
      <.window_status_bar_field class="flex items-center gap-retro-2 min-w-0">
        <Icons.icon_status_signal class="h-3 w-3 shrink-0" />
        <span class="truncate text-xs">{dgettext("connect", "Not connected")}</span>
      </.window_status_bar_field>

      <%!-- Current sign-in step --%>
      <.window_status_bar_field grow class="hidden md:flex items-center gap-retro-2 min-w-0">
        <Icons.icon_connect class="h-3 w-3 shrink-0" />
        <span class="truncate text-xs">{step_text(@step)}</span>
      </.window_status_bar_field>
    </.window_status_bar>
    """
  end

  # ── Private helpers ───────────────────────────────────

  @spec step_text(atom()) :: String.t()
  defp step_text(:password), do: dgettext("connect", "Authentication")
  defp step_text(:register), do: dgettext("connect", "Registration")
  defp step_text(_step), do: dgettext("connect", "User Information")
end
