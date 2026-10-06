defmodule RetroHexChatWeb.Components.UI.GroupCall.ScreenShareControl do
  @moduledoc """
  Browser-backed screen share control for the channel conference.

  The button is picked up by `GroupCallWebRTCHook` through click delegation;
  capture must start in the browser from a direct user gesture. Like the
  microphone and camera it keeps one name and is pressed while sharing.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ToolButton

  alias RetroHexChatWeb.Icons.CallControls

  attr :call, :map, required: true
  attr :variant, :string, values: ~w(raised flat dock), default: "raised"

  @spec screen_share_control(map()) :: Phoenix.LiveView.Rendered.t()
  def screen_share_control(assigns) do
    ~H"""
    <.tool_button
      label={screen_share_title(@call)}
      active={screen_share_active?(@call) || screen_share_blocked?(@call)}
      pressed={screen_share_active?(@call)}
      variant={@variant}
      disabled={screen_share_blocked?(@call)}
      data-group-call-screen-share-for={@call.token}
      data-testid="group-call-screen-share-toggle"
    >
      <CallControls.icon_call_screen_share class="h-4 w-4" />
    </.tool_button>
    """
  end

  defp screen_share_active?(%{media: %{screen: true}}), do: true
  defp screen_share_active?(_call), do: false

  defp screen_share_blocked?(%{media: %{server_screen_blocked: true}}), do: true
  defp screen_share_blocked?(_call), do: false

  defp screen_share_title(%{media: %{server_screen_blocked: true}}),
    do: dgettext("group_call", "Screen sharing disabled by moderator")

  defp screen_share_title(_call), do: dgettext("group_call", "Share screen")
end
