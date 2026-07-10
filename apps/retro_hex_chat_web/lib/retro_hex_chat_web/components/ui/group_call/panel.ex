defmodule RetroHexChatWeb.Components.UI.GroupCall.Panel do
  @moduledoc """
  Presentation component for the channel group-call window body.

  The ChatLive live component owns runtime state and events; this module owns the
  reusable visual surface and keeps group-call markup in the UI component layer.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :call, :map, default: nil
  attr :on_close_room, :any, default: "group_call_close_room"
  attr :on_toggle_audio, :any, default: "group_call_toggle_audio"
  attr :on_toggle_video, :any, default: "group_call_toggle_video"
  attr :on_leave, :any, default: "group_call_leave"
  attr :on_moderate_audio, :any, default: "group_call_moderate_audio"
  attr :on_kick_participant, :any, default: "group_call_kick_participant"

  @spec group_call_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def group_call_panel(assigns) do
    ~H"""
    <div id={@id} class="flex h-full min-h-0 flex-col gap-1 text-xs" data-testid="group-call-panel">
      <.call_header
        call={@call}
        on_close_room={@on_close_room}
        on_toggle_audio={@on_toggle_audio}
        on_toggle_video={@on_toggle_video}
        on_leave={@on_leave}
      />

      <div class="grid min-h-0 flex-1 grid-cols-[minmax(0,1fr)_12rem] gap-1">
        <.webrtc_surface call={@call} />
        <.participant_list
          call={@call}
          on_moderate_audio={@on_moderate_audio}
          on_kick_participant={@on_kick_participant}
        />
      </div>

      <.call_error call={@call} />
      <.call_warning call={@call} />
    </div>
    """
  end

  defp call_header(assigns) do
    ~H"""
    <div class="flex h-8 shrink-0 items-center justify-between gap-2 border border-border bg-surface px-2 shadow-retro-sunken">
      <div class="flex min-w-0 items-center gap-2">
        <Icons.icon_camera class="h-4 w-4 shrink-0" />
        <div class="min-w-0">
          <div class="truncate font-bold leading-4">{channel_name(@call)}</div>
          <div class="flex min-w-0 items-center gap-2 text-[10px] leading-3 text-muted-foreground">
            <span class="inline-flex min-w-0 items-center gap-1 truncate">
              <Icons.icon_status_signal class={["h-3 w-3 shrink-0", status_icon_class(@call)]} />
              <span class="truncate">{status_label(@call)}</span>
            </span>
            <span class="inline-flex items-center gap-1">
              <Icons.icon_status_user class="h-3 w-3 shrink-0" />
              {participant_count(@call)}
            </span>
            <span class="inline-flex items-center gap-1">
              <Icons.icon_camera class="h-3 w-3 shrink-0" />
              {track_count(@call)}
            </span>
          </div>
        </div>
      </div>

      <div class="flex shrink-0 items-center gap-px">
        <button
          :if={can_moderate_call?(@call)}
          type="button"
          phx-click={@on_close_room}
          class={[
            "mr-1 flex h-6 w-7 items-center justify-center bg-destructive text-destructive-foreground shadow-retro-raised",
            "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
          ]}
          aria-label={dgettext("chat", "End group call")}
          title={dgettext("chat", "End group call")}
          data-testid="group-call-close-room"
        >
          <Icons.icon_ban class="h-3.5 w-3.5" />
        </button>
        <button
          type="button"
          phx-click={@on_toggle_audio}
          class={[
            "flex h-6 w-7 items-center justify-center bg-surface shadow-retro-raised",
            "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground",
            !media_enabled?(@call, :audio) && "bg-muted shadow-retro-sunken"
          ]}
          aria-label={dgettext("chat", "Toggle microphone")}
          title={dgettext("chat", "Toggle microphone")}
          aria-pressed={to_string(media_enabled?(@call, :audio))}
          data-testid="group-call-audio-toggle"
        >
          <Icons.icon_microphone :if={media_enabled?(@call, :audio)} class="h-3.5 w-3.5" />
          <Icons.icon_mute :if={!media_enabled?(@call, :audio)} class="h-3.5 w-3.5" />
        </button>
        <button
          type="button"
          phx-click={@on_toggle_video}
          class={[
            "flex h-6 w-7 items-center justify-center bg-surface shadow-retro-raised",
            "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground",
            !media_enabled?(@call, :video) && "bg-muted shadow-retro-sunken"
          ]}
          aria-label={dgettext("chat", "Toggle camera")}
          title={dgettext("chat", "Toggle camera")}
          aria-pressed={to_string(media_enabled?(@call, :video))}
          data-testid="group-call-video-toggle"
        >
          <Icons.icon_camera :if={media_enabled?(@call, :video)} class="h-3.5 w-3.5" />
          <Icons.icon_camera_off :if={!media_enabled?(@call, :video)} class="h-3.5 w-3.5" />
        </button>
        <button
          type="button"
          phx-click={@on_leave}
          class={[
            "ml-1 flex h-6 w-7 items-center justify-center bg-destructive text-destructive-foreground shadow-retro-raised",
            "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
          ]}
          aria-label={dgettext("chat", "Leave group call")}
          title={dgettext("chat", "Leave group call")}
          data-testid="group-call-leave"
        >
          <Icons.icon_phone_end class="h-3.5 w-3.5" />
        </button>
      </div>
    </div>
    """
  end

  defp webrtc_surface(assigns) do
    ~H"""
    <div
      :if={@call}
      id={"group-call-webrtc-#{@call.token}"}
      phx-hook="GroupCallWebRTCHook"
      phx-update="ignore"
      data-group-call-token={@call.token}
      data-join-token={@call.join_token}
      data-audio={media_enabled?(@call, :audio)}
      data-video={media_enabled?(@call, :video)}
      class="grid min-h-0 grid-rows-[minmax(0,1fr)_5.5rem] gap-1"
      data-testid="group-call-webrtc"
    >
      <div
        class="relative grid min-h-0 grid-cols-1 gap-1 overflow-hidden border border-border bg-canvas p-1 shadow-retro-sunken md:grid-cols-2"
        data-group-call-remote-videos
        data-testid="group-call-remote-videos"
      >
        <div
          class="pointer-events-none absolute inset-0 flex items-center justify-center px-3 text-center text-muted-foreground"
          data-group-call-remote-placeholder
        >
          {dgettext("chat", "Waiting for remote video")}
        </div>
      </div>

      <div class="grid min-h-0 grid-cols-[7rem_minmax(0,1fr)] gap-1">
        <video
          data-group-call-local-video
          autoplay
          muted
          playsinline
          class="h-full w-full border border-border bg-black object-cover shadow-retro-sunken"
          data-testid="group-call-local-video"
        >
        </video>
        <.local_media_summary call={@call} />
      </div>
    </div>
    """
  end

  defp local_media_summary(assigns) do
    ~H"""
    <div class="min-h-0 border border-border bg-surface p-2 shadow-retro-sunken">
      <div class="truncate font-bold">{@call && @call.nickname}</div>
      <div class="mt-1 flex flex-wrap gap-1 text-[10px] text-muted-foreground">
        <.media_badge enabled={media_enabled?(@call, :audio)} kind={:audio} />
        <.media_badge enabled={media_enabled?(@call, :video)} kind={:video} />
      </div>
    </div>
    """
  end

  defp media_badge(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1 bg-canvas px-1 shadow-retro-sunken">
      <Icons.icon_microphone :if={@kind == :audio && @enabled} class="h-3 w-3" />
      <Icons.icon_mute :if={@kind == :audio && !@enabled} class="h-3 w-3" />
      <Icons.icon_camera :if={@kind == :video && @enabled} class="h-3 w-3" />
      <Icons.icon_camera_off :if={@kind == :video && !@enabled} class="h-3 w-3" />
      {media_badge_label(@kind, @enabled)}
    </span>
    """
  end

  defp participant_list(assigns) do
    ~H"""
    <div class="flex min-h-0 flex-col border border-border bg-surface shadow-retro-sunken">
      <div class="flex h-7 shrink-0 items-center justify-between border-b border-border px-2">
        <span class="font-bold">{dgettext("chat", "Participants")}</span>
        <span class="text-muted-foreground">{participant_count(@call)}</span>
      </div>

      <div class="min-h-0 flex-1 overflow-auto p-1" data-testid="group-call-participants">
        <div :if={participant_count(@call) == 0} class="px-1 py-2 text-center text-muted-foreground">
          {dgettext("chat", "Joining...")}
        </div>

        <.participant_row
          :for={participant <- participants(@call)}
          call={@call}
          participant={participant}
          on_moderate_audio={@on_moderate_audio}
          on_kick_participant={@on_kick_participant}
        />
      </div>
    </div>
    """
  end

  defp participant_row(assigns) do
    ~H"""
    <div
      class="mb-1 grid grid-cols-[1fr_auto] gap-1 border border-border bg-canvas px-1.5 py-1"
      data-testid={"group-call-participant-#{@participant.id}"}
      data-group-call-participant
      data-group-call-participant-nickname={@participant.nickname}
      data-media-audio={to_string(participant_media?(@participant, :audio))}
      data-media-video={to_string(participant_media?(@participant, :video))}
    >
      <div class="min-w-0">
        <div class="truncate font-bold">{@participant.nickname}</div>
        <div class="truncate text-[10px] text-muted-foreground">
          {participant_status(@participant)}
        </div>
      </div>
      <div class="flex items-center gap-px">
        <button
          :if={can_moderate_participant?(@call, @participant)}
          type="button"
          phx-click={@on_moderate_audio}
          phx-value-participant-id={@participant.id}
          class="flex h-5 w-5 items-center justify-center bg-surface shadow-retro-raised focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
          title={moderate_audio_title(@participant)}
          aria-label={moderate_audio_title(@participant)}
          data-testid={"group-call-participant-audio-moderate-#{@participant.id}"}
        >
          <Icons.icon_mute :if={participant_media?(@participant, :audio)} class="h-3 w-3" />
          <Icons.icon_microphone :if={!participant_media?(@participant, :audio)} class="h-3 w-3" />
        </button>
        <button
          :if={can_moderate_participant?(@call, @participant)}
          type="button"
          phx-click={@on_kick_participant}
          phx-value-participant-id={@participant.id}
          class="flex h-5 w-5 items-center justify-center bg-destructive text-destructive-foreground shadow-retro-raised focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground"
          title={dgettext("chat", "Remove from call")}
          aria-label={dgettext("chat", "Remove from call")}
          data-testid={"group-call-participant-kick-#{@participant.id}"}
        >
          <Icons.icon_btn_remove class="h-3 w-3" />
        </button>
        <.participant_media_indicator participant={@participant} kind={:audio} />
        <.participant_media_indicator participant={@participant} kind={:video} />
      </div>
    </div>
    """
  end

  defp participant_media_indicator(assigns) do
    assigns = assign(assigns, :enabled, participant_media?(assigns.participant, assigns.kind))

    ~H"""
    <span
      class={[
        "flex h-5 w-5 items-center justify-center shadow-retro-sunken",
        @enabled && "bg-surface",
        !@enabled && "bg-muted text-muted-foreground"
      ]}
      title={participant_media_title(@participant, @kind)}
      aria-label={participant_media_title(@participant, @kind)}
      data-group-call-participant-audio={@kind == :audio}
      data-group-call-participant-video={@kind == :video}
      data-media-enabled={to_string(@enabled)}
    >
      <Icons.icon_microphone :if={@kind == :audio && @enabled} class="h-3 w-3" />
      <Icons.icon_mute :if={@kind == :audio && !@enabled} class="h-3 w-3" />
      <Icons.icon_camera :if={@kind == :video && @enabled} class="h-3 w-3" />
      <Icons.icon_camera_off :if={@kind == :video && !@enabled} class="h-3 w-3" />
    </span>
    """
  end

  defp call_error(assigns) do
    ~H"""
    <div
      :if={@call && @call.error}
      class="shrink-0 border border-destructive bg-destructive/10 px-2 py-1 text-destructive"
      data-testid="group-call-error"
    >
      {@call.error}
    </div>
    """
  end

  defp call_warning(assigns) do
    ~H"""
    <div
      :if={@call && @call.warning && !@call.error}
      class="flex shrink-0 items-center gap-1 border border-warning bg-warning-light px-2 py-1 text-foreground"
      data-testid="group-call-warning"
    >
      <Icons.icon_warning class="h-3 w-3 shrink-0" />
      <span class="min-w-0 truncate">{@call.warning}</span>
    </div>
    """
  end

  defp media_badge_label(:audio, true), do: dgettext("chat", "Mic on")
  defp media_badge_label(:audio, false), do: dgettext("chat", "Mic off")
  defp media_badge_label(:video, true), do: dgettext("chat", "Camera on")
  defp media_badge_label(:video, false), do: dgettext("chat", "Camera off")

  defp channel_name(nil), do: dgettext("chat", "Group Call")
  defp channel_name(call), do: call.channel_name || dgettext("chat", "Group Call")

  defp status_label(nil), do: dgettext("chat", "Idle")
  defp status_label(%{status: :joining}), do: dgettext("chat", "Joining call")
  defp status_label(%{status: :connecting}), do: dgettext("chat", "Connecting media")
  defp status_label(%{status: :negotiating}), do: dgettext("chat", "Negotiating media")
  defp status_label(%{status: :connected}), do: dgettext("chat", "Connected")
  defp status_label(%{status: :error}), do: dgettext("chat", "Connection error")
  defp status_label(_call), do: dgettext("chat", "Group call")

  defp status_icon_class(%{status: :connected}), do: "text-primary"
  defp status_icon_class(%{status: :error}), do: "text-destructive"
  defp status_icon_class(_call), do: "text-muted-foreground"

  defp media_enabled?(%{media: media}, key), do: Map.get(media, key, true) == true
  defp media_enabled?(_call, _key), do: true

  defp participant_count(call), do: length(participants(call))
  defp participants(nil), do: []
  defp participants(%{participants: participants}), do: participants || []

  defp track_count(%{tracks: tracks}) when is_list(tracks), do: length(tracks)
  defp track_count(_call), do: 0

  defp participant_status(%{status: "connected"}), do: dgettext("chat", "Connected")
  defp participant_status(%{status: "joining"}), do: dgettext("chat", "Joining")
  defp participant_status(%{status: "disconnected"}), do: dgettext("chat", "Disconnected")
  defp participant_status(_participant), do: dgettext("chat", "In call")

  defp participant_media?(%{media_state: media}, key) when is_map(media) do
    case Map.get(media, key) do
      nil -> true
      value -> value == true
    end
  end

  defp participant_media?(_participant, _key), do: true

  defp can_moderate_call?(call) do
    call
    |> self_participant()
    |> moderator_participant?()
  end

  defp can_moderate_participant?(%{participant_id: self_id}, %{id: participant_id})
       when self_id == participant_id,
       do: false

  defp can_moderate_participant?(call, _participant) do
    call
    |> self_participant()
    |> moderator_participant?()
  end

  defp self_participant(%{participant_id: participant_id, participants: participants}) do
    Enum.find(participants || [], &(&1.id == participant_id))
  end

  defp self_participant(_call), do: nil

  defp moderator_participant?(%{channel_role_snapshot: role})
       when role in ["owner", "operator", "half_operator"],
       do: true

  defp moderator_participant?(_participant), do: false

  defp moderate_audio_title(participant) do
    if participant_media?(participant, :audio),
      do: dgettext("chat", "Mute participant"),
      else: dgettext("chat", "Unmute participant")
  end

  defp participant_media_title(participant, :audio) do
    if participant_media?(participant, :audio),
      do: dgettext("chat", "Microphone on"),
      else: dgettext("chat", "Microphone off")
  end

  defp participant_media_title(participant, :video) do
    if participant_media?(participant, :video),
      do: dgettext("chat", "Camera on"),
      else: dgettext("chat", "Camera off")
  end
end
