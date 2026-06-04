defmodule RetroHexChatWeb.Components.UI.StatusBarApp do
  @moduledoc """
  Application status bar component for the showcase design system.

  Composed from Window (window_status_bar, window_status_bar_field) primitives.
  Displays nick, channel/PM info with user count, lag, clock, and mute toggle.

  ## Usage

      <.status_bar_app
        nickname="alice"
        channel="#lobby"
        user_count={42}
        tab_type={:channel}
        lag_ms={120}
        lag_status={:normal}
        online_buddy_count={2}
        on_notify_toggle="toggle_notify_list"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChatWeb.Icons

  @doc "Renders the application status bar."
  attr :nickname, :string, required: true
  attr :channel, :string, default: nil
  attr :user_count, :integer, default: 0
  attr :tab_type, :atom, default: :channel, values: [:channel, :pm]
  attr :lag_ms, :any, default: nil, doc: "Lag in milliseconds, or nil when unknown/timed out"
  attr :lag_status, :atom, default: :normal, values: [:normal, :warning, :critical, :timeout]
  attr :online_buddy_count, :integer, default: 0
  attr :on_notify_toggle, :any, default: nil
  attr :muted, :boolean, default: false
  attr :timezone, :string, default: "Etc/UTC"
  attr :on_mute_toggle, :any, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec status_bar_app(map()) :: Phoenix.LiveView.Rendered.t()
  def status_bar_app(assigns) do
    ~H"""
    <.window_status_bar
      class={@class}
      data-testid="status-bar-app"
      {@rest}
    >
      <%!-- Zone 1: Nick --%>
      <.window_status_bar_field class="flex items-center gap-retro-2 min-w-0 md:min-w-[80px]">
        <Icons.icon_status_user class="w-3 h-3 shrink-0" />
        <span class="truncate text-xs">{@nickname}</span>
      </.window_status_bar_field>

      <%!-- Zone 2: Channel / PM info with user count --%>
      <.window_status_bar_field grow class="flex items-center gap-retro-2">
        <Icons.icon_tab_channel :if={@tab_type == :channel} class="w-3 h-3 shrink-0" />
        <Icons.icon_tab_pm :if={@tab_type == :pm} class="w-3 h-3 shrink-0" />
        <span class="truncate text-xs">{@channel || "—"}</span>
        <span
          :if={@user_count > 0 and @tab_type == :channel}
          class="text-xs text-muted-foreground shrink-0"
        >
          ({@user_count})
        </span>
      </.window_status_bar_field>

      <%!-- Zone 3: Online buddy count (hidden on mobile) --%>
      <.window_status_bar_field
        :if={@online_buddy_count > 0 and @on_notify_toggle}
        class="hidden md:flex items-center justify-center min-w-[34px] px-[2px]"
      >
        <button
          type="button"
          class="inline-flex items-center justify-center gap-retro-2 w-full h-full min-h-0 bg-transparent"
          phx-click={@on_notify_toggle}
          title={buddy_count_label(@online_buddy_count)}
          aria-label={buddy_count_label(@online_buddy_count)}
          data-testid="status-bar-notify-badge"
        >
          <Icons.icon_btn_bell class="w-3 h-3 shrink-0" />
          <span class="text-xs font-mono leading-none">{@online_buddy_count}</span>
        </button>
      </.window_status_bar_field>

      <%!-- Zone 4: Lag display (hidden on mobile) --%>
      <.window_status_bar_field class={[
        "hidden md:flex items-center gap-retro-2 min-w-[64px]",
        lag_class(@lag_status)
      ]}>
        <Icons.icon_status_signal class="w-3 h-3 shrink-0" />
        <span id="lag-display" phx-hook="LagHook" class="text-xs">
          {lag_text(@lag_ms, @lag_status)}
        </span>
      </.window_status_bar_field>

      <%!-- Zone 5: Clock (hidden on mobile) --%>
      <.window_status_bar_field class="hidden md:flex items-center gap-retro-2 min-w-[64px]">
        <Icons.icon_clock class="w-3 h-3 shrink-0" />
        <span id="clock-display" phx-hook="ClockHook" class="text-xs font-mono">--:--</span>
      </.window_status_bar_field>

      <%!-- Zone 6: Mute toggle --%>
      <.window_status_bar_field class="flex items-center justify-center w-[28px] shrink-0">
        <.button
          :if={@on_mute_toggle}
          type="button"
          variant="ghost"
          size="icon"
          class="w-full h-full min-h-0"
          phx-click={@on_mute_toggle}
          title={if @muted, do: "Unmute", else: "Mute"}
          aria-label={if @muted, do: "Unmute", else: "Mute"}
          data-testid="status-bar-mute-toggle"
        >
          <:icon>
            <Icons.icon_mute :if={@muted} class="w-3 h-3" />
            <Icons.icon_dialog_sound :if={!@muted} class="w-3 h-3" />
          </:icon>
        </.button>
        <span :if={!@on_mute_toggle} class="flex items-center justify-center w-full h-full">
          <Icons.icon_mute :if={@muted} class="w-3 h-3" />
          <Icons.icon_dialog_sound :if={!@muted} class="w-3 h-3" />
        </span>
      </.window_status_bar_field>
    </.window_status_bar>
    """
  end

  # ── Private helpers ───────────────────────────────────

  @spec buddy_count_label(non_neg_integer()) :: String.t()
  defp buddy_count_label(count),
    do: dngettext("ui", "%{count} buddy online", "%{count} buddies online", count)

  @spec lag_text(integer() | nil, atom()) :: String.t()
  defp lag_text(nil, :timeout), do: "?"
  defp lag_text(nil, _), do: "—"
  defp lag_text(ms, _), do: "#{ms}ms"

  @spec lag_class(atom()) :: String.t() | nil
  defp lag_class(:warning), do: "text-warning-alt"
  defp lag_class(:critical), do: "text-error"
  defp lag_class(:timeout), do: "text-error"
  defp lag_class(_), do: nil
end
