defmodule RetroHexChatWeb.Components.UI.GroupCall.VideoSurface do
  @moduledoc """
  Stable WebRTC surface for the group-call conference window.

  The LiveView renders the static structure and initial view state. The
  GroupCallWebRTCHook owns the video elements inside the ignored subtree so
  layout changes do not recreate media streams.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  attr :call, :map, default: nil

  @spec video_surface(map()) :: Phoenix.LiveView.Rendered.t()
  def video_surface(assigns) do
    ~H"""
    <div
      :if={@call}
      id={"group-call-webrtc-#{@call.token}"}
      phx-hook="GroupCallWebRTCHook"
      phx-update="ignore"
      data-group-call-token={@call.token}
      data-join-token={@call.join_token}
      data-audio={to_string(media_enabled?(@call, :audio))}
      data-video={to_string(media_enabled?(@call, :video))}
      data-audio-input-id={device_preference(@call, :audio_input_id)}
      data-video-input-id={device_preference(@call, :video_input_id)}
      data-audio-output-id={device_preference(@call, :audio_output_id)}
      data-layout-mode={layout_mode(@call)}
      data-focused-participant-id={focused_participant_id(@call)}
      data-pinned-participant-ids={pinned_participant_ids(@call)}
      data-self-view={self_view(@call)}
      data-sidebar-open={sidebar_open?(@call)}
      class="group-call-room min-h-0"
      role="region"
      aria-label={dgettext("group_call", "Conference media")}
      data-testid="group-call-webrtc"
    >
      <div
        class="group-call-video-surface"
        role="group"
        aria-label={dgettext("group_call", "Conference video tiles")}
        data-group-call-video-grid
        data-group-call-remote-videos
        data-testid="group-call-video-grid"
      >
        <div
          class="group-call-empty-tile"
          role="status"
          aria-live="polite"
          data-group-call-remote-placeholder
          data-testid="group-call-remote-placeholder"
        >
          <Icons.icon_protocol_conference_compact class="h-6 w-6 shrink-0 text-primary" />
          <span class="font-bold text-foreground">
            {dgettext("group_call", "Waiting for participants")}
          </span>
          <span class="max-w-[18rem] text-[10px] leading-3 text-muted-foreground">
            {dgettext(
              "group_call",
              "Remote cameras and shared screens appear here as people join."
            )}
          </span>
        </div>

        <div
          class="group-call-video-tile group-call-video-tile--local"
          data-group-call-video-tile
          data-group-call-local-tile
          data-participant-id={@call.participant_id}
          data-local="true"
          data-media-audio={media_enabled?(@call, :audio)}
          data-media-video={media_enabled?(@call, :video)}
          data-media-screen={media_enabled?(@call, :screen)}
          data-track-source="camera"
          data-active-speaker="false"
          data-quality-level="unknown"
          data-pinned="false"
          role="button"
          tabindex="0"
          aria-label={dgettext("group_call", "Focus your video")}
          title={dgettext("group_call", "Focus your video")}
          data-testid="group-call-local-tile"
        >
          <video
            data-group-call-local-video
            autoplay
            muted
            playsinline
            class="group-call-video-tile__video"
            data-testid="group-call-local-video"
          >
          </video>

          <div
            class="group-call-video-tile__empty"
            role="status"
            aria-live="polite"
            data-group-call-local-empty
            data-testid="group-call-local-empty"
          >
            <Icons.icon_camera_off class="h-6 w-6 shrink-0" />
            <span class="font-bold" data-group-call-local-empty-title>
              {local_empty_title(@call)}
            </span>
            <span class="text-[10px] leading-3" data-group-call-local-empty-detail>
              {local_empty_detail(@call)}
            </span>
          </div>

          <div class="group-call-video-tile__nameplate">
            <span class="truncate font-bold" data-group-call-local-name>{@call.nickname}</span>
            <span class="group-call-video-tile__badges">
              <span class="group-call-video-badge" data-group-call-local-audio-badge>
                <Icons.icon_microphone class="h-3 w-3" />
              </span>
              <span class="group-call-video-badge" data-group-call-local-video-badge>
                <Icons.icon_camera class="h-3 w-3" />
              </span>
              <span class="group-call-video-badge" data-group-call-local-screen-badge>
                <Icons.icon_screen_share class="h-3 w-3" />
              </span>
            </span>
          </div>
        </div>

        <template data-group-call-remote-tile-template>
          <div
            class="group-call-video-tile group-call-video-tile--remote"
            data-group-call-video-tile
            data-media-audio="true"
            data-media-video="true"
            data-media-screen="false"
            data-track-source="camera"
            data-active-speaker="false"
            data-quality-level="unknown"
            data-pinned="false"
            data-local="false"
            role="button"
            tabindex="0"
          >
            <div class="group-call-video-tile__nameplate">
              <span class="inline-flex min-w-0 items-center gap-1 truncate font-bold">
                <Icons.icon_status_user class="h-3 w-3 shrink-0" />
                <span class="truncate" data-group-call-tile-name>
                  {dgettext("group_call", "Remote")}
                </span>
              </span>
              <span class="group-call-video-tile__badges">
                <span
                  class="group-call-video-badge"
                  data-group-call-audio-badge
                  title={dgettext("group_call", "Remote microphone")}
                  aria-label={dgettext("group_call", "Remote microphone")}
                >
                  <Icons.icon_microphone class="h-3 w-3" />
                </span>
                <span
                  class="group-call-video-badge"
                  data-group-call-video-badge
                  title={dgettext("group_call", "Remote camera")}
                  aria-label={dgettext("group_call", "Remote camera")}
                >
                  <Icons.icon_camera class="h-3 w-3" />
                </span>
                <span
                  class="group-call-video-badge"
                  data-group-call-screen-badge
                  title={dgettext("group_call", "Remote screen share")}
                  aria-label={dgettext("group_call", "Remote screen share")}
                >
                  <Icons.icon_screen_share class="h-3 w-3" />
                </span>
                <span
                  class="group-call-video-badge"
                  data-group-call-active-speaker-badge
                  title={dgettext("group_call", "Not speaking")}
                  aria-label={dgettext("group_call", "Not speaking")}
                >
                  <Icons.icon_microphone class="h-3 w-3" />
                </span>
                <span
                  class="group-call-video-badge"
                  data-group-call-quality-badge
                  data-quality-level="unknown"
                  hidden
                  title={dgettext("group_call", "Quality unknown")}
                  aria-label={dgettext("group_call", "Quality unknown")}
                >
                  <span data-quality-icon="high"><Icons.icon_quality_high class="h-3 w-3" /></span>
                  <span data-quality-icon="medium">
                    <Icons.icon_quality_medium class="h-3 w-3" />
                  </span>
                  <span data-quality-icon="low"><Icons.icon_quality_low class="h-3 w-3" /></span>
                  <span data-quality-icon="reconnecting">
                    <Icons.icon_btn_timers class="h-3 w-3" />
                  </span>
                  <span data-quality-icon="unknown"><Icons.icon_warning class="h-3 w-3" /></span>
                </span>
              </span>
            </div>
          </div>
        </template>

        <template data-group-call-reaction-icon-template="heart">
          <span class="inline-flex items-center justify-center" aria-hidden="true">
            <Icons.icon_heart class="h-4 w-4" />
          </span>
        </template>
        <template data-group-call-reaction-icon-template="thumbs_up">
          <span class="inline-flex items-center justify-center" aria-hidden="true">
            <Icons.icon_thumbs_up class="h-4 w-4" />
          </span>
        </template>
        <template data-group-call-reaction-icon-template="clap">
          <span class="inline-flex items-center justify-center" aria-hidden="true">
            <Icons.icon_clap class="h-4 w-4" />
          </span>
        </template>
        <template data-group-call-reaction-icon-template="laugh">
          <span class="inline-flex items-center justify-center" aria-hidden="true">
            <Icons.icon_laugh class="h-4 w-4" />
          </span>
        </template>
        <template data-group-call-reaction-icon-template="wow">
          <span class="inline-flex items-center justify-center" aria-hidden="true">
            <Icons.icon_sparkle class="h-4 w-4" />
          </span>
        </template>
      </div>
    </div>
    """
  end

  defp layout_mode(%{layout: %{mode: mode}})
       when mode in [:auto, :grid, :focus, :sidebar, :speaker],
       do: mode

  defp layout_mode(_call), do: :auto

  defp focused_participant_id(%{layout: %{focused_participant_id: id}}), do: id
  defp focused_participant_id(_call), do: nil

  defp pinned_participant_ids(%{layout: %{pinned_participant_ids: ids}}) when is_list(ids) do
    Enum.join(ids, ",")
  end

  defp pinned_participant_ids(_call), do: ""

  defp self_view(%{layout: %{self_view: mode}}) when mode in [:tile, :pip, :hidden], do: mode
  defp self_view(_call), do: :tile

  defp sidebar_open?(%{layout: %{sidebar_open: false}}), do: false
  defp sidebar_open?(_call), do: true

  defp media_enabled?(%{media: media}, :screen), do: Map.get(media, :screen, false) == true
  defp media_enabled?(%{media: media}, key), do: Map.get(media, key, true) == true
  defp media_enabled?(_call, :screen), do: false
  defp media_enabled?(_call, _key), do: true

  defp local_empty_title(call) do
    cond do
      media_enabled?(call, :screen) ->
        dgettext("group_call", "Sharing screen")

      !media_enabled?(call, :audio) && !media_enabled?(call, :video) ->
        dgettext("group_call", "Receive-only mode")

      !media_enabled?(call, :video) ->
        dgettext("group_call", "Camera off")

      true ->
        dgettext("group_call", "Camera preview starting")
    end
  end

  defp local_empty_detail(call) do
    cond do
      media_enabled?(call, :screen) ->
        dgettext("group_call", "Your screen is replacing the camera feed.")

      !media_enabled?(call, :audio) && !media_enabled?(call, :video) ->
        dgettext("group_call", "Your microphone and camera are off.")

      !media_enabled?(call, :video) ->
        dgettext("group_call", "Your camera is not being sent.")

      true ->
        dgettext("group_call", "Your local preview appears here when the camera is ready.")
    end
  end

  defp device_preference(%{device_preferences: preferences}, key) when is_map(preferences) do
    Map.get(preferences, key) || ""
  end

  defp device_preference(_call, _key), do: ""
end
