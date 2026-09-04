defmodule RetroHexChatWeb.Components.UI.GroupCallConfirmDialog do
  @moduledoc """
  Confirmation dialog for destructive group-call actions.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog

  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :mode, :atom,
    default: :leave,
    values: [:leave, :end_call, :kick_participant, :mute_all, :camera_off_all]

  attr :channel, :string, default: nil
  attr :target_nickname, :string, default: nil
  attr :on_confirm, :any, required: true
  attr :on_cancel, :any, required: true

  attr :scope, :atom,
    default: :viewport,
    values: [:viewport, :window],
    doc: "`:window` when the host renders it inside the call's own desktop window"

  @spec group_call_confirm_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def group_call_confirm_dialog(assigns) do
    ~H"""
    <span data-testid={@id}>
      <.dialog id={@id} show={@show} scope={@scope}>
        <.dialog_header id={@id} title={title(@mode)}>
          <:icon><.inline_icon name={mode_icon(@mode)} class="h-[16px] w-[16px]" /></:icon>
        </.dialog_header>

        <.dialog_body>
          <div class="flex items-start gap-2 text-xs">
            <span class={dialog_badge_class(@mode)}>
              <.inline_icon name={mode_icon(@mode)} class="h-5 w-5" />
            </span>
            <div class="min-w-0">
              <p>{body(@mode, @channel, @target_nickname)}</p>
              <div class="mt-2 grid gap-1">
                <div
                  :for={impact <- impact_items(@mode)}
                  class="flex min-w-0 items-center gap-1 text-muted-foreground"
                >
                  <.inline_icon name={impact.icon} class="h-3.5 w-3.5 shrink-0" />
                  <span class="truncate">{impact.label}</span>
                </div>
              </div>
            </div>
          </div>
        </.dialog_body>

        <.dialog_footer>
          <.button
            variant="destructive"
            phx-click={@on_confirm}
            data-testid={"#{@id}-confirm"}
          >
            <:icon><.inline_icon name={confirm_icon(@mode)} class="h-4 w-4" /></:icon>
            {confirm_label(@mode)}
          </.button>
          <.button
            variant="outline"
            phx-click={@on_cancel}
            data-testid={"#{@id}-cancel"}
          >
            <:icon><Icons.icon_close class="h-4 w-4" /></:icon>
            {dgettext("group_call", "Cancel")}
          </.button>
        </.dialog_footer>
      </.dialog>
    </span>
    """
  end

  defp title(:leave), do: dgettext("group_call", "Leave Group Call")
  defp title(:end_call), do: dgettext("group_call", "End Group Call")
  defp title(:kick_participant), do: dgettext("group_call", "Remove From Channel?")
  defp title(:mute_all), do: dgettext("group_call", "Mute Everyone?")
  defp title(:camera_off_all), do: dgettext("group_call", "Turn Cameras Off?")

  defp body(:leave, channel, _target_nickname) do
    dgettext(
      "group_call",
      "Leave the group call in %{channel}? Your microphone and camera will disconnect.",
      channel: channel || "?"
    )
  end

  defp body(:end_call, channel, _target_nickname) do
    dgettext(
      "group_call",
      "End the group call in %{channel} for everyone? All participants will be disconnected.",
      channel: channel || "?"
    )
  end

  defp body(:kick_participant, channel, target_nickname) do
    dgettext(
      "group_call",
      "Remove %{target} from %{channel}? This will ban them from the channel, disconnect them from the conference, and prevent them from rejoining until a channel operator unbans them.",
      target: target_nickname || "?",
      channel: channel || "?"
    )
  end

  defp body(:mute_all, channel, _target_nickname) do
    dgettext(
      "group_call",
      "Mute all lower-ranked participants in %{channel}? They cannot unmute until a moderator allows their microphone again.",
      channel: channel || "?"
    )
  end

  defp body(:camera_off_all, channel, _target_nickname) do
    dgettext(
      "group_call",
      "Turn off cameras for all lower-ranked participants in %{channel}? They cannot turn camera back on until a moderator allows it again.",
      channel: channel || "?"
    )
  end

  defp confirm_label(:leave), do: dgettext("group_call", "Leave call")
  defp confirm_label(:end_call), do: dgettext("group_call", "End call")
  defp confirm_label(:kick_participant), do: dgettext("group_call", "Remove and ban")
  defp confirm_label(:mute_all), do: dgettext("group_call", "Mute all")
  defp confirm_label(:camera_off_all), do: dgettext("group_call", "Cameras off")

  attr :name, :atom, required: true
  attr :class, :string, default: nil

  defp inline_icon(assigns) do
    ~H"""
    {apply(Icons, @name, [%{class: @class}])}
    """
  end

  defp mode_icon(:leave), do: :icon_phone_end
  defp mode_icon(:end_call), do: :icon_phone_end
  defp mode_icon(:kick_participant), do: :icon_ban
  defp mode_icon(:mute_all), do: :icon_mute
  defp mode_icon(:camera_off_all), do: :icon_camera_off

  defp confirm_icon(:kick_participant), do: :icon_ban
  defp confirm_icon(:mute_all), do: :icon_mute
  defp confirm_icon(:camera_off_all), do: :icon_camera_off
  defp confirm_icon(_mode), do: :icon_phone_end

  defp dialog_badge_class(:kick_participant),
    do:
      "flex h-9 w-9 shrink-0 items-center justify-center bg-destructive text-destructive-foreground shadow-retro-sunken"

  defp dialog_badge_class(:end_call),
    do:
      "flex h-9 w-9 shrink-0 items-center justify-center bg-destructive text-destructive-foreground shadow-retro-sunken"

  defp dialog_badge_class(:mute_all),
    do:
      "flex h-9 w-9 shrink-0 items-center justify-center bg-warning text-foreground shadow-retro-sunken"

  defp dialog_badge_class(:camera_off_all),
    do:
      "flex h-9 w-9 shrink-0 items-center justify-center bg-warning text-foreground shadow-retro-sunken"

  defp dialog_badge_class(_mode),
    do: "flex h-9 w-9 shrink-0 items-center justify-center bg-canvas shadow-retro-sunken"

  defp impact_items(:leave) do
    [
      %{icon: :icon_microphone, label: dgettext("group_call", "Microphone disconnects")},
      %{icon: :icon_camera_off, label: dgettext("group_call", "Camera stream stops")}
    ]
  end

  defp impact_items(:end_call) do
    [
      %{icon: :icon_community, label: dgettext("group_call", "All participants disconnect")},
      %{icon: :icon_server, label: dgettext("group_call", "The room is stopped on the server")}
    ]
  end

  defp impact_items(:kick_participant) do
    [
      %{icon: :icon_phone_end, label: dgettext("group_call", "Conference connection closes")},
      %{icon: :icon_ban, label: dgettext("group_call", "Channel access is banned")},
      %{icon: :icon_shield, label: dgettext("group_call", "Operators can unban later")}
    ]
  end

  defp impact_items(:mute_all) do
    [
      %{icon: :icon_role_halfop, label: dgettext("group_call", "Only lower ranks are affected")},
      %{icon: :icon_mute, label: dgettext("group_call", "Microphones are server-muted")},
      %{
        icon: :icon_shield,
        label: dgettext("group_call", "Moderators can allow individuals later")
      }
    ]
  end

  defp impact_items(:camera_off_all) do
    [
      %{icon: :icon_role_halfop, label: dgettext("group_call", "Only lower ranks are affected")},
      %{icon: :icon_camera_off, label: dgettext("group_call", "Cameras are server-blocked")},
      %{
        icon: :icon_shield,
        label: dgettext("group_call", "Moderators can allow individuals later")
      }
    ]
  end
end
