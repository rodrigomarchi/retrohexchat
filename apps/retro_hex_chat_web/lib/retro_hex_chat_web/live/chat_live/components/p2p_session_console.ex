defmodule RetroHexChatWeb.ChatLive.Components.P2PSessionConsole do
  @moduledoc """
  Unified P2P media-session surface.

  This component is a product shell: it composes the existing call, file, game
  and stats surfaces without owning their lifecycle state. The host LiveView
  keeps the session read model and the islands keep their feature state.
  """

  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.Lobby.LobbyNetworkPanel
  import RetroHexChatWeb.Components.UI.MediaSession.ActionButton
  import RetroHexChatWeb.Components.UI.MediaSession.IconButton
  import RetroHexChatWeb.Components.UI.MediaSession.SectionNav

  alias RetroHexChatWeb.ChatLive.Components.{P2PFileIsland, P2PGameIsland, P2PMediaIsland}
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.Icons.CallControls

  @sections ~w(call files games stats)

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns =
      assigns
      |> assign(:section, normalize_section(assigns[:section]))
      |> assign(:p2p_connected?, p2p_connected?(assigns.p2p_session))

    ~H"""
    <section
      id={@id}
      class="flex h-full min-h-0 flex-col overflow-hidden bg-surface text-foreground"
      data-testid="p2p-session-console"
      data-p2p-console-section={@section}
      data-p2p-media-mode={Map.get(@p2p_session, :media_mode, "video")}
    >
      <.section_nav
        aria_label={dgettext("p2p", "P2P session sections")}
        event="p2p_console_select"
        testid="p2p-console-nav"
        testid_prefix="p2p-console-nav"
        actions_label={dgettext("p2p", "P2P window controls")}
        class="flex shrink-0 flex-wrap border border-border bg-muted shadow-retro-sunken"
        button_class="min-w-[4.75rem]"
      >
        <:item section="call" active={@section == "call"} label={dgettext("p2p", "Call")}>
          <Icons.icon_camera class="h-4 w-4" />
        </:item>
        <:item section="files" active={@section == "files"} label={dgettext("p2p", "Files")}>
          <Icons.icon_file_send class="h-4 w-4" />
        </:item>
        <:item section="games" active={@section == "games"} label={dgettext("p2p", "Games")}>
          <Icons.icon_game_arcade class="h-4 w-4" />
        </:item>
        <:item section="stats" active={@section == "stats"} label={dgettext("p2p", "Stats")}>
          <Icons.icon_status_signal class="h-4 w-4" />
        </:item>

        <:actions>
          <.media_session_icon_button
            label={
              if Map.get(@p2p_session, :call_mini, false),
                do: dgettext("p2p", "Expand call window"),
                else: dgettext("p2p", "Mini call window")
            }
            active={Map.get(@p2p_session, :call_mini, false)}
            pressed={Map.get(@p2p_session, :call_mini, false)}
            phx-click="p2p_toggle_call_mini"
            data-testid="p2p-call-mini-toggle"
          >
            <CallControls.icon_call_expand
              :if={Map.get(@p2p_session, :call_mini, false)}
              class="h-4 w-4"
            />
            <CallControls.icon_call_mini
              :if={!Map.get(@p2p_session, :call_mini, false)}
              class="h-4 w-4"
            />
          </.media_session_icon_button>
          <.media_session_icon_button
            label={dgettext("p2p", "End P2P session")}
            tone="danger"
            phx-click="p2p_statusbar_stop"
            data-testid="p2p-console-end-session"
          >
            <Icons.icon_btn_disconnect class="h-4 w-4" />
          </.media_session_icon_button>
        </:actions>
      </.section_nav>

      <.recovery_notice p2p_session={@p2p_session} />

      <div class="min-h-0 flex-1 overflow-hidden border border-border border-t-0 bg-canvas">
        <div
          id="p2p-console-section-call-scroll"
          phx-hook="PreserveScrollHook"
          data-preserve-scroll-target="self"
          class={section_class(@section, "call")}
          data-testid="p2p-console-section-call"
        >
          <.live_component
            module={P2PMediaIsland}
            id={P2PMediaIsland.id()}
            connected={@p2p_connected?}
            nickname={@nickname}
            peer_nick={@p2p_session.peer_nick}
            token={@p2p_session.token}
            user_id={@p2p_session.user_id}
            mini={Map.get(@p2p_session, :call_mini, false)}
            device_preferences={Map.get(@p2p_session, :device_preferences, %{})}
            media_mode={Map.get(@p2p_session, :media_mode, "video")}
          />
        </div>

        <div
          id="p2p-console-section-files-scroll"
          phx-hook="PreserveScrollHook"
          data-preserve-scroll-target="self"
          class={section_class(@section, "files")}
          data-testid="p2p-console-section-files"
        >
          <.live_component
            module={P2PFileIsland}
            id={P2PFileIsland.id()}
            connected={@p2p_connected?}
            nickname={@nickname}
            peer_nick={@p2p_session.peer_nick}
            token={@p2p_session.token}
          />
        </div>

        <div
          id="p2p-console-section-games-scroll"
          phx-hook="PreserveScrollHook"
          data-preserve-scroll-target="self"
          class={section_class(@section, "games")}
          data-testid="p2p-console-section-games"
        >
          <.live_component
            module={P2PGameIsland}
            id={P2PGameIsland.id()}
            connected={@p2p_connected?}
            peer_nick={@p2p_session.peer_nick}
          />
        </div>

        <div
          id="p2p-console-section-stats-scroll"
          phx-hook="PreserveScrollHook"
          data-preserve-scroll-target="self"
          class={section_class(@section, "stats")}
          data-testid="p2p-console-section-stats"
        >
          <.lobby_network_panel
            :if={@section == "stats"}
            stats={@p2p_session.stats}
            info_open={@p2p_session.info_open}
            nickname={@nickname}
            peer_nick={@p2p_session.peer_nick}
            peer_online={@p2p_session.peer_online}
            session_status={@session_status}
            connection_label={@connection_label}
            local_info={@client_info}
            peer_info={@p2p_session.peer_info}
            call_summary={@p2p_session.call_summary}
            file_summary={@p2p_session.file_summary}
            game_summary={@p2p_session.game_summary}
            turn_only={@p2p_session.turn_only}
          />
        </div>
      </div>
    </section>
    """
  end

  defp section_class(active_section, "call") do
    [
      "h-full min-h-0 overflow-hidden p-1",
      active_section != "call" && "hidden"
    ]
  end

  defp section_class(active_section, section) do
    [
      "h-full min-h-0 overflow-auto p-1",
      active_section != section && "hidden"
    ]
  end

  defp normalize_section(section) when section in @sections, do: section

  defp normalize_section(section) when is_atom(section),
    do: normalize_section(Atom.to_string(section))

  defp normalize_section(_section), do: "call"

  defp p2p_connected?(%{recovery: %{state: state}}) when state in [:reconnecting, :failed],
    do: false

  defp p2p_connected?(%{state: :connected}), do: true
  defp p2p_connected?(_p2p), do: false

  @doc """
  P2P session status for the window title bar.

  Only the session-wide state belongs here — the file and game counters are
  section-specific and already have their own tabs.
  """
  attr :p2p_session, :map, required: true
  attr :connection_label, :string, default: nil

  @spec p2p_title_meta(map()) :: Phoenix.LiveView.Rendered.t()
  def p2p_title_meta(assigns) do
    ~H"""
    <span
      class="inline-flex min-w-0 items-center gap-1 truncate"
      aria-live="polite"
      data-testid="p2p-call-status-announcer"
    >
      <Icons.icon_status_signal class="h-3.5 w-3.5 shrink-0" />
      {connection_label(@p2p_session, @connection_label)}
    </span>
    <span class="inline-flex items-center gap-1" data-testid="p2p-call-kind">
      <CallControls.icon_call_webrtc class="h-3.5 w-3.5 shrink-0" />
      {call_status_label(@p2p_session)}
    </span>
    <span
      :if={call_duration_label(@p2p_session)}
      class="inline-flex items-center gap-1 font-bold"
      data-testid="p2p-call-duration"
    >
      <Icons.icon_clock class="h-3.5 w-3.5 shrink-0" />
      {call_duration_label(@p2p_session)}
    </span>
    """
  end

  defp connection_label(_p2p, label) when is_binary(label) and label != "", do: label

  defp connection_label(%{recovery: %{state: :failed}}, _label),
    do: dgettext("chat", "Connection failed")

  defp connection_label(%{recovery: %{state: :reconnecting, attempt: attempt}}, _label)
       when is_integer(attempt) and attempt > 0,
       do: dgettext("chat", "Reconnecting (%{attempt}/3)", attempt: attempt)

  defp connection_label(%{recovery: %{state: :reconnecting}}, _label),
    do: dgettext("chat", "Reconnecting...")

  defp connection_label(%{state: :connected}, _label), do: dgettext("chat", "Connected")
  defp connection_label(%{state: :joining}, _label), do: dgettext("chat", "Joining...")
  defp connection_label(%{state: :connecting}, _label), do: dgettext("chat", "Connecting...")
  defp connection_label(_p2p, _label), do: dgettext("chat", "Preparing")

  defp call_status_label(%{call_summary: %{type: "video"}}), do: dgettext("p2p", "Video")
  defp call_status_label(%{call_summary: %{type: "audio"}}), do: dgettext("p2p", "Audio")
  defp call_status_label(%{call_summary: %{type: "receiving"}}), do: dgettext("p2p", "Receiving")
  defp call_status_label(%{state: :invite_sent}), do: dgettext("p2p", "Invite pending")
  defp call_status_label(_p2p), do: dgettext("p2p", "Ready")

  defp call_duration_label(%{call_summary: %{duration: duration}})
       when is_binary(duration) and duration != "",
       do: duration

  defp call_duration_label(_p2p), do: nil

  defp recovery_notice(assigns) do
    assigns = assign(assigns, :recovery, Map.get(assigns.p2p_session, :recovery, %{}))

    ~H"""
    <div
      :if={recovery_visible?(@recovery)}
      class={recovery_notice_class(@recovery)}
      role={if recovery_failed?(@recovery), do: "alert", else: "status"}
      aria-live={if recovery_failed?(@recovery), do: "assertive", else: "polite"}
      data-testid="p2p-recovery-banner"
      data-p2p-recovery-state={@recovery.state}
    >
      <div class="flex min-w-0 items-start gap-2">
        <Icons.icon_warning class={["mt-[1px] h-4 w-4 shrink-0", recovery_icon_class(@recovery)]} />
        <div class="min-w-0">
          <div class="font-bold leading-4" data-testid="p2p-recovery-title">
            {recovery_title(@recovery)}
          </div>
          <div
            class="min-w-0 text-[10px] leading-3 text-muted-foreground"
            data-testid="p2p-recovery-message"
          >
            {recovery_message(@recovery)}
          </div>
        </div>
      </div>
      <div class="flex shrink-0 justify-end gap-1">
        <.media_session_action_button
          :if={manual_retry?(@recovery)}
          label={dgettext("p2p", "Retry P2P connection")}
          phx-click="p2p_retry_connection"
          data-testid="p2p-retry-connection"
        >
          <Icons.icon_btn_refresh class="h-4 w-4" />
          <span>{dgettext("p2p", "Retry")}</span>
        </.media_session_action_button>
        <.media_session_action_button
          label={dgettext("p2p", "End P2P session")}
          tone="danger"
          phx-click="p2p_statusbar_stop"
          data-testid="p2p-end-from-recovery"
        >
          <Icons.icon_btn_disconnect class="h-4 w-4" />
          <span>{dgettext("p2p", "End")}</span>
        </.media_session_action_button>
      </div>
    </div>
    """
  end

  defp recovery_visible?(%{state: state}) when state in [:reconnecting, :failed], do: true
  defp recovery_visible?(_recovery), do: false

  defp recovery_failed?(%{state: :failed}), do: true
  defp recovery_failed?(_recovery), do: false

  defp manual_retry?(%{state: :failed, manual_retry: true}), do: true
  defp manual_retry?(_recovery), do: false

  defp recovery_notice_class(%{state: :failed}) do
    "flex shrink-0 flex-col gap-1 border border-destructive bg-destructive/10 px-2 py-1 text-destructive sm:flex-row sm:items-center sm:justify-between"
  end

  defp recovery_notice_class(_recovery) do
    "flex shrink-0 flex-col gap-1 border border-warning bg-warning-light px-2 py-1 text-foreground sm:flex-row sm:items-center sm:justify-between"
  end

  defp recovery_icon_class(%{state: :failed}), do: "text-destructive"
  defp recovery_icon_class(_recovery), do: "text-warning"

  defp recovery_title(%{state: :failed}), do: dgettext("p2p", "Connection needs attention")
  defp recovery_title(_recovery), do: dgettext("p2p", "Reconnecting")

  defp recovery_message(%{state: :failed, reason: "max_retries_exhausted"}) do
    dgettext("p2p", "Automatic recovery did not reconnect. Retry or end the session.")
  end

  defp recovery_message(%{state: :failed}) do
    dgettext("p2p", "The P2P media connection failed. Retry or end the session.")
  end

  defp recovery_message(%{state: :reconnecting, attempt: attempt})
       when is_integer(attempt) and attempt > 0 do
    dgettext("p2p", "Retrying the peer connection, attempt %{attempt} of 3.", attempt: attempt)
  end

  defp recovery_message(_recovery) do
    dgettext("p2p", "Trying to restore the peer connection.")
  end
end
