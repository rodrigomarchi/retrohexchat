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
  attr :class, :string, default: nil
  attr :rest, :global

  @spec media_controls(map()) :: Phoenix.LiveView.Rendered.t()
  def media_controls(assigns) do
    ~H"""
    <.toolbar class={classes(["gap-retro-4 p-retro-4 justify-center", @class])} {@rest}>
      <%!-- Mute/Unmute --%>
      <.toolbar_button label={if @muted, do: "Unmute", else: "Mute"} active={@muted}>
        <Icons.icon_mute :if={@muted} class="w-4 h-4" />
        <Icons.icon_microphone :if={!@muted} class="w-4 h-4" />
      </.toolbar_button>

      <%!-- Camera --%>
      <.toolbar_button label={if @camera_on, do: "Camera Off", else: "Camera On"} active={!@camera_on}>
        <Icons.icon_camera :if={@camera_on} class="w-4 h-4" />
        <Icons.icon_camera_off :if={!@camera_on} class="w-4 h-4" />
      </.toolbar_button>

      <.toolbar_separator />

      <%!-- End call --%>
      <.toolbar_button :if={@in_call} label="End Call">
        <Icons.icon_phone_end class="w-4 h-4" />
      </.toolbar_button>

      <%!-- Status badge --%>
      <.badge :if={@in_call} variant="default" class="text-[10px]">In Call</.badge>
    </.toolbar>
    """
  end
end
