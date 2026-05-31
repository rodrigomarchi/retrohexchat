defmodule RetroHexChatWeb.ShowcaseLive.P2P.MediaControlsPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.MediaControls
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Media Controls"),
       active_page: "media-controls"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Media Controls")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Default (In Call)")}
        description="All controls active, mic and camera on."
      >
        <.media_controls />
        <.code_example>
          &lt;.media_controls muted=&#123;false&#125; camera_on=&#123;true&#125; in_call=&#123;true&#125; /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title={dgettext("showcase", "Muted")} description="Microphone muted.">
        <.media_controls muted={true} />
      </.showcase_card>

      <.showcase_card title={dgettext("showcase", "Camera Off")} description="Camera disabled.">
        <.media_controls camera_on={false} />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Muted + Camera Off")}
        description="Both muted and camera off."
      >
        <.media_controls muted={true} camera_on={false} />
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Not In Call")}
        description="Controls shown when not actively in a call. End Call button and badge are hidden."
      >
        <.media_controls in_call={false} />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
