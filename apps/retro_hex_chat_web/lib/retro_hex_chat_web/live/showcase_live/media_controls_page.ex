defmodule RetroHexChatWeb.ShowcaseLive.MediaControlsPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.MediaControls
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Media Controls", active_page: "media-controls")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Media Controls</h2>

      <.showcase_card title="Default" description="All controls active, mic and camera on.">
        <.media_controls />
        <.code_example>
          &lt;.media_controls muted={false} camera_on={true} /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="Muted" description="Microphone muted.">
        <.media_controls muted={true} />
      </.showcase_card>

      <.showcase_card title="Camera Off" description="Camera disabled.">
        <.media_controls camera_on={false} />
      </.showcase_card>

      <.showcase_card title="Muted + Camera Off" description="Both muted and camera off.">
        <.media_controls muted={true} camera_on={false} />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
