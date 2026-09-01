defmodule RetroHexChatWeb.Components.UI.GroupCall.MediaPreview do
  @moduledoc """
  Camera preview and device permission status for the channel conference pre-join flow.

  The device-state line, the empty-preview overlay and the permission notice
  are written by the browser controller and carry `phx-update="ignore"`: the
  section re-renders whenever the media defaults change, and a patch without
  that flag restores the template over whatever the controller had just said.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Components.UI.GroupCall.PermissionNotice
  alias RetroHexChatWeb.Icons

  attr :media, :map, required: true
  attr :prejoin, :map, default: nil
  attr :device_preferences, :map, required: true

  @spec media_preview(map()) :: Phoenix.LiveView.Rendered.t()
  def media_preview(assigns) do
    ~H"""
    <section
      id="group-call-prejoin-preview"
      phx-hook="GroupCallPreJoinHook"
      data-audio={to_string(media_enabled?(@media, :audio))}
      data-video={to_string(media_enabled?(@media, :video))}
      data-audio-input-id={device_preference(@device_preferences, :audio_input_id)}
      data-video-input-id={device_preference(@device_preferences, :video_input_id)}
      data-audio-output-id={device_preference(@device_preferences, :audio_output_id)}
      class="flex min-h-[170px] flex-col border border-border bg-canvas p-1 shadow-retro-sunken"
      data-testid="group-call-prejoin-preview"
    >
      <div class="mb-1 flex items-center justify-between gap-2 text-xs">
        <span class="inline-flex min-w-0 items-center gap-1 font-bold">
          <Icons.icon_camera class="h-3.5 w-3.5 shrink-0" />
          <span class="truncate">{dgettext("group_call", "Preview")}</span>
        </span>
        <span
          id="group-call-prejoin-device-state"
          phx-update="ignore"
          class="inline-flex items-center gap-1 text-muted-foreground"
          data-group-call-prejoin-device-state
        >
          <Icons.icon_devices class="h-3 w-3" />
          <span data-group-call-prejoin-device-state-text>
            {dgettext("group_call", "Checking devices")}
          </span>
        </span>
      </div>

      <div class="relative flex min-h-0 flex-1 items-center justify-center bg-black">
        <video
          data-group-call-prejoin-video
          autoplay
          muted
          playsinline
          class="h-full max-h-[150px] w-full object-contain"
          data-testid="group-call-prejoin-video"
        >
        </video>
        <div
          id="group-call-prejoin-empty"
          phx-update="ignore"
          class="absolute inset-0 flex flex-col items-center justify-center gap-1 bg-canvas text-center text-xs text-muted-foreground"
          data-group-call-prejoin-empty
          data-testid="group-call-prejoin-empty"
        >
          <Icons.icon_camera_off class="h-5 w-5" />
          <span data-group-call-prejoin-empty-text>
            {dgettext("group_call", "Camera preview is off")}
          </span>
        </div>
      </div>

      <PermissionNotice.permission_notice />
    </section>
    """
  end

  defp media_enabled?(media, key), do: Map.get(media, key, true) == true

  defp device_preference(preferences, key), do: Map.get(preferences, key) || ""
end
