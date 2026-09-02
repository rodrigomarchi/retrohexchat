defmodule RetroHexChatWeb.Components.UI.StatusBarApp do
  @moduledoc """
  Application status bar component for the showcase design system.

  Composed from Window (window_status_bar, window_status_bar_field) primitives.
  Shows live session state — active call or P2P session, online buddies, lag,
  clock and the mute toggle. The three readouts a desktop tray also has a place
  for (`show_clock`, `show_lag`, `show_mute`) can be dropped here so they are
  not reported twice on the same screen.

  Who you are and what you are reading are *not* here: the window title bar
  names them (`#lobby[Troll]` plus the identity state), and repeating that a few
  pixels above it only cost the eye a second stop.

  ## Usage

      <.status_bar_app
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
  attr :lag_ms, :any, default: nil, doc: "Lag in milliseconds, or nil when unknown/timed out"
  attr :lag_status, :atom, default: :normal, values: [:normal, :warning, :critical, :timeout]
  attr :online_buddy_count, :integer, default: 0
  attr :on_notify_toggle, :any, default: nil
  attr :muted, :boolean, default: false
  attr :timezone, :string, default: "Etc/UTC"

  attr :group_call, :map,
    default: nil,
    doc: """
    A live conference this reader is in, as `%{label, title, path}`. A call is
    never on the screen showing this bar, so the zone is a link to the tab
    holding it and carries no Leave — leaving is done from the screen in it.
    """

  attr :p2p, :map,
    default: nil,
    doc: """
    A live P2P session this reader is in, as `%{label, title, path}`. A session
    is never on the screen showing this bar, so the zone is a link to the tab
    holding it and carries no End — ending is done from the screen in it. The
    zone stays visible on mobile.
    """

  attr :show_clock, :boolean,
    default: true,
    doc: "hide the clock zone when the surrounding chrome already shows one (e.g. a desktop tray)"

  attr :show_lag, :boolean,
    default: true,
    doc: "same, for the lag readout"

  attr :show_mute, :boolean,
    default: true,
    doc: "same, for the mute toggle"

  attr :on_mute_toggle, :any, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec status_bar_app(map()) :: Phoenix.LiveView.Rendered.t()
  def status_bar_app(assigns) do
    ~H"""
    <.window_status_bar class={@class} data-testid="status-bar-app" {@rest}>
      <.status_bar_zones
        lag_ms={@lag_ms}
        lag_status={@lag_status}
        online_buddy_count={@online_buddy_count}
        on_notify_toggle={@on_notify_toggle}
        muted={@muted}
        timezone={@timezone}
        group_call={@group_call}
        p2p={@p2p}
        show_clock={@show_clock}
        show_lag={@show_lag}
        show_mute={@show_mute}
        on_mute_toggle={@on_mute_toggle}
      />
    </.window_status_bar>
    """
  end

  @doc """
  The status zones on their own, without a bar around them.

  A window that already has a status bar of its own — `desktop_window`'s
  `:status` slot renders one — needs the fields, not a second frame. The chat
  window reports its active call this way.
  """
  attr :lag_ms, :any, default: nil, doc: "Lag in milliseconds, or nil when unknown/timed out"
  attr :lag_status, :atom, default: :normal, values: [:normal, :warning, :critical, :timeout]
  attr :online_buddy_count, :integer, default: 0
  attr :on_notify_toggle, :any, default: nil
  attr :muted, :boolean, default: false
  attr :timezone, :string, default: "Etc/UTC"

  attr :group_call, :map,
    default: nil,
    doc: """
    A live conference this reader is in, as `%{label, title, path}`. A call is
    never on this screen, so the zone is always a way over to the tab holding
    it — there is no control here to stop one with.
    """

  attr :p2p, :map,
    default: nil,
    doc: """
    A live P2P session this reader is in, as `%{label, title, path}`. A session
    is never on this screen, so the zone is always a way over to the tab holding
    it — there is no control here to end one with.
    """

  attr :show_clock, :boolean,
    default: true,
    doc: "hide the clock zone when the surrounding chrome already shows one (e.g. a desktop tray)"

  attr :show_lag, :boolean,
    default: true,
    doc: "same, for the lag readout"

  attr :show_mute, :boolean,
    default: true,
    doc: "same, for the mute toggle"

  attr :on_mute_toggle, :any, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec status_bar_zones(map()) :: Phoenix.LiveView.Rendered.t()
  def status_bar_zones(assigns) do
    ~H"""
    <%!-- Zone group call: a conference this reader is in, always on a screen
            that is not this one. Never hidden on mobile: an active session must
            stay visible. --%>
    <.window_status_bar_field
      :if={@group_call}
      class="flex items-center gap-retro-2 min-w-0 px-[2px]"
    >
      <%!-- The call is on another screen of this person's, so this zone is a
            way to that screen and not a control over the call. It stays an
            anchor with the real address: the hook asks the tab to come
            forward, and the click after a silent refusal follows the link. --%>
      <.link
        href={@group_call.path}
        target="_blank"
        rel="noopener"
        id="status-bar-group-call-elsewhere"
        phx-hook="SurfaceTabLinkHook"
        data-surface-path={@group_call.path}
        class="inline-flex items-center gap-retro-2 min-w-0 h-full min-h-0 bg-transparent"
        title={@group_call.title}
        aria-label={@group_call.title}
        data-testid="status-bar-group-call"
      >
        <Icons.icon_protocol_conference_compact class="w-3 h-3 shrink-0" />
        <span class="truncate text-xs">{@group_call.label}</span>
      </.link>
    </.window_status_bar_field>

    <.window_status_bar_field :if={@p2p} class="flex items-center gap-retro-2 min-w-0 px-[2px]">
      <%!-- The session is in another page of this person's: a way over to it,
            and no End beside it, because a session is ended from the screen
            that is holding it. --%>
      <.link
        href={@p2p.path}
        target="_blank"
        rel="noopener"
        id="status-bar-p2p-elsewhere"
        phx-hook="SurfaceTabLinkHook"
        data-surface-path={@p2p.path}
        class="inline-flex items-center gap-retro-2 min-w-0 h-full min-h-0 bg-transparent"
        title={@p2p.title}
        aria-label={@p2p.title}
        data-testid="status-bar-p2p"
      >
        <Icons.icon_protocol_p2p_compact class="w-3 h-3 shrink-0" />
        <span class="truncate text-xs">{@p2p.label}</span>
      </.link>
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
    <.window_status_bar_field
      :if={@show_lag}
      class={[
        "hidden md:flex items-center gap-retro-2 min-w-[64px]",
        lag_class(@lag_status)
      ]}
    >
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
    <.window_status_bar_field
      :if={@show_mute}
      class="flex items-center justify-center w-[28px] shrink-0"
    >
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
