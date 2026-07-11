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
      data-audio={media_enabled?(@call, :audio)}
      data-video={media_enabled?(@call, :video)}
      data-layout-mode={layout_mode(@call)}
      data-focused-participant-id={focused_participant_id(@call)}
      data-self-view={self_view(@call)}
      data-sidebar-open={sidebar_open?(@call)}
      class="group-call-room min-h-0"
      data-testid="group-call-webrtc"
    >
      <div
        class="group-call-video-surface"
        data-group-call-video-grid
        data-group-call-remote-videos
        data-testid="group-call-video-grid"
      >
        <div
          class="group-call-empty-tile"
          data-group-call-remote-placeholder
          data-testid="group-call-remote-placeholder"
        >
          <Icons.icon_conference class="h-5 w-5 shrink-0" />
          <span>{dgettext("group_call", "Waiting for remote video")}</span>
        </div>

        <div
          class="group-call-video-tile group-call-video-tile--local"
          data-group-call-video-tile
          data-group-call-local-tile
          data-participant-id={@call.participant_id}
          data-local="true"
          data-media-audio={media_enabled?(@call, :audio)}
          data-media-video={media_enabled?(@call, :video)}
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

          <div class="group-call-video-tile__nameplate">
            <span class="truncate font-bold" data-group-call-local-name>{@call.nickname}</span>
            <span class="group-call-video-tile__badges">
              <span class="group-call-video-badge" data-group-call-local-audio-badge>
                <Icons.icon_microphone class="h-3 w-3" />
              </span>
              <span class="group-call-video-badge" data-group-call-local-video-badge>
                <Icons.icon_camera class="h-3 w-3" />
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
              </span>
            </div>
          </div>
        </template>
      </div>
    </div>
    """
  end

  defp layout_mode(%{layout: %{mode: mode}}) when mode in [:auto, :grid, :focus, :sidebar],
    do: mode

  defp layout_mode(_call), do: :auto

  defp focused_participant_id(%{layout: %{focused_participant_id: id}}), do: id
  defp focused_participant_id(_call), do: nil

  defp self_view(%{layout: %{self_view: mode}}) when mode in [:tile, :pip, :hidden], do: mode
  defp self_view(_call), do: :tile

  defp sidebar_open?(%{layout: %{sidebar_open: false}}), do: false
  defp sidebar_open?(_call), do: true

  defp media_enabled?(%{media: media}, key), do: Map.get(media, key, true) == true
  defp media_enabled?(_call, _key), do: true
end
