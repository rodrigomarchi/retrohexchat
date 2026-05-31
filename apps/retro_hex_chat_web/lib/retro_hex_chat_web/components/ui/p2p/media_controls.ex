defmodule RetroHexChatWeb.Components.UI.MediaControls do
  @moduledoc """
  Media controls component for the showcase design system.

  Composed from toolbar + button + badge primitives.
  Mute/unmute, camera on/off, end call controls.

  ## Usage

      <.media_controls muted={false} camera_on={true} />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Toolbar
  import RetroHexChatWeb.Components.UI.Badge

  alias RetroHexChatWeb.Icons

  @doc "Renders the media controls toolbar."
  attr :muted, :boolean, default: false
  attr :camera_on, :boolean, default: true
  attr :in_call, :boolean, default: true
  attr :on_mute_toggle, :any, default: nil, doc: "Mute/unmute toggle callback"
  attr :on_camera_toggle, :any, default: nil, doc: "Camera on/off toggle callback"
  attr :on_end_call, :any, default: nil, doc: "End call callback"
  attr :class, :string, default: nil
  attr :rest, :global

  @spec media_controls(map()) :: Phoenix.LiveView.Rendered.t()
  def media_controls(assigns) do
    ~H"""
    <.toolbar
      class={classes(["gap-retro-4 p-retro-4 justify-center", @class])}
      data-testid="media-controls"
      {@rest}
    >
      <%!-- Mute/Unmute --%>
      <.toolbar_button
        label={if @muted, do: dgettext("p2p", "Unmute"), else: dgettext("p2p", "Mute")}
        active={@muted}
        phx-click={@on_mute_toggle}
        data-testid="media-controls-mute"
      >
        <Icons.icon_mute :if={@muted} class="w-4 h-4" />
        <Icons.icon_microphone :if={!@muted} class="w-4 h-4" />
      </.toolbar_button>

      <%!-- Camera --%>
      <.toolbar_button
        label={if @camera_on, do: dgettext("p2p", "Camera Off"), else: dgettext("p2p", "Camera On")}
        active={!@camera_on}
        phx-click={@on_camera_toggle}
        data-testid="media-controls-camera"
      >
        <Icons.icon_camera :if={@camera_on} class="w-4 h-4" />
        <Icons.icon_camera_off :if={!@camera_on} class="w-4 h-4" />
      </.toolbar_button>

      <.toolbar_separator />

      <%!-- End call --%>
      <.toolbar_button
        :if={@in_call}
        label={dgettext("p2p", "End Call")}
        phx-click={@on_end_call}
        data-testid="media-controls-end-call"
      >
        <Icons.icon_phone_end class="w-4 h-4" />
      </.toolbar_button>

      <%!-- Status badge --%>
      <.badge :if={@in_call} variant="default" class="text-[10px]">
        {dgettext("p2p", "In Call")}
      </.badge>
    </.toolbar>
    """
  end
end
