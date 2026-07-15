defmodule RetroHexChatWeb.Components.UI.GroupCall.Panel do
  @moduledoc """
  Presentation component for the channel group-call window body.

  The ChatLive live component owns runtime state and events; this module owns the
  reusable visual surface and keeps group-call markup in the UI component layer.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Components.UI.GroupCall.{
    ActiveSpeakerRing,
    LayoutControls,
    ParticipantQualityBadge,
    ScreenShareControl,
    VideoSurface
  }

  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.Icons.CallControls

  attr :id, :string, required: true
  attr :call, :map, default: nil
  attr :on_close_room, :any, default: "group_call_close_room"
  attr :on_toggle_audio, :any, default: "group_call_toggle_audio"
  attr :on_toggle_video, :any, default: "group_call_toggle_video"
  attr :on_toggle_hand, :any, default: "group_call_toggle_hand"
  attr :on_leave, :any, default: "group_call_leave"
  attr :on_retry, :any, default: "group_call_retry"
  attr :on_moderate_audio, :any, default: "group_call_moderate_audio"
  attr :on_moderate_video, :any, default: "group_call_moderate_video"
  attr :on_moderate_screen, :any, default: "group_call_moderate_screen"
  attr :on_allow_speak, :any, default: "group_call_allow_speak"
  attr :on_mute_all, :any, default: "group_call_mute_all"
  attr :on_camera_off_all, :any, default: "group_call_camera_off_all"
  attr :on_toggle_lock, :any, default: "group_call_toggle_lock"
  attr :on_kick_participant, :any, default: "group_call_kick_participant"
  attr :on_focus_participant, :any, default: "group_call_focus_participant"
  attr :on_toggle_pin_participant, :any, default: "group_call_toggle_pin_participant"
  attr :on_layout_mode, :any, default: "group_call_layout_mode"
  attr :on_toggle_sidebar, :any, default: "group_call_toggle_sidebar"
  attr :on_cycle_self_view, :any, default: "group_call_cycle_self_view"
  attr :on_toggle_mini, :any, default: "group_call_toggle_mini"
  attr :on_dock_stats, :any, default: "group_call_dock_stats"
  attr :on_clear_focus, :any, default: "group_call_clear_focus"

  @spec group_call_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def group_call_panel(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "flex h-full min-h-0 flex-col gap-1 text-xs",
        mini_mode?(@call) && "group-call-panel--mini"
      ]}
      role="region"
      aria-label={dgettext("group_call", "Channel conference")}
      data-mini-mode={to_string(mini_mode?(@call))}
      data-testid="group-call-panel"
    >
      <.call_header
        :if={!mini_mode?(@call)}
        call={@call}
        on_close_room={@on_close_room}
        on_toggle_audio={@on_toggle_audio}
        on_toggle_video={@on_toggle_video}
        on_toggle_hand={@on_toggle_hand}
        on_leave={@on_leave}
        on_toggle_mini={@on_toggle_mini}
        on_layout_mode={@on_layout_mode}
        on_toggle_sidebar={@on_toggle_sidebar}
        on_cycle_self_view={@on_cycle_self_view}
        on_clear_focus={@on_clear_focus}
        on_dock_stats={@on_dock_stats}
        on_mute_all={@on_mute_all}
        on_camera_off_all={@on_camera_off_all}
        on_toggle_lock={@on_toggle_lock}
      />
      <.mini_header
        :if={mini_mode?(@call)}
        call={@call}
        on_toggle_audio={@on_toggle_audio}
        on_toggle_video={@on_toggle_video}
        on_toggle_mini={@on_toggle_mini}
        on_leave={@on_leave}
      />

      <div class={workspace_class(@call)}>
        <.conference_view_rail
          :if={@call && !mini_mode?(@call)}
          call={@call}
          on_layout_mode={@on_layout_mode}
          on_toggle_sidebar={@on_toggle_sidebar}
          on_cycle_self_view={@on_cycle_self_view}
          on_clear_focus={@on_clear_focus}
        />

        <div class={main_grid_class(@call)}>
          <VideoSurface.video_surface call={@call} />
          <.participant_list
            :if={sidebar_open?(@call) && !mini_mode?(@call)}
            call={@call}
            on_moderate_audio={@on_moderate_audio}
            on_moderate_video={@on_moderate_video}
            on_moderate_screen={@on_moderate_screen}
            on_allow_speak={@on_allow_speak}
            on_kick_participant={@on_kick_participant}
            on_focus_participant={@on_focus_participant}
            on_toggle_pin_participant={@on_toggle_pin_participant}
          />
        </div>
      </div>

      <.conference_bottom_controls
        :if={@call && !mini_mode?(@call)}
        call={@call}
        on_toggle_audio={@on_toggle_audio}
        on_toggle_video={@on_toggle_video}
        on_toggle_hand={@on_toggle_hand}
        on_leave={@on_leave}
      />

      <.call_error call={@call} on_retry={@on_retry} on_leave={@on_leave} />
      <.call_warning call={@call} on_leave={@on_leave} />
    </div>
    """
  end

  defp call_header(assigns) do
    ~H"""
    <div class="flex min-h-8 shrink-0 flex-wrap items-center justify-between gap-1 border border-border bg-surface px-2 py-1 shadow-retro-sunken">
      <div class="flex min-w-0 items-center gap-2">
        <Icons.icon_protocol_conference_compact class="h-8 w-8 shrink-0" />
        <div class="min-w-0">
          <div class="truncate font-bold leading-4">{channel_name(@call)}</div>
          <div class="flex min-w-0 items-center gap-2 text-[10px] leading-3 text-muted-foreground">
            <span
              class="inline-flex min-w-0 items-center gap-1 truncate"
              aria-live="polite"
              data-testid="group-call-status-announcer"
            >
              <Icons.icon_status_signal class={["h-8 w-8 shrink-0", status_icon_class(@call)]} />
              <span class="truncate">{status_label(@call)}</span>
            </span>
            <span class="inline-flex items-center gap-1">
              <Icons.icon_status_user class="h-8 w-8 shrink-0" />
              {participant_count(@call)}
            </span>
            <span class="inline-flex items-center gap-1">
              <CallControls.icon_call_webrtc class="h-8 w-8 shrink-0" />
              {track_count(@call)}
            </span>
          </div>
        </div>
      </div>

      <div
        class="flex max-w-full shrink-0 flex-wrap items-center justify-end gap-1"
        role="toolbar"
        aria-label={dgettext("group_call", "Conference window controls")}
      >
        <.group_call_button
          label={dgettext("group_call", "Dock conference statistics")}
          phx-click={@on_dock_stats}
          data-testid="group-call-dock-stats"
        >
          <CallControls.icon_call_stats class="h-8 w-8" />
        </.group_call_button>

        <.group_call_button
          label={dgettext("group_call", "Switch to compact conference mode")}
          pressed={mini_mode?(@call)}
          phx-click={@on_toggle_mini}
          data-testid="group-call-mini-toggle"
        >
          <CallControls.icon_call_mini class="h-8 w-8" />
        </.group_call_button>
        <.group_call_button
          :if={can_moderate_call?(@call)}
          label={dgettext("group_call", "End group call")}
          tone="danger"
          phx-click={@on_close_room}
          data-testid="group-call-close-room"
        >
          <CallControls.icon_call_phone_end class="h-8 w-8" />
        </.group_call_button>
        <.group_call_button
          :if={can_moderate_call?(@call)}
          label={lock_title(@call)}
          active={locked?(@call)}
          pressed={locked?(@call)}
          phx-click={@on_toggle_lock}
          data-testid="group-call-lock-toggle"
        >
          <CallControls.icon_call_lock class="h-8 w-8" />
        </.group_call_button>
        <.group_call_button
          :if={can_moderate_call?(@call)}
          label={dgettext("group_call", "Mute all lower-ranked participants")}
          phx-click={@on_mute_all}
          data-testid="group-call-mute-all"
        >
          <CallControls.icon_call_mute class="h-8 w-8" />
        </.group_call_button>
        <.group_call_button
          :if={can_moderate_call?(@call)}
          label={dgettext("group_call", "Turn off all lower-ranked cameras")}
          phx-click={@on_camera_off_all}
          data-testid="group-call-camera-off-all"
        >
          <CallControls.icon_call_camera_off class="h-8 w-8" />
        </.group_call_button>
      </div>
    </div>
    """
  end

  defp conference_view_rail(assigns) do
    ~H"""
    <div
      class="flex shrink-0 flex-row flex-wrap content-start gap-1 border border-border bg-surface p-1 shadow-retro-sunken lg:flex-col"
      role="group"
      aria-label={dgettext("group_call", "Conference view controls")}
      data-testid="group-call-view-rail"
    >
      <LayoutControls.layout_controls
        call={@call}
        orientation="vertical"
        on_layout_mode={@on_layout_mode}
        on_toggle_sidebar={@on_toggle_sidebar}
        on_cycle_self_view={@on_cycle_self_view}
        on_clear_focus={@on_clear_focus}
      />
    </div>
    """
  end

  defp conference_bottom_controls(assigns) do
    ~H"""
    <div
      class="flex shrink-0 flex-wrap items-center justify-center gap-2 border border-border bg-surface px-2 py-2 shadow-retro-sunken"
      role="toolbar"
      aria-label={dgettext("group_call", "Conference media controls")}
      data-testid="group-call-media-controls"
    >
      <.group_call_button
        label={dgettext("group_call", "Toggle microphone")}
        active={!media_enabled?(@call, :audio)}
        pressed={media_enabled?(@call, :audio)}
        phx-click={@on_toggle_audio}
        data-testid="group-call-audio-toggle"
      >
        <CallControls.icon_call_microphone :if={media_enabled?(@call, :audio)} class="h-8 w-8" />
        <CallControls.icon_call_mute :if={!media_enabled?(@call, :audio)} class="h-8 w-8" />
      </.group_call_button>

      <.group_call_button
        label={dgettext("group_call", "Toggle camera")}
        active={!media_enabled?(@call, :video)}
        pressed={media_enabled?(@call, :video)}
        phx-click={@on_toggle_video}
        data-testid="group-call-video-toggle"
      >
        <CallControls.icon_call_camera :if={media_enabled?(@call, :video)} class="h-8 w-8" />
        <CallControls.icon_call_camera_off :if={!media_enabled?(@call, :video)} class="h-8 w-8" />
      </.group_call_button>

      <.group_call_button
        label={hand_toggle_title(@call)}
        active={hand_raised?(@call)}
        pressed={hand_raised?(@call)}
        phx-click={@on_toggle_hand}
        data-testid="group-call-hand-toggle"
      >
        <CallControls.icon_call_raise_hand class="h-8 w-8" />
      </.group_call_button>

      <ScreenShareControl.screen_share_control call={@call} />
      <.reaction_controls call={@call} />

      <.group_call_button
        label={dgettext("group_call", "Leave group call")}
        tone="danger"
        phx-click={@on_leave}
        data-testid="group-call-leave"
      >
        <CallControls.icon_call_phone_end class="h-8 w-8" />
      </.group_call_button>
    </div>
    """
  end

  defp mini_header(assigns) do
    ~H"""
    <div
      class="flex min-h-8 shrink-0 items-center justify-between gap-2 border border-border bg-surface px-2 py-1 shadow-retro-sunken"
      data-testid="group-call-mini-header"
    >
      <div class="flex min-w-0 items-center gap-2">
        <Icons.icon_protocol_conference_compact class="h-8 w-8 shrink-0" />
        <div class="min-w-0">
          <div class="truncate font-bold leading-4">{channel_name(@call)}</div>
          <div class="flex min-w-0 items-center gap-2 text-[10px] leading-3 text-muted-foreground">
            <span
              class="inline-flex min-w-0 items-center gap-1 truncate"
              aria-live="polite"
              data-testid="group-call-mini-status-announcer"
            >
              <Icons.icon_status_signal class={["h-8 w-8 shrink-0", status_icon_class(@call)]} />
              <span class="truncate">{status_label(@call)}</span>
            </span>
            <span class="inline-flex items-center gap-1">
              <Icons.icon_status_user class="h-8 w-8 shrink-0" />
              {participant_count(@call)}
            </span>
          </div>
        </div>
      </div>

      <div
        class="flex shrink-0 flex-wrap items-center justify-end gap-1"
        role="toolbar"
        aria-label={dgettext("group_call", "Compact conference controls")}
      >
        <.group_call_button
          label={dgettext("group_call", "Toggle microphone")}
          active={!media_enabled?(@call, :audio)}
          pressed={media_enabled?(@call, :audio)}
          phx-click={@on_toggle_audio}
          data-testid="group-call-mini-audio-toggle"
        >
          <CallControls.icon_call_microphone :if={media_enabled?(@call, :audio)} class="h-8 w-8" />
          <CallControls.icon_call_mute :if={!media_enabled?(@call, :audio)} class="h-8 w-8" />
        </.group_call_button>
        <.group_call_button
          label={dgettext("group_call", "Toggle camera")}
          active={!media_enabled?(@call, :video)}
          pressed={media_enabled?(@call, :video)}
          phx-click={@on_toggle_video}
          data-testid="group-call-mini-video-toggle"
        >
          <CallControls.icon_call_camera :if={media_enabled?(@call, :video)} class="h-8 w-8" />
          <CallControls.icon_call_camera_off :if={!media_enabled?(@call, :video)} class="h-8 w-8" />
        </.group_call_button>
        <.group_call_button
          label={dgettext("group_call", "Expand conference")}
          pressed={mini_mode?(@call)}
          phx-click={@on_toggle_mini}
          data-testid="group-call-mini-expand"
        >
          <CallControls.icon_call_expand class="h-8 w-8" />
        </.group_call_button>
        <.group_call_button
          label={dgettext("group_call", "Leave group call")}
          tone="danger"
          phx-click={@on_leave}
          data-testid="group-call-mini-leave"
        >
          <CallControls.icon_call_phone_end class="h-8 w-8" />
        </.group_call_button>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :active, :boolean, default: false
  attr :pressed, :any, default: nil
  attr :tone, :string, values: ~w(default danger), default: "default"
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  defp group_call_button(assigns) do
    ~H"""
    <button
      type="button"
      title={@label}
      aria-label={@label}
      aria-pressed={aria_pressed(@pressed)}
      class={group_call_button_class(@active, @tone, @class)}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp group_call_button_class(active?, tone, extra) do
    classes([
      "flex h-10 w-10 min-w-[2.5rem] items-center justify-center border border-transparent bg-surface p-0 shadow-retro-raised",
      "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground",
      active? && "bg-muted shadow-retro-sunken",
      tone == "danger" && "bg-destructive text-destructive-foreground",
      extra
    ])
  end

  defp aria_pressed(nil), do: nil
  defp aria_pressed(value) when is_binary(value), do: value
  defp aria_pressed(value), do: to_string(value)

  defp reaction_controls(assigns) do
    ~H"""
    <div
      class="mx-1 flex shrink-0 flex-wrap items-center gap-1 border-l border-border pl-2"
      role="toolbar"
      aria-label={dgettext("group_call", "Conference reactions")}
      data-testid="group-call-reactions"
    >
      <.reaction_button
        call={@call}
        reaction="heart"
        label={dgettext("group_call", "Send heart reaction")}
      >
        <CallControls.icon_call_reaction_heart class="h-8 w-8" />
      </.reaction_button>
      <.reaction_button
        call={@call}
        reaction="thumbs_up"
        label={dgettext("group_call", "Send thumbs up reaction")}
      >
        <CallControls.icon_call_reaction_thumbs_up class="h-8 w-8" />
      </.reaction_button>
      <.reaction_button
        call={@call}
        reaction="clap"
        label={dgettext("group_call", "Send clap reaction")}
      >
        <CallControls.icon_call_reaction_clap class="h-8 w-8" />
      </.reaction_button>
      <.reaction_button
        call={@call}
        reaction="laugh"
        label={dgettext("group_call", "Send laugh reaction")}
      >
        <CallControls.icon_call_reaction_laugh class="h-8 w-8" />
      </.reaction_button>
      <.reaction_button
        call={@call}
        reaction="wow"
        label={dgettext("group_call", "Send sparkle reaction")}
      >
        <CallControls.icon_call_reaction_sparkle class="h-8 w-8" />
      </.reaction_button>
    </div>
    """
  end

  attr :call, :map, required: true
  attr :reaction, :string, required: true
  attr :label, :string, required: true
  slot :inner_block

  defp reaction_button(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "flex h-10 w-10 min-w-[2.5rem] items-center justify-center bg-surface shadow-retro-raised",
        "text-[13px] leading-none focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
      ]}
      data-group-call-reaction={@reaction}
      data-group-call-reaction-for={@call.token}
      data-testid={"group-call-reaction-#{@reaction}"}
      aria-label={@label}
      title={@label}
    >
      <span
        class="flex items-center justify-center"
        aria-hidden="true"
        data-testid={"group-call-reaction-icon-#{@reaction}"}
      >
        <%= if @inner_block != [] do %>
          {render_slot(@inner_block)}
        <% else %>
          <Icons.icon_star class="h-8 w-8" />
        <% end %>
      </span>
    </button>
    """
  end

  defp participant_list(assigns) do
    ~H"""
    <div
      class="flex min-h-0 flex-col border border-border bg-surface shadow-retro-sunken"
      role="complementary"
      aria-label={dgettext("group_call", "Conference participants")}
    >
      <div class="flex min-h-10 shrink-0 items-center justify-between border-b border-border px-2">
        <span class="inline-flex min-w-0 items-center gap-1 font-bold">
          <CallControls.icon_call_participants class="h-8 w-8 shrink-0" />
          <span class="truncate">{dgettext("group_call", "Participants")}</span>
        </span>
        <span class="inline-flex items-center gap-1 text-muted-foreground">
          <Icons.icon_status_user class="h-8 w-8 shrink-0" />
          {participant_count(@call)}
        </span>
      </div>

      <div
        class="min-h-0 flex-1 overflow-auto p-1"
        role="list"
        aria-label={dgettext("group_call", "Conference participant list")}
        data-testid="group-call-participants"
      >
        <div
          :if={participant_count(@call) == 0}
          class="px-1 py-2 text-center text-muted-foreground"
          role="status"
          aria-live="polite"
        >
          {dgettext("group_call", "Joining...")}
        </div>

        <.raised_hand_queue
          call={@call}
          on_allow_speak={@on_allow_speak}
        />

        <.participant_row
          :for={participant <- participants(@call)}
          call={@call}
          participant={participant}
          on_moderate_audio={@on_moderate_audio}
          on_moderate_video={@on_moderate_video}
          on_moderate_screen={@on_moderate_screen}
          on_allow_speak={@on_allow_speak}
          on_kick_participant={@on_kick_participant}
          on_focus_participant={@on_focus_participant}
          on_toggle_pin_participant={@on_toggle_pin_participant}
        />
      </div>
    </div>
    """
  end

  defp raised_hand_queue(assigns) do
    assigns = assign(assigns, :raised_participants, raised_hand_participants(assigns.call))

    ~H"""
    <div
      :if={@raised_participants != []}
      class="mb-1 border border-warning bg-warning-light p-1 shadow-retro-sunken"
      role="status"
      aria-live="polite"
      data-testid="group-call-raised-hand-queue"
    >
      <div class="mb-1 flex items-center justify-between gap-1 text-[10px] font-bold uppercase">
        <span class="inline-flex min-w-0 items-center gap-1">
          <CallControls.icon_call_raise_hand class="h-8 w-8 shrink-0" />
          <span class="truncate">{dgettext("group_call", "Requests to speak")}</span>
        </span>
        <span>{length(@raised_participants)}</span>
      </div>

      <div class="space-y-1">
        <div
          :for={{participant, index} <- Enum.with_index(@raised_participants, 1)}
          class="flex min-w-0 items-center justify-between gap-1 bg-white px-1 py-px shadow-retro-status"
          data-testid={"group-call-raised-hand-#{participant.id}"}
        >
          <span class="inline-flex min-w-0 items-center gap-1">
            <span class="text-muted-foreground">{index}</span>
            <span class="truncate font-bold">{participant.nickname}</span>
          </span>
          <button
            :if={can_moderate_participant?(@call, participant)}
            type="button"
            phx-click={@on_allow_speak}
            phx-value-participant-id={participant.id}
            class="flex h-10 min-w-[2.5rem] shrink-0 items-center justify-center bg-surface px-1 shadow-retro-raised focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
            title={allow_speak_title(participant)}
            aria-label={allow_speak_title(participant)}
            data-testid={"group-call-queue-allow-speak-#{participant.id}"}
          >
            <CallControls.icon_call_raise_hand class="h-8 w-8" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp participant_row(assigns) do
    assigns =
      assigns
      |> assign(:quality, participant_quality(assigns.call, assigns.participant))
      |> assign(:active_speaker, active_speaker?(assigns.call, assigns.participant))
      |> assign(:latest_reaction, latest_participant_reaction(assigns.call, assigns.participant))

    ~H"""
    <div
      class={[
        "mb-1 grid grid-cols-[1fr_auto] gap-1 border border-border bg-canvas px-1.5 py-1",
        @active_speaker && "border-primary bg-primary/10"
      ]}
      data-testid={"group-call-participant-#{@participant.id}"}
      data-group-call-participant
      data-group-call-participant-nickname={@participant.nickname}
      data-media-audio={to_string(participant_media?(@participant, :audio))}
      data-media-video={to_string(participant_media?(@participant, :video))}
      data-media-screen={to_string(participant_media?(@participant, :screen))}
      data-active-speaker={to_string(@active_speaker)}
      data-quality-level={quality_level(@quality)}
      role="listitem"
    >
      <div class="min-w-0">
        <div class="flex min-w-0 items-center gap-1">
          {apply(Icons, participant_role_icon(@participant), [%{class: "h-8 w-8 shrink-0"}])}
          <span class="truncate font-bold">{@participant.nickname}</span>
          <ActiveSpeakerRing.active_speaker_badge
            participant_id={@participant.id}
            active={@active_speaker}
          />
          <span
            :if={participant_hand_raised?(@participant)}
            class="inline-flex h-8 min-w-8 shrink-0 items-center justify-center border border-warning bg-warning-light px-1 text-[9px] font-bold text-foreground shadow-retro-status"
            title={dgettext("group_call", "Hand raised")}
            aria-label={dgettext("group_call", "Hand raised")}
            data-testid={"group-call-participant-hand-#{@participant.id}"}
          >
            <CallControls.icon_call_raise_hand class="h-8 w-8" />
          </span>
          <span
            :if={@latest_reaction}
            class="group-call-participant-reaction inline-flex h-8 min-w-8 shrink-0 items-center justify-center border border-border bg-warning-light px-1 leading-none shadow-retro-status"
            title={participant_reaction_title(@latest_reaction)}
            aria-label={participant_reaction_title(@latest_reaction)}
            data-testid={"group-call-participant-reaction-#{@participant.id}"}
            data-reaction={@latest_reaction.reaction}
          >
            <span
              class="inline-flex items-center justify-center"
              aria-hidden="true"
              data-testid={"group-call-participant-reaction-icon-#{@participant.id}"}
            >
              {apply(Icons, reaction_icon(@latest_reaction.reaction), [%{class: "h-8 w-8"}])}
            </span>
          </span>
        </div>
        <div class="flex min-w-0 items-center gap-1 truncate text-[10px] text-muted-foreground">
          {apply(Icons, participant_status_icon(@participant), [%{class: "h-8 w-8 shrink-0"}])}
          <span class="truncate">{participant_status(@participant)}</span>
        </div>
      </div>
      <div class="flex shrink-0 items-start gap-1">
        <div
          class="grid grid-cols-2 gap-1"
          role="group"
          aria-label={dgettext("group_call", "Participant media state")}
        >
          <.participant_media_indicator participant={@participant} kind={:audio} />
          <.participant_media_indicator participant={@participant} kind={:video} />
          <.participant_media_indicator participant={@participant} kind={:screen} />
          <ParticipantQualityBadge.participant_quality_badge
            participant_id={@participant.id}
            quality={@quality}
          />
        </div>
        <.participant_controls_menu
          call={@call}
          participant={@participant}
          on_focus_participant={@on_focus_participant}
          on_toggle_pin_participant={@on_toggle_pin_participant}
          on_allow_speak={@on_allow_speak}
          on_moderate_audio={@on_moderate_audio}
          on_moderate_video={@on_moderate_video}
          on_moderate_screen={@on_moderate_screen}
          on_kick_participant={@on_kick_participant}
        />
      </div>
    </div>
    """
  end

  defp participant_controls_menu(assigns) do
    ~H"""
    <details class="relative shrink-0">
      <summary
        class={[
          group_call_button_class(false, "default", nil),
          "list-none [&::-webkit-details-marker]:hidden"
        ]}
        title={dgettext("group_call", "Participant actions")}
        aria-label={dgettext("group_call", "Participant actions")}
        data-testid={"group-call-participant-actions-#{@participant.id}"}
      >
        <CallControls.icon_call_more class="h-8 w-8" />
      </summary>

      <div
        class="absolute right-0 top-full z-40 mt-1 grid w-[8.75rem] grid-cols-3 gap-1 border border-border bg-surface p-1 shadow-retro-raised"
        role="toolbar"
        aria-label={dgettext("group_call", "Participant actions")}
      >
        <button
          type="button"
          phx-click={@on_focus_participant}
          phx-value-participant-id={@participant.id}
          class={[
            "flex h-10 w-10 items-center justify-center bg-surface shadow-retro-raised",
            "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground",
            focused_participant?(@call, @participant) && "bg-muted shadow-retro-sunken"
          ]}
          title={focus_participant_title(@call, @participant)}
          aria-label={focus_participant_title(@call, @participant)}
          aria-pressed={to_string(focused_participant?(@call, @participant))}
          data-testid={"group-call-participant-focus-#{@participant.id}"}
        >
          <CallControls.icon_call_layout_focus class="h-8 w-8" />
        </button>
        <button
          type="button"
          phx-click={@on_toggle_pin_participant}
          phx-value-participant-id={@participant.id}
          class={[
            "flex h-10 w-10 items-center justify-center bg-surface shadow-retro-raised",
            "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground",
            pinned_participant?(@call, @participant) && "bg-warning-light shadow-retro-sunken"
          ]}
          title={pin_participant_title(@call, @participant)}
          aria-label={pin_participant_title(@call, @participant)}
          aria-pressed={to_string(pinned_participant?(@call, @participant))}
          data-testid={"group-call-participant-pin-#{@participant.id}"}
        >
          <Icons.icon_pin class="h-8 w-8" />
        </button>
        <button
          :if={
            participant_hand_raised?(@participant) && can_moderate_participant?(@call, @participant)
          }
          type="button"
          phx-click={@on_allow_speak}
          phx-value-participant-id={@participant.id}
          class="flex h-10 w-10 items-center justify-center bg-warning-light shadow-retro-raised focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
          title={allow_speak_title(@participant)}
          aria-label={allow_speak_title(@participant)}
          data-testid={"group-call-participant-allow-speak-#{@participant.id}"}
        >
          <CallControls.icon_call_raise_hand class="h-8 w-8" />
        </button>
        <button
          :if={can_moderate_participant?(@call, @participant)}
          type="button"
          phx-click={@on_moderate_audio}
          phx-value-participant-id={@participant.id}
          class="flex h-10 w-10 items-center justify-center bg-surface shadow-retro-raised focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
          title={moderate_audio_title(@participant)}
          aria-label={moderate_audio_title(@participant)}
          data-testid={"group-call-participant-audio-moderate-#{@participant.id}"}
        >
          <CallControls.icon_call_mute :if={participant_media?(@participant, :audio)} class="h-8 w-8" />
          <CallControls.icon_call_microphone
            :if={!participant_media?(@participant, :audio)}
            class="h-8 w-8"
          />
        </button>
        <button
          :if={can_moderate_video_participant?(@call, @participant)}
          type="button"
          phx-click={@on_moderate_video}
          phx-value-participant-id={@participant.id}
          class="flex h-10 w-10 items-center justify-center bg-surface shadow-retro-raised focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
          title={moderate_video_title(@participant)}
          aria-label={moderate_video_title(@participant)}
          data-testid={"group-call-participant-video-moderate-#{@participant.id}"}
        >
          <CallControls.icon_call_camera_off
            :if={participant_media?(@participant, :video)}
            class="h-8 w-8"
          />
          <CallControls.icon_call_camera
            :if={!participant_media?(@participant, :video)}
            class="h-8 w-8"
          />
        </button>
        <button
          :if={can_moderate_screen_participant?(@call, @participant)}
          type="button"
          phx-click={@on_moderate_screen}
          phx-value-participant-id={@participant.id}
          class="flex h-10 w-10 items-center justify-center bg-surface shadow-retro-raised focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
          title={moderate_screen_title(@participant)}
          aria-label={moderate_screen_title(@participant)}
          data-testid={"group-call-participant-screen-moderate-#{@participant.id}"}
        >
          <CallControls.icon_call_screen_share class="h-8 w-8" />
        </button>
        <button
          :if={can_remove_participant?(@call, @participant)}
          type="button"
          phx-click={@on_kick_participant}
          phx-value-participant-id={@participant.id}
          class="flex h-10 w-10 items-center justify-center bg-destructive text-destructive-foreground shadow-retro-raised focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
          title={dgettext("group_call", "Remove from conference and ban from channel")}
          aria-label={dgettext("group_call", "Remove from conference and ban from channel")}
          data-testid={"group-call-participant-kick-#{@participant.id}"}
        >
          <Icons.icon_ban class="h-8 w-8" />
        </button>
      </div>
    </details>
    """
  end

  defp participant_media_indicator(assigns) do
    assigns =
      assigns
      |> assign(:enabled, participant_media?(assigns.participant, assigns.kind))
      |> assign(:moderated, participant_media_moderated?(assigns.participant, assigns.kind))

    ~H"""
    <span
      class={[
        "flex h-10 w-10 items-center justify-center shadow-retro-sunken",
        @enabled && "bg-surface",
        !@enabled && "bg-muted text-muted-foreground",
        @moderated && "bg-destructive text-destructive-foreground"
      ]}
      title={participant_media_title(@participant, @kind)}
      aria-label={participant_media_title(@participant, @kind)}
      data-group-call-participant-audio={@kind == :audio}
      data-group-call-participant-video={@kind == :video}
      data-group-call-participant-screen={@kind == :screen}
      data-media-enabled={to_string(@enabled)}
      data-media-moderated={to_string(@moderated)}
    >
      <CallControls.icon_call_microphone :if={@kind == :audio && @enabled} class="h-8 w-8" />
      <CallControls.icon_call_mute :if={@kind == :audio && !@enabled} class="h-8 w-8" />
      <CallControls.icon_call_camera :if={@kind == :video && @enabled} class="h-8 w-8" />
      <CallControls.icon_call_camera_off :if={@kind == :video && !@enabled} class="h-8 w-8" />
      <CallControls.icon_call_screen_share :if={@kind == :screen} class="h-8 w-8" />
    </span>
    """
  end

  defp call_error(assigns) do
    ~H"""
    <div
      :if={@call && @call.error}
      class="grid shrink-0 gap-1 border border-destructive bg-destructive/10 px-2 py-1 text-destructive"
      role="alert"
      aria-live="assertive"
      data-testid="group-call-error"
    >
      <div class="flex min-w-0 items-start gap-2">
        <Icons.icon_warning class="mt-[1px] h-8 w-8 shrink-0" />
        <div class="min-w-0">
          <div class="font-bold leading-4" data-testid="group-call-error-title">
            {dgettext("group_call", "Connection needs attention")}
          </div>
          <div class="min-w-0 truncate text-[10px] leading-3 text-foreground">
            {@call.error}
          </div>
        </div>
      </div>
      <div class="flex justify-end gap-1">
        <button
          :if={retry_available?(@call)}
          type="button"
          phx-click={@on_retry}
          class="flex h-10 shrink-0 items-center gap-1 bg-surface px-2 text-foreground shadow-retro-raised focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
          title={dgettext("group_call", "Retry media connection")}
          aria-label={dgettext("group_call", "Retry media connection")}
          data-testid="group-call-retry"
        >
          <Icons.icon_btn_refresh class="h-8 w-8" />
          <span class="text-[10px] font-bold">{dgettext("group_call", "Retry")}</span>
        </button>
        <button
          type="button"
          phx-click={@on_leave}
          class="flex h-10 shrink-0 items-center gap-1 bg-destructive px-2 text-destructive-foreground shadow-retro-raised focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
          title={dgettext("group_call", "Leave conference")}
          aria-label={dgettext("group_call", "Leave conference")}
          data-testid="group-call-leave-from-error"
        >
          <CallControls.icon_call_phone_end class="h-8 w-8" />
          <span class="text-[10px] font-bold">{dgettext("group_call", "Leave")}</span>
        </button>
      </div>
    </div>
    """
  end

  defp call_warning(assigns) do
    ~H"""
    <div
      :if={@call && @call.warning && !@call.error}
      class="flex shrink-0 items-center justify-between gap-2 border border-warning bg-warning-light px-2 py-1 text-foreground"
      role="status"
      aria-live="polite"
      data-testid="group-call-warning"
    >
      <div class="flex min-w-0 items-start gap-2">
        <Icons.icon_warning class="mt-[1px] h-8 w-8 shrink-0 text-warning" />
        <div class="min-w-0">
          <div class="font-bold leading-4" data-testid="group-call-warning-title">
            {dgettext("group_call", "Media warning")}
          </div>
          <div class="min-w-0 truncate text-[10px] leading-3 text-muted-foreground">
            {@call.warning}
          </div>
        </div>
      </div>
      <button
        type="button"
        phx-click={@on_leave}
        class="flex h-10 shrink-0 items-center gap-1 bg-surface px-2 text-foreground shadow-retro-raised focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
        title={dgettext("group_call", "Leave conference")}
        aria-label={dgettext("group_call", "Leave conference")}
        data-testid="group-call-leave-from-warning"
      >
        <CallControls.icon_call_phone_end class="h-8 w-8" />
        <span class="text-[10px] font-bold">{dgettext("group_call", "Leave")}</span>
      </button>
    </div>
    """
  end

  defp channel_name(nil), do: dgettext("group_call", "Group Call")
  defp channel_name(call), do: call.channel_name || dgettext("group_call", "Group Call")

  defp status_label(nil), do: dgettext("group_call", "Idle")
  defp status_label(%{status: :joining}), do: dgettext("group_call", "Joining call")
  defp status_label(%{status: :connecting}), do: dgettext("group_call", "Connecting media")
  defp status_label(%{status: :negotiating}), do: dgettext("group_call", "Negotiating media")
  defp status_label(%{status: :reconnecting}), do: dgettext("group_call", "Reconnecting media")
  defp status_label(%{status: :connected}), do: dgettext("group_call", "Connected")
  defp status_label(%{status: :error}), do: dgettext("group_call", "Connection error")
  defp status_label(_call), do: dgettext("group_call", "Group call")

  defp status_icon_class(%{status: :connected}), do: "text-primary"
  defp status_icon_class(%{status: :reconnecting}), do: "text-warning"
  defp status_icon_class(%{status: :error}), do: "text-destructive"
  defp status_icon_class(_call), do: "text-muted-foreground"

  defp main_grid_class(call) do
    classes([
      "grid min-h-0 flex-1 gap-1",
      sidebar_open?(call) && !mini_mode?(call) && "grid-cols-[minmax(0,1fr)_14rem]",
      (mini_mode?(call) || !sidebar_open?(call)) && "grid-cols-1"
    ])
  end

  defp workspace_class(call) do
    classes([
      "grid min-h-0 flex-1 gap-1",
      !mini_mode?(call) && "grid-cols-1 lg:grid-cols-[3.25rem_minmax(0,1fr)]",
      mini_mode?(call) && "grid-cols-1"
    ])
  end

  defp mini_mode?(%{layout: %{mini: true}}), do: true
  defp mini_mode?(_call), do: false

  defp sidebar_open?(%{layout: %{sidebar_open: false}}), do: false
  defp sidebar_open?(_call), do: true

  defp media_enabled?(%{media: media}, key), do: Map.get(media, key, true) == true
  defp media_enabled?(_call, _key), do: true

  defp participant_count(call), do: length(participants(call))
  defp participants(nil), do: []
  defp participants(%{participants: participants}), do: participants || []

  defp participant_quality(%{participant_quality: %{by_participant: by_participant}}, %{
         id: participant_id
       })
       when is_map(by_participant),
       do: Map.get(by_participant, participant_id)

  defp participant_quality(_call, _participant), do: nil

  defp active_speaker?(
         %{participant_quality: %{active_speaker_participant_id: participant_id}},
         %{id: participant_id}
       )
       when not is_nil(participant_id),
       do: true

  defp active_speaker?(_call, _participant), do: false

  defp latest_participant_reaction(%{reactions: reactions}, %{id: participant_id})
       when is_list(reactions) do
    Enum.find(reactions, &(&1.participant_id == participant_id))
  end

  defp latest_participant_reaction(_call, _participant), do: nil

  defp quality_level(%{level: level}) when is_atom(level), do: Atom.to_string(level)
  defp quality_level(%{level: level}) when is_binary(level), do: level
  defp quality_level(_quality), do: "unknown"

  defp pinned_participant?(%{layout: %{pinned_participant_ids: ids}}, %{id: participant_id})
       when is_list(ids),
       do: participant_id in ids

  defp pinned_participant?(_call, _participant), do: false

  defp retry_available?(%{recovery: %{manual_retry: true}}), do: true
  defp retry_available?(_call), do: false

  defp track_count(%{tracks: tracks}) when is_list(tracks), do: length(tracks)
  defp track_count(_call), do: 0

  defp locked?(%{room: %{metadata: metadata}}) when is_map(metadata) do
    Map.get(metadata, :locked) == true or Map.get(metadata, "locked") == true or
      Map.get(metadata, :admission_locked) == true or
      Map.get(metadata, "admission_locked") == true
  end

  defp locked?(_call), do: false

  defp lock_title(call) do
    if locked?(call),
      do: dgettext("group_call", "Unlock conference"),
      else: dgettext("group_call", "Lock conference")
  end

  defp hand_raised?(call) do
    case self_participant(call) do
      nil -> Map.get(call.media || %{}, :hand_raised) == true
      participant -> participant_hand_raised?(participant)
    end
  end

  defp hand_toggle_title(call) do
    if hand_raised?(call),
      do: dgettext("group_call", "Lower hand"),
      else: dgettext("group_call", "Raise hand")
  end

  defp raised_hand_participants(call) do
    call
    |> participants()
    |> Enum.filter(&participant_hand_raised?/1)
    |> Enum.sort_by(&hand_raised_sort_key/1)
  end

  defp hand_raised_sort_key(%{media_state: media}) when is_map(media) do
    to_string(Map.get(media, :hand_raised_at, Map.get(media, "hand_raised_at", "")))
  end

  defp hand_raised_sort_key(_participant), do: ""

  defp participant_status(%{status: "connected"}), do: dgettext("group_call", "Connected")
  defp participant_status(%{status: "joining"}), do: dgettext("group_call", "Joining")
  defp participant_status(%{status: "disconnected"}), do: dgettext("group_call", "Disconnected")
  defp participant_status(_participant), do: dgettext("group_call", "In call")

  defp participant_status_icon(%{status: "connected"}), do: :icon_status_signal
  defp participant_status_icon(%{status: "joining"}), do: :icon_btn_timers
  defp participant_status_icon(%{status: "disconnected"}), do: :icon_btn_disconnect
  defp participant_status_icon(_participant), do: :icon_webrtc

  defp participant_role_icon(%{channel_role_snapshot: "owner"}), do: :icon_role_owner
  defp participant_role_icon(%{channel_role_snapshot: "operator"}), do: :icon_role_operator
  defp participant_role_icon(%{channel_role_snapshot: "half_operator"}), do: :icon_role_halfop
  defp participant_role_icon(%{channel_role_snapshot: "voiced"}), do: :icon_role_voiced
  defp participant_role_icon(_participant), do: :icon_role_regular

  defp participant_media?(%{media_state: media}, key) when is_map(media) do
    case Map.get(media, key) do
      nil -> key != :screen
      value -> value == true
    end
  end

  defp participant_media?(_participant, :screen), do: false
  defp participant_media?(_participant, _key), do: true

  defp participant_hand_raised?(%{media_state: media}) when is_map(media),
    do: Map.get(media, :hand_raised, Map.get(media, "hand_raised")) == true

  defp participant_hand_raised?(_participant), do: false

  defp can_moderate_call?(call) do
    call
    |> self_participant()
    |> moderator_participant?()
  end

  defp can_moderate_participant?(%{participant_id: self_id}, %{id: participant_id})
       when self_id == participant_id,
       do: false

  defp can_moderate_participant?(call, participant) do
    call
    |> self_participant()
    |> can_moderate_target?(participant)
  end

  defp can_moderate_video_participant?(call, participant) do
    can_moderate_participant?(call, participant) and
      (participant_media?(participant, :video) or
         participant_media_moderated?(participant, :video))
  end

  defp can_moderate_screen_participant?(call, participant) do
    can_moderate_participant?(call, participant) and
      (participant_media?(participant, :screen) or
         participant_media_moderated?(participant, :screen))
  end

  defp can_remove_participant?(%{participant_id: self_id}, %{id: participant_id})
       when self_id == participant_id,
       do: false

  defp can_remove_participant?(call, participant) do
    call
    |> self_participant()
    |> can_ban_target?(participant)
  end

  defp self_participant(%{participant_id: participant_id, participants: participants} = call) do
    Enum.find(participants || [], &(&1.id == participant_id)) ||
      self_participant_fallback(call)
  end

  defp self_participant(_call), do: nil

  defp self_participant_fallback(%{participant_id: participant_id, self_role: role})
       when not is_nil(participant_id) and not is_nil(role),
       do: %{id: participant_id, channel_role_snapshot: role, media_state: %{}}

  defp self_participant_fallback(_call), do: nil

  defp moderator_participant?(%{channel_role_snapshot: role})
       when role in ["owner", "operator", "half_operator"],
       do: true

  defp moderator_participant?(_participant), do: false

  defp can_moderate_target?(%{channel_role_snapshot: actor_role}, %{
         channel_role_snapshot: target_role
       }) do
    with actor_rank when is_integer(actor_rank) <- role_rank(actor_role),
         target_rank when is_integer(target_rank) <- role_rank(target_role) do
      actor_rank >= role_rank("half_operator") and actor_rank > target_rank
    else
      _unknown_role -> false
    end
  end

  defp can_moderate_target?(_actor, _target), do: false

  defp can_ban_target?(%{channel_role_snapshot: actor_role}, %{channel_role_snapshot: target_role}) do
    with actor_rank when is_integer(actor_rank) <- role_rank(actor_role),
         target_rank when is_integer(target_rank) <- role_rank(target_role) do
      actor_role in ["owner", "operator"] and actor_rank > target_rank
    else
      _unknown_role -> false
    end
  end

  defp can_ban_target?(_actor, _target), do: false

  defp role_rank(role) when is_atom(role), do: role |> Atom.to_string() |> role_rank()
  defp role_rank("owner"), do: 4
  defp role_rank("operator"), do: 3
  defp role_rank("half_operator"), do: 2
  defp role_rank("voiced"), do: 1
  defp role_rank("regular"), do: 0
  defp role_rank("bot"), do: 0
  defp role_rank(_role), do: nil

  defp moderate_audio_title(participant) do
    cond do
      participant_media_moderated?(participant, :audio) ->
        dgettext("group_call", "Allow participant microphone")

      participant_media?(participant, :audio) ->
        dgettext("group_call", "Mute participant")

      true ->
        dgettext("group_call", "Unmute participant")
    end
  end

  defp moderate_video_title(participant) do
    if participant_media_moderated?(participant, :video),
      do: dgettext("group_call", "Allow participant camera"),
      else: dgettext("group_call", "Turn participant camera off")
  end

  defp moderate_screen_title(participant) do
    if participant_media_moderated?(participant, :screen),
      do: dgettext("group_call", "Allow participant screen sharing"),
      else: dgettext("group_call", "Stop participant screen sharing")
  end

  defp allow_speak_title(participant) do
    dgettext("group_call", "Allow %{nickname} to speak", nickname: participant.nickname)
  end

  defp participant_media_moderated?(%{media_state: media}, :audio) when is_map(media),
    do:
      Map.get(media, :server_audio_muted) == true or Map.get(media, "server_audio_muted") == true

  defp participant_media_moderated?(%{media_state: media}, :video) when is_map(media),
    do:
      Map.get(media, :server_video_blocked) == true or
        Map.get(media, "server_video_blocked") == true

  defp participant_media_moderated?(%{media_state: media}, :screen) when is_map(media),
    do:
      Map.get(media, :server_screen_blocked) == true or
        Map.get(media, "server_screen_blocked") == true

  defp participant_media_moderated?(_participant, _kind), do: false

  defp focused_participant?(%{layout: %{focused_participant_id: id}}, %{id: id})
       when not is_nil(id),
       do: true

  defp focused_participant?(_call, _participant), do: false

  defp focus_participant_title(call, participant) do
    if focused_participant?(call, participant),
      do: dgettext("group_call", "Focused participant"),
      else: dgettext("group_call", "Focus participant")
  end

  defp pin_participant_title(call, participant) do
    if pinned_participant?(call, participant),
      do: dgettext("group_call", "Unpin participant"),
      else: dgettext("group_call", "Pin participant")
  end

  defp participant_reaction_title(%{nickname: nickname, reaction: reaction}) do
    dgettext("group_call", "%{nickname} reacted with %{reaction}",
      nickname: nickname,
      reaction: reaction
    )
  end

  defp reaction_icon("heart"), do: :icon_call_reaction_heart
  defp reaction_icon("thumbs_up"), do: :icon_call_reaction_thumbs_up
  defp reaction_icon("clap"), do: :icon_call_reaction_clap
  defp reaction_icon("laugh"), do: :icon_call_reaction_laugh
  defp reaction_icon("wow"), do: :icon_call_reaction_sparkle
  defp reaction_icon(_reaction), do: :icon_call_reaction_sparkle

  defp participant_media_title(participant, :audio) do
    cond do
      participant_media_moderated?(participant, :audio) ->
        dgettext("group_call", "Microphone muted by moderator")

      participant_media?(participant, :audio) ->
        dgettext("group_call", "Microphone on")

      true ->
        dgettext("group_call", "Microphone off")
    end
  end

  defp participant_media_title(participant, :video) do
    cond do
      participant_media_moderated?(participant, :video) ->
        dgettext("group_call", "Camera disabled by moderator")

      participant_media?(participant, :video) ->
        dgettext("group_call", "Camera on")

      true ->
        dgettext("group_call", "Camera off")
    end
  end

  defp participant_media_title(participant, :screen) do
    cond do
      participant_media_moderated?(participant, :screen) ->
        dgettext("group_call", "Screen sharing disabled by moderator")

      participant_media?(participant, :screen) ->
        dgettext("group_call", "Sharing screen")

      true ->
        dgettext("group_call", "Not sharing screen")
    end
  end
end
