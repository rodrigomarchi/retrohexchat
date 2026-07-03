defmodule RetroHexChatWeb.Components.UI.Games.ArcadeStatusBar do
  @moduledoc """
  Status bar for the solo arcade desktop's top bar.

  The arcade counterpart to `StatusBarApp`/`LobbyStatusBar`, composed from the same
  `window_status_bar`/`window_status_bar_field` primitives but surfacing
  arcade-relevant state: the player's nickname, the current game (when playing) or a
  session-status label, and the clock (filled in client-side by `ClockHook`).
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChatWeb.Icons

  attr :nickname, :string, required: true
  attr :session_status, :string, default: "lobby"
  attr :game_name, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global

  @spec arcade_status_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def arcade_status_bar(assigns) do
    ~H"""
    <.window_status_bar class={@class} data-testid="arcade-status-bar" {@rest}>
      <%!-- Player --%>
      <.window_status_bar_field class="flex items-center gap-retro-2 min-w-0">
        <Icons.icon_status_user class="h-3 w-3 shrink-0" />
        <span class="truncate text-xs">{@nickname}</span>
      </.window_status_bar_field>

      <%!-- Current game / status --%>
      <.window_status_bar_field
        grow
        class="hidden md:flex items-center gap-retro-2 min-w-0"
      >
        <Icons.icon_joystick class="h-3 w-3 shrink-0" />
        <span class="truncate text-xs">{status_text(@session_status, @game_name)}</span>
      </.window_status_bar_field>

      <%!-- Clock --%>
      <.window_status_bar_field class="flex items-center gap-retro-2 min-w-[64px]">
        <Icons.icon_clock class="h-3 w-3 shrink-0" />
        <span id="arcade-status-clock" phx-hook="ClockHook" class="text-xs font-mono">--:--</span>
      </.window_status_bar_field>
    </.window_status_bar>
    """
  end

  # ── Private helpers ───────────────────────────────────

  @spec status_text(String.t(), String.t() | nil) :: String.t()
  defp status_text("playing", game_name) when is_binary(game_name), do: game_name
  defp status_text("playing", _game_name), do: dgettext("games", "Playing")
  defp status_text("finished", _game_name), do: dgettext("games", "Session complete")
  defp status_text(_status, _game_name), do: dgettext("games", "Ready")
end
