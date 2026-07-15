defmodule RetroHexChatWeb.Components.UI.GroupCall.ScreenShareControl do
  @moduledoc """
  Browser-backed screen share control for the channel conference.

  The button is picked up by `GroupCallWebRTCHook` through click delegation;
  capture must start in the browser from a direct user gesture.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons.CallControls

  attr :call, :map, required: true

  @spec screen_share_control(map()) :: Phoenix.LiveView.Rendered.t()
  def screen_share_control(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "flex h-10 w-10 min-w-[2.5rem] items-center justify-center bg-surface shadow-retro-raised",
        "focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground",
        screen_share_active?(@call) && "bg-muted shadow-retro-sunken text-primary",
        screen_share_blocked?(@call) &&
          "bg-destructive text-destructive-foreground shadow-retro-sunken"
      ]}
      aria-label={screen_share_title(@call)}
      title={screen_share_title(@call)}
      aria-pressed={to_string(screen_share_active?(@call))}
      disabled={screen_share_blocked?(@call)}
      data-group-call-screen-share-for={@call.token}
      data-testid="group-call-screen-share-toggle"
    >
      <CallControls.icon_call_screen_share class="h-8 w-8" />
    </button>
    """
  end

  defp screen_share_active?(%{media: %{screen: true}}), do: true
  defp screen_share_active?(_call), do: false

  defp screen_share_blocked?(%{media: %{server_screen_blocked: true}}), do: true
  defp screen_share_blocked?(_call), do: false

  defp screen_share_title(%{media: %{server_screen_blocked: true}}),
    do: dgettext("group_call", "Screen sharing disabled by moderator")

  defp screen_share_title(%{media: %{screen: true}}),
    do: dgettext("group_call", "Stop sharing screen")

  defp screen_share_title(_call), do: dgettext("group_call", "Share screen")
end
