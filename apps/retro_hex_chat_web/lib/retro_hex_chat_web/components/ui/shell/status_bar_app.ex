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
  import RetroHexChatWeb.Components.UI.AccountStatus
  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChatWeb.Icons

  @doc "Renders the application status bar."
  attr :nickname, :string, required: true
  attr :account_state, :atom, default: :guest, values: [:guest, :identified, :away]
  attr :away, :boolean, default: false
  attr :on_account_click, :any, default: nil
  attr :on_away_toggle, :any, default: nil
  attr :channel, :string, default: nil
  attr :user_count, :integer, default: 0
  attr :tab_type, :atom, default: :channel, values: [:channel, :pm]
  attr :lag_ms, :any, default: nil, doc: "Lag in milliseconds, or nil when unknown/timed out"
  attr :lag_status, :atom, default: :normal, values: [:normal, :warning, :critical, :timeout]
  attr :online_buddy_count, :integer, default: 0
  attr :on_notify_toggle, :any, default: nil
  attr :muted, :boolean, default: false
  attr :timezone, :string, default: "Etc/UTC"

  attr :group_call, :map,
    default: nil,
    doc: "Active group-call display (%{label, title, stop_title})"

  attr :on_group_call_click, :any, default: nil
  attr :on_group_call_stop, :any, default: nil

  attr :p2p, :map,
    default: nil,
    doc:
      "Active P2P session display (%{label, title, stop_title}) — the zone stays visible on mobile"

  attr :on_p2p_click, :any, default: nil
  attr :on_p2p_stop, :any, default: nil

  attr :show_clock, :boolean,
    default: true,
    doc: "hide the clock zone when the surrounding chrome already shows one (e.g. a desktop tray)"

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
      <%!-- Zone 1: Account / presence --%>
      <.window_status_bar_field class="flex items-center gap-retro-2 min-w-0 md:min-w-[128px]">
        <.account_status
          nickname={@nickname}
          account_state={@account_state}
          away={@away}
          on_click={@on_account_click}
          on_away_toggle={@on_away_toggle}
        />
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

      <%!-- Zone group call: active channel conference — click focuses the
            conference windows, the trailing button leaves the session.
            Never hidden on mobile: an active session must stay visible. --%>
      <.window_status_bar_field
        :if={@group_call}
        class="flex items-center gap-retro-2 min-w-0 px-[2px]"
      >
        <button
          type="button"
          class="inline-flex items-center gap-retro-2 min-w-0 h-full min-h-0 bg-transparent"
          phx-click={@on_group_call_click}
          title={@group_call.title}
          aria-label={@group_call.title}
          data-testid="status-bar-group-call"
        >
          <Icons.icon_protocol_conference_compact class="w-3 h-3 shrink-0" />
          <span class="truncate text-xs">{@group_call.label}</span>
        </button>
        <button
          type="button"
          class="inline-flex items-center justify-center h-full min-h-0 bg-transparent shrink-0"
          phx-click={@on_group_call_stop}
          title={@group_call.stop_title}
          aria-label={@group_call.stop_title}
          data-testid="status-bar-group-call-stop"
        >
          <Icons.icon_phone_end class="w-3 h-3" />
        </button>
      </.window_status_bar_field>

      <.window_status_bar_field :if={@p2p} class="flex items-center gap-retro-2 min-w-0 px-[2px]">
        <button
          type="button"
          class="inline-flex items-center gap-retro-2 min-w-0 h-full min-h-0 bg-transparent"
          phx-click={@on_p2p_click}
          title={@p2p.title}
          aria-label={@p2p.title}
          data-testid="status-bar-p2p"
        >
          <Icons.icon_protocol_p2p_compact class="w-3 h-3 shrink-0" />
          <span class="truncate text-xs">{@p2p.label}</span>
          <.p2p_badges p2p={@p2p} />
        </button>
        <button
          type="button"
          class="inline-flex items-center justify-center h-full min-h-0 bg-transparent shrink-0"
          phx-click={@on_p2p_stop}
          title={@p2p.stop_title}
          aria-label={@p2p.stop_title}
          data-testid="status-bar-p2p-stop"
        >
          <Icons.icon_btn_disconnect class="w-3 h-3" />
        </button>
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
      <.window_status_bar_field
        :if={@show_clock}
        class="hidden md:flex items-center gap-retro-2 min-w-[64px]"
      >
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

  attr :p2p, :map, required: true

  defp p2p_badges(assigns) do
    ~H"""
    <span
      class="inline-flex min-w-0 shrink-0 items-center gap-[2px]"
      data-testid="status-bar-p2p-badges"
    >
      <span
        :for={facet <- @p2p[:facets] || []}
        class="inline-flex h-4 w-4 items-center justify-center bg-canvas shadow-retro-sunken"
        title={p2p_facet_title(facet)}
        data-testid={"status-bar-p2p-facet-#{facet}"}
      >
        <.p2p_facet_icon facet={facet} />
      </span>
      <span
        :if={@p2p[:quality]}
        class="hidden h-4 items-center gap-[1px] bg-canvas px-1 text-[10px] shadow-retro-sunken sm:inline-flex"
        title={dgettext("ui", "P2P call quality")}
        data-testid="status-bar-p2p-quality"
      >
        <Icons.icon_status_signal class="h-3 w-3" />
        {@p2p[:quality]}
      </span>
      <span
        :if={@p2p[:turn_only]}
        class="inline-flex h-4 w-4 items-center justify-center bg-canvas shadow-retro-sunken"
        title={dgettext("ui", "P2P privacy relay active")}
        data-testid="status-bar-p2p-relay"
      >
        <Icons.icon_privacy class="h-3 w-3" />
      </span>
    </span>
    """
  end

  attr :facet, :atom, required: true

  defp p2p_facet_icon(assigns) do
    ~H"""
    <Icons.icon_camera :if={@facet == :call} class="h-3 w-3" />
    <Icons.icon_file_send :if={@facet == :file} class="h-3 w-3" />
    <Icons.icon_joystick :if={@facet == :game} class="h-3 w-3" />
    """
  end

  defp p2p_facet_title(:call), do: dgettext("ui", "P2P call active")
  defp p2p_facet_title(:file), do: dgettext("ui", "P2P file transfer active")
  defp p2p_facet_title(:game), do: dgettext("ui", "P2P game active")
  defp p2p_facet_title(_facet), do: dgettext("ui", "P2P feature active")

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
