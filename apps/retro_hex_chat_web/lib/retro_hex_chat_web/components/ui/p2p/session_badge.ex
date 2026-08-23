defmodule RetroHexChatWeb.Components.UI.P2P.SessionBadge do
  @moduledoc """
  PM-level P2P session indicators.

  This mirrors the visual contract of `GroupCall.ChannelBadge`, but keeps the
  P2P semantics explicit: the indicator belongs to the peer conversation, not
  to a public channel.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  attr :peer, :string, required: true
  attr :session, :map, default: nil
  attr :state, :any, default: nil
  attr :current, :boolean, default: false
  attr :on_open, :any, default: "p2p_statusbar_click"
  attr :on_open_call, :any, default: "p2p_console_select"
  attr :on_open_stats, :any, default: "p2p_console_select"
  attr :on_stop, :any, default: "p2p_statusbar_stop"
  attr :on_start, :any, default: "p2p_start_pm_session"
  attr :class, :any, default: nil

  @spec p2p_peer_entry(map()) :: Phoenix.LiveView.Rendered.t()
  def p2p_peer_entry(assigns) do
    assigns = assign_session(assigns)

    ~H"""
    <div
      :if={@active}
      class={classes(["conversation-toolbar-entry flex items-center gap-px", @class])}
      data-testid="p2p-peer-entry-wrap"
    >
      <button
        type="button"
        phx-click={@primary_event}
        phx-value-peer={@primary_peer}
        phx-value-token={@primary_token}
        class={[
          "conversation-toolbar-button relative flex shrink-0 items-center justify-center shadow-retro-raised bg-surface text-xs",
          "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground",
          @current && "bg-canvas font-bold shadow-retro-sunken",
          status_class(@status)
        ]}
        title={@title}
        aria-pressed={to_string(@current)}
        data-testid="p2p-peer-entry"
        data-peer={@peer}
        data-p2p-state={@visual_state}
        data-p2p-status={Atom.to_string(@status)}
        data-p2p-facets={facets_value(@facets)}
      >
        <Icons.icon_toolbar_p2p class="h-3.5 w-3.5 shrink-0" />
        <span class="conversation-toolbar-button__text">
          {dgettext("p2p", "P2P Session")}
        </span>
        <span
          class={[
            "absolute bottom-0.5 right-0.5 h-1.5 w-1.5 border border-border",
            @status in [:link, :live] && "animate-pulse",
            dot_class(@status)
          ]}
          aria-hidden="true"
        />
      </button>

      <button
        :if={@pending_received?}
        type="button"
        phx-click="p2p_accept_invite"
        phx-value-token={@token}
        disabled={is_nil(@token)}
        class="conversation-toolbar-button flex shrink-0 items-center justify-center p-0 shadow-retro-raised bg-surface text-primary focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground disabled:opacity-50"
        title={dgettext("p2p", "Accept P2P request")}
        aria-label={dgettext("p2p", "Accept P2P request")}
        data-testid="p2p-peer-join"
      >
        <Icons.icon_btn_join class="h-3.5 w-3.5" />
      </button>

      <button
        :if={@pending_received?}
        type="button"
        phx-click="p2p_decline_invite"
        phx-value-token={@token}
        disabled={is_nil(@token)}
        class="conversation-toolbar-button flex items-center justify-center shadow-retro-raised bg-surface text-destructive focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground disabled:opacity-50"
        title={dgettext("p2p", "Decline P2P request")}
        aria-label={dgettext("p2p", "Decline P2P request")}
        data-testid="p2p-peer-decline"
      >
        <Icons.icon_reject class="h-3.5 w-3.5" />
      </button>

      <details class="conversation-toolbar-entry relative">
        <summary
          class={[
            "conversation-toolbar-button flex cursor-pointer list-none items-center justify-center shadow-retro-raised bg-surface text-primary",
            "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
          ]}
          aria-label={dgettext("p2p", "P2P session summary")}
          title={dgettext("p2p", "P2P session summary")}
          data-testid="p2p-peer-popover-toggle"
        >
          <Icons.icon_btn_info class="h-3.5 w-3.5" />
        </summary>

        <div
          class="absolute right-0 top-full z-50 mt-1 w-72 border border-border bg-surface p-2 text-xs shadow-retro-raised"
          role="group"
          data-testid="p2p-peer-popover"
          data-peer={@peer}
        >
          <div class="flex items-start justify-between gap-2 border-b border-border pb-1">
            <div class="min-w-0">
              <div class="flex items-center gap-1 font-bold">
                <Icons.icon_protocol_p2p_compact class="h-3.5 w-3.5 shrink-0" />
                <span class="truncate">{@peer}</span>
              </div>
              <div class="mt-0.5 flex items-center gap-1 text-[10px] text-muted-foreground">
                <Icons.icon_p2p_route class="h-3 w-3 shrink-0" />
                <span>{transport_label(@turn_only)}</span>
              </div>
            </div>
            <span class={[
              "shadow-retro-sunken bg-white px-1 py-px text-[10px] font-bold",
              status_class(@status)
            ]}>
              {status_label(@status)}
            </span>
          </div>

          <div class="mt-2 grid grid-cols-2 gap-1 text-[11px]">
            <div class="shadow-retro-status bg-white px-1 py-px">
              <span class="font-bold">{dgettext("p2p", "Session")}</span>
              <span class="float-right">{status_label(@status)}</span>
            </div>
            <div class="shadow-retro-status bg-white px-1 py-px">
              <span class="font-bold">{dgettext("p2p", "Quality")}</span>
              <span class="float-right truncate max-w-[9ch]">{@quality_label || "-"}</span>
            </div>
          </div>

          <div class="mt-2 shadow-retro-sunken bg-white p-1">
            <div class="mb-1 flex items-center gap-1 text-[10px] font-bold uppercase">
              <Icons.icon_protocol_p2p_compact class="h-3 w-3" />
              <span>{dgettext("p2p", "P2P activity")}</span>
            </div>
            <div class="flex flex-wrap gap-1">
              <span
                :for={facet <- @facets}
                class="inline-flex items-center gap-px border border-border bg-surface px-1 py-px text-[10px]"
                data-testid={"p2p-peer-facet-#{facet}"}
              >
                <.facet_icon facet={facet} class="h-3 w-3" />
                <span>{facet_label(facet)}</span>
              </span>
              <span :if={@facets == []} class="text-muted-foreground">
                {dgettext("p2p", "Session ready")}
              </span>
            </div>
          </div>

          <div class="mt-2 grid grid-cols-2 gap-1">
            <button
              :if={@idle?}
              type="button"
              phx-click={@on_start}
              phx-value-peer={@peer}
              class="col-span-2 flex h-6 items-center justify-center gap-1 shadow-retro-raised bg-surface px-2 text-xs font-bold focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
              data-testid="p2p-peer-start"
            >
              <Icons.icon_btn_join class="h-3.5 w-3.5" />
              <span>{dgettext("p2p", "Start")}</span>
            </button>
            <button
              :if={@pending_received?}
              type="button"
              phx-click="p2p_accept_invite"
              phx-value-token={@token}
              disabled={is_nil(@token)}
              class="flex h-6 items-center justify-center gap-1 shadow-retro-raised bg-surface px-2 text-xs font-bold focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground disabled:opacity-50"
              data-testid="p2p-peer-popover-join"
            >
              <Icons.icon_btn_join class="h-3.5 w-3.5" />
              <span>{dgettext("p2p", "Join")}</span>
            </button>
            <button
              :if={@pending_received?}
              type="button"
              phx-click="p2p_decline_invite"
              phx-value-token={@token}
              disabled={is_nil(@token)}
              class="flex h-6 items-center justify-center gap-1 shadow-retro-raised bg-surface px-2 text-xs font-bold text-destructive focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground disabled:opacity-50"
              data-testid="p2p-peer-popover-decline"
            >
              <Icons.icon_reject class="h-3.5 w-3.5" />
              <span>{dgettext("p2p", "Decline")}</span>
            </button>
            <button
              :if={!@idle? && !@pending_received?}
              type="button"
              phx-click={@on_open_call}
              phx-value-section="call"
              class="flex h-6 items-center justify-center gap-1 shadow-retro-raised bg-surface px-2 text-xs font-bold focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
              data-testid="p2p-peer-open-call"
            >
              <Icons.icon_camera class="h-3.5 w-3.5" />
              <span>{dgettext("p2p", "Call")}</span>
            </button>
            <button
              :if={!@idle? && !@pending_received?}
              type="button"
              phx-click={@on_open_stats}
              phx-value-section="stats"
              class="flex h-6 items-center justify-center gap-1 shadow-retro-raised bg-surface px-2 text-xs font-bold focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
              data-testid="p2p-peer-open-stats"
            >
              <Icons.icon_quality_high class="h-3.5 w-3.5" />
              <span>{dgettext("p2p", "Stats")}</span>
            </button>
            <button
              :if={!@idle? && !@pending_received?}
              type="button"
              phx-click={@on_open}
              class="flex h-6 items-center justify-center gap-1 shadow-retro-raised bg-surface px-2 text-xs font-bold focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
              data-testid="p2p-peer-focus"
            >
              <Icons.icon_btn_open class="h-3.5 w-3.5" />
              <span>{dgettext("p2p", "Focus")}</span>
            </button>
            <button
              :if={!@idle? && !@pending_received?}
              type="button"
              phx-click={@on_stop}
              class="flex h-6 items-center justify-center gap-1 shadow-retro-raised bg-surface px-2 text-xs font-bold text-destructive focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
              data-testid="p2p-peer-end"
            >
              <Icons.icon_phone_end class="h-3.5 w-3.5" />
              <span>{dgettext("p2p", "End")}</span>
            </button>
          </div>
        </div>
      </details>
    </div>
    """
  end

  attr :peer, :string, required: true
  attr :session, :map, default: nil
  attr :state, :any, default: nil
  attr :testid, :string, default: "p2p-peer-glyph"
  attr :class, :any, default: nil

  @spec p2p_peer_glyph(map()) :: Phoenix.LiveView.Rendered.t()
  def p2p_peer_glyph(assigns) do
    assigns = assign_session(assigns)

    ~H"""
    <span
      :if={@active}
      class={
        classes([
          "relative h-4 w-4 shrink-0 inline-flex items-center justify-center bg-canvas shadow-retro-sunken",
          status_class(@status),
          @class
        ])
      }
      title={@title}
      data-testid={@testid}
      data-peer={@peer}
      data-p2p-state={@visual_state}
      data-p2p-status={Atom.to_string(@status)}
      data-p2p-facets={facets_value(@facets)}
    >
      <Icons.icon_protocol_p2p_compact class="h-3 w-3" />
      <span
        class={[
          "absolute bottom-0 right-0 h-1.5 w-1.5 border border-border",
          @status in [:link, :live] && "animate-pulse",
          dot_class(@status)
        ]}
        aria-hidden="true"
      >
      </span>
    </span>
    """
  end

  attr :facet, :atom, required: true
  attr :class, :any, default: nil
  attr :testid, :string, default: nil

  defp facet_icon(%{facet: :call} = assigns) do
    ~H"""
    <span class="inline-flex" data-testid={@testid}>
      <Icons.icon_camera class={@class} />
    </span>
    """
  end

  defp facet_icon(%{facet: :file} = assigns) do
    ~H"""
    <span class="inline-flex" data-testid={@testid}>
      <Icons.icon_file_send class={@class} />
    </span>
    """
  end

  defp facet_icon(%{facet: :game} = assigns) do
    ~H"""
    <span class="inline-flex" data-testid={@testid}>
      <Icons.icon_game_arcade class={@class} />
    </span>
    """
  end

  defp facet_icon(%{facet: :relay} = assigns) do
    ~H"""
    <span class="inline-flex" data-testid={@testid}>
      <Icons.icon_p2p_route class={@class} />
    </span>
    """
  end

  defp assign_session(assigns) do
    session = normalize_session(assigns[:session], assigns[:state])
    state = value(session, :state)
    role = value(session, :role)
    token = value(session, :token)
    facets = facets(session)
    activity_facets = Enum.reject(facets, &(&1 == :relay))
    status = status(state, activity_facets)
    visual_state = visual_state(state)
    quality_label = value(value(session, :call_summary), :quality_label)
    duration = value(value(session, :call_summary), :duration)
    turn_only = value(session, :turn_only) == true and value(session, :turn_configured) == true
    idle? = state in [:idle, "idle"]
    pending_received? = pending_received?(state, role)

    assigns
    |> assign(:session_data, session)
    |> assign(:active, session != nil)
    |> assign(:idle?, idle?)
    |> assign(:pending_received?, pending_received?)
    |> assign(:token, token)
    |> assign(:facets, facets)
    |> assign(:status, status)
    |> assign(:visual_state, visual_state)
    |> assign(:quality_label, quality_label)
    |> assign(:duration, duration)
    |> assign(:turn_only, turn_only)
    |> assign(:title, title(assigns.peer, status, facets))
    |> assign(:primary_event, primary_event(assigns, idle?, pending_received?))
    |> assign(:primary_peer, if(idle?, do: assigns.peer))
    |> assign(:primary_token, if(pending_received?, do: token))
  end

  defp normalize_session(nil, nil), do: nil
  defp normalize_session(nil, state), do: %{state: state}
  defp normalize_session(session, _state) when is_map(session), do: session

  defp pending_received?(state, role) do
    state in [:pending_received, "pending_received"] or
      (state in [:pending, "pending"] and role in [:peer, "peer"])
  end

  defp primary_event(assigns, true = _idle?, _pending_received?),
    do: Map.get(assigns, :on_start, "p2p_start_pm_session")

  defp primary_event(_assigns, _idle?, true = _pending_received?), do: "p2p_accept_invite"

  defp primary_event(assigns, _idle?, _pending_received?),
    do: Map.get(assigns, :on_open, "p2p_statusbar_click")

  defp status(:idle, _activity_facets), do: :idle
  defp status("idle", _activity_facets), do: :idle
  defp status(:pending_received, _activity_facets), do: :invite
  defp status("pending_received", _activity_facets), do: :invite
  defp status(:invite_sent, _activity_facets), do: :invite
  defp status("pending", _activity_facets), do: :invite
  defp status(:connected, []), do: :ready
  defp status("connected", []), do: :ready
  defp status(:connected, _activity_facets), do: :live
  defp status("connected", _activity_facets), do: :live
  defp status(_state, _activity_facets), do: :link

  defp visual_state(:idle), do: "idle"
  defp visual_state("idle"), do: "idle"
  defp visual_state(:pending_received), do: "pending"
  defp visual_state("pending_received"), do: "pending"
  defp visual_state(:invite_sent), do: "pending"
  defp visual_state("pending"), do: "pending"
  defp visual_state(:connected), do: "connected"
  defp visual_state("connected"), do: "connected"
  defp visual_state(nil), do: nil
  defp visual_state(_state), do: "connecting"

  defp facets(session) when is_map(session) do
    []
    |> maybe_add_facet(:call, call_active?(value(session, :call_summary)))
    |> maybe_add_facet(:file, file_active?(value(session, :file_summary)))
    |> maybe_add_facet(:game, game_active?(value(session, :game_summary)))
    |> maybe_add_facet(
      :relay,
      value(session, :turn_only) == true and value(session, :turn_configured) == true
    )
  end

  defp facets(_session), do: []

  defp call_active?(summary), do: is_map(summary)
  defp file_active?(summary), do: is_map(summary)

  defp game_active?(summary) when is_map(summary) do
    value(summary, :active?) == true or value(summary, :status) in ["active", "playing"]
  end

  defp game_active?(_summary), do: false

  defp maybe_add_facet(facets, facet, true), do: facets ++ [facet]
  defp maybe_add_facet(facets, _facet, _false), do: facets

  defp status_label(:idle), do: dgettext("p2p", "Ready")
  defp status_label(:invite), do: dgettext("p2p", "Invite")
  defp status_label(:link), do: dgettext("p2p", "Link")
  defp status_label(:live), do: dgettext("p2p", "Live")
  defp status_label(:ready), do: dgettext("p2p", "Ready")

  defp facet_label(:call), do: dgettext("p2p", "Call")
  defp facet_label(:file), do: dgettext("p2p", "Files")
  defp facet_label(:game), do: dgettext("p2p", "Game")
  defp facet_label(:relay), do: dgettext("p2p", "Relay")

  defp title(peer, :idle, _facets),
    do: dgettext("p2p", "Start P2P session with %{peer}", peer: peer)

  defp title(_peer, :invite, _facets), do: dgettext("chat", "P2P invite pending")
  defp title(_peer, :link, _facets), do: dgettext("chat", "P2P session connecting")

  defp title(peer, _status, []) do
    dgettext("chat", "P2P session active")
    |> title_with_peer(peer)
  end

  defp title(peer, _status, facets) do
    suffix = facets |> Enum.map_join(", ", &facet_title/1)

    dgettext("p2p", "P2P session with %{peer} - %{facets}",
      peer: peer,
      facets: suffix
    )
  end

  defp title_with_peer(title, peer) when is_binary(peer) and peer != "",
    do: "#{title}: #{peer}"

  defp title_with_peer(title, _peer), do: title

  defp facet_title(:call), do: dgettext("chat", "call active")
  defp facet_title(:file), do: dgettext("chat", "file transfer active")
  defp facet_title(:game), do: dgettext("chat", "game active")
  defp facet_title(:relay), do: dgettext("p2p", "privacy relay active")

  defp transport_label(true), do: dgettext("p2p", "Privacy relay")
  defp transport_label(_false), do: dgettext("p2p", "Direct or relay")

  defp status_class(:idle), do: "border border-primary text-primary"
  defp status_class(:invite), do: "border border-warning text-warning"
  defp status_class(:link), do: "border border-warning-alt text-warning-alt"
  defp status_class(:live), do: "border border-success text-success"
  defp status_class(:ready), do: "border border-primary text-primary"

  defp dot_class(:idle), do: "bg-primary"
  defp dot_class(:invite), do: "bg-warning"
  defp dot_class(:link), do: "bg-warning-alt"
  defp dot_class(:live), do: "bg-success"
  defp dot_class(:ready), do: "bg-primary"

  defp facets_value(facets), do: Enum.map_join(facets, ",", &Atom.to_string/1)

  # Nil-safe because the session it reads is absent more often than present.
  defp value(nil, _key), do: nil
  defp value(map, key) when is_map(map) and is_atom(key), do: Map.get(map, key)

  defp value(_value, _key), do: nil
end
