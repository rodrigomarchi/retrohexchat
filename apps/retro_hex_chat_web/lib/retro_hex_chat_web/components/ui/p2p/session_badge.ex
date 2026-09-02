defmodule RetroHexChatWeb.Components.UI.P2P.SessionBadge do
  @moduledoc """
  PM-level P2P session indicators.

  This mirrors the visual contract of `GroupCall.ChannelBadge`, and for the same
  reason: the two are the same question asked of a conversation instead of a
  channel. A session is never on this screen — it lives at `/p2p/:token`, in a
  tab of its own — so the entry has exactly three shapes, and which one is drawn
  is the server's answer:

    * no session, and this reader may start one: a button that sends the invite.
    * a session, and this reader has its tab open: a way *to that tab*. A second
      tab of a session you are in moves the session into it, which is the
      takeover contract firing for somebody who only wanted to look.
    * a session, and no tab of it: the way in, which is a real anchor to the
      session's own address.

  Declining is the fourth control and the only one that is not a door. It stays
  here because refusing an invitation is conversation, and conversation is the
  chat's.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.SurfaceTabLink

  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.Live.OpenSurfaces

  attr :peer, :string, required: true
  attr :session, :map, default: nil
  attr :state, :any, default: nil
  attr :current, :boolean, default: false
  attr :on_start, :any, default: "p2p_start_pm_session"

  attr :open_paths, :any,
    default: nil,
    doc: "the addresses this person already has open, from `Live.OpenSurfaces`"

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
      <%!-- Nothing to enter yet: this conversation has no session, and the
            click is what creates one and writes its card into the PM. --%>
      <button
        :if={@idle?}
        type="button"
        phx-click={@on_start}
        phx-value-peer={@peer}
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
      >
        <Icons.icon_toolbar_p2p class="h-3.5 w-3.5 shrink-0" />
        <span class="conversation-toolbar-button__text">
          {dgettext("p2p", "P2P Session")}
        </span>
      </button>

      <%!-- The tab is already open, so this is a way *to it*: opening a second
            one would move the session out of the window holding it. --%>
      <.link
        :if={not @idle? and @tab_open?}
        href={@path}
        id={"p2p-peer-tab-#{@token}"}
        phx-hook="SurfaceTabLinkHook"
        data-surface-path={@path}
        class={[
          "conversation-toolbar-button flex shrink-0 items-center justify-center shadow-retro-raised bg-surface text-xs",
          "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground",
          status_class(@status)
        ]}
        title={dgettext("p2p", "This P2P session is open in another tab — click to go to it")}
        data-testid="p2p-peer-elsewhere"
        data-peer={@peer}
        data-p2p-state={@visual_state}
        data-p2p-status={Atom.to_string(@status)}
      >
        <Icons.icon_toolbar_p2p class="h-3.5 w-3.5 shrink-0" />
        <span class="conversation-toolbar-button__text">
          {dgettext("p2p", "In another tab")}
        </span>
      </.link>

      <%!-- The way in, and the only one: an anchor to the session's own
            address, so middle-click and open-in-new-tab work and the chat this
            conversation is in stays exactly where it is. --%>
      <.link
        :if={not @idle? and not @tab_open?}
        href={@path}
        target="_blank"
        rel="noopener"
        class={[
          "conversation-toolbar-button relative flex shrink-0 items-center justify-center shadow-retro-raised bg-surface text-xs",
          "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground",
          @current && "bg-canvas font-bold shadow-retro-sunken",
          status_class(@status)
        ]}
        title={@title}
        data-testid="p2p-peer-entry"
        data-peer={@peer}
        data-p2p-state={@visual_state}
        data-p2p-status={Atom.to_string(@status)}
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
      </.link>

      <%!-- Refusing is not a door, which is why it is the one control here
            that is still a button: it ends the invitation from the
            conversation, without anybody entering anything. --%>
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
            </div>
            <span class={[
              "shadow-retro-sunken bg-white px-1 py-px text-[10px] font-bold",
              status_class(@status)
            ]}>
              {status_label(@status)}
            </span>
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
            <%!-- The same door in the popover, in the two shapes it has out
                  in the strip. --%>
            <.surface_tab_link
              :if={not @idle?}
              path={@path}
              open?={@tab_open?}
              class={
                if @pending_received?,
                  do: "h-6 text-xs font-bold",
                  else: "col-span-2 h-6 text-xs font-bold"
              }
              testid="p2p-peer-popover-join"
            />
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

  defp assign_session(assigns) do
    session = normalize_session(assigns[:session], assigns[:state])
    state = value(session, :state)
    role = value(session, :role)
    token = value(session, :token)
    path = value(session, :path) || (token && Paths.p2p_path(token))
    status = status(state)

    assigns
    |> assign(:active, session != nil)
    |> assign(:idle?, state in [:idle, "idle"])
    |> assign(:pending_received?, pending_received?(state, role))
    |> assign(:token, token)
    |> assign(:path, path)
    |> assign(:tab_open?, OpenSurfaces.open?(open_paths(assigns), path))
    |> assign(:status, status)
    |> assign(:visual_state, visual_state(state))
    |> assign(:title, title(assigns.peer, status))
  end

  defp open_paths(assigns) do
    case assigns[:open_paths] do
      %MapSet{} = paths -> paths
      _absent -> MapSet.new()
    end
  end

  defp normalize_session(nil, nil), do: nil
  defp normalize_session(nil, state), do: %{state: state}
  defp normalize_session(session, _state) when is_map(session), do: session

  defp pending_received?(state, role) do
    state in [:pending_received, "pending_received"] or
      (state in [:pending, "pending"] and role in [:peer, "peer"])
  end

  defp status(:idle), do: :idle
  defp status("idle"), do: :idle
  defp status(:pending_received), do: :invite
  defp status("pending_received"), do: :invite
  defp status(:invite_sent), do: :invite
  defp status("pending"), do: :invite
  defp status(:connected), do: :live
  defp status("connected"), do: :live
  defp status(_state), do: :link

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

  defp status_label(:idle), do: dgettext("p2p", "Ready")
  defp status_label(:invite), do: dgettext("p2p", "Invite")
  defp status_label(:link), do: dgettext("p2p", "Link")
  defp status_label(:live), do: dgettext("p2p", "Live")

  defp title(peer, :idle),
    do: dgettext("p2p", "Start P2P session with %{peer}", peer: peer)

  defp title(_peer, :invite), do: dgettext("chat", "P2P invite pending")
  defp title(_peer, :link), do: dgettext("chat", "P2P session connecting")

  defp title(peer, _status),
    do: dgettext("p2p", "Open the P2P session with %{peer} in a tab of its own", peer: peer)

  defp status_class(:idle), do: "border border-primary text-primary"
  defp status_class(:invite), do: "border border-warning text-warning"
  defp status_class(:link), do: "border border-warning-alt text-warning-alt"
  defp status_class(:live), do: "border border-success text-success"

  defp dot_class(:idle), do: "bg-primary"
  defp dot_class(:invite), do: "bg-warning"
  defp dot_class(:link), do: "bg-warning-alt"
  defp dot_class(:live), do: "bg-success"

  # Nil-safe because the session it reads is absent more often than present.
  defp value(nil, _key), do: nil
  defp value(map, key) when is_map(map) and is_atom(key), do: Map.get(map, key)

  defp value(_value, _key), do: nil
end
