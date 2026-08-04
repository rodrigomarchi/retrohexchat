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
    <%!-- A phone reads this bar as icons: the labels drop below md and the title
          carries the meaning, exactly as `StatusBarApp` does in the chat. The
          header there is a rail of icons too, and a zone spelling out
          "Not connected" beside it was the one piece of chrome still spending
          its width on prose. --%>
    <.window_status_bar class={@class} data-testid="connect-status-bar" {@rest}>
      <%!-- Connection state --%>
      <.window_status_bar_field
        class="flex items-center gap-retro-2 min-w-0"
        title={dgettext("connect", "Not connected")}
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
      >
        <Icons.icon_connect class="h-3 w-3 shrink-0" />
        <span class="hidden truncate text-xs md:inline">{step_text(@step)}</span>
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
