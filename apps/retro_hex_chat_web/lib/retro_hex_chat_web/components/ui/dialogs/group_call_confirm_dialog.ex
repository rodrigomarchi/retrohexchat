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
  attr :mode, :atom, default: :leave, values: [:leave, :close, :switch, :end_call]
  attr :channel, :string, default: nil
  attr :new_channel, :string, default: nil
  attr :on_confirm, :any, required: true
  attr :on_cancel, :any, required: true

  @spec group_call_confirm_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def group_call_confirm_dialog(assigns) do
    ~H"""
    <span data-testid="group-call-confirm-dialog">
      <.dialog id={@id} show={@show}>
        <.dialog_header id={@id} title={title(@mode)}>
          <:icon><Icons.icon_camera class="h-[16px] w-[16px]" /></:icon>
        </.dialog_header>

        <.dialog_body>
          <p class="text-xs">{body(@mode, @channel, @new_channel)}</p>
        </.dialog_body>

        <.dialog_footer>
          <.button
            variant="destructive"
            phx-click={@on_confirm}
            data-testid="group-call-confirm-dialog-confirm"
          >
            <:icon><Icons.icon_phone_end class="h-4 w-4" /></:icon>
            {confirm_label(@mode)}
          </.button>
          <.button
            variant="outline"
            phx-click={@on_cancel}
            data-testid="group-call-confirm-dialog-cancel"
          >
            <:icon><Icons.icon_close class="h-4 w-4" /></:icon>
            {dgettext("dialogs", "Cancel")}
          </.button>
        </.dialog_footer>
      </.dialog>
    </span>
    """
  end

  defp title(:leave), do: dgettext("dialogs", "Leave Group Call")
  defp title(:close), do: dgettext("dialogs", "Close Group Call?")
  defp title(:switch), do: dgettext("dialogs", "Switch Group Call")
  defp title(:end_call), do: dgettext("dialogs", "End Group Call")

  defp body(:leave, channel, _new_channel) do
    dgettext(
      "dialogs",
      "Leave the group call in %{channel}? Your microphone and camera will disconnect.",
      channel: channel || "?"
    )
  end

  defp body(:close, channel, _new_channel) do
    dgettext(
      "dialogs",
      "Closing this window leaves the group call in %{channel}. To keep the call running and just tidy up, minimize the window instead.",
      channel: channel || "?"
    )
  end

  defp body(:switch, channel, new_channel) do
    dgettext(
      "dialogs",
      "You are already in a group call in %{channel}. Leave it and join the call in %{new_channel}?",
      channel: channel || "?",
      new_channel: new_channel || "?"
    )
  end

  defp body(:end_call, channel, _new_channel) do
    dgettext(
      "dialogs",
      "End the group call in %{channel} for everyone? All participants will be disconnected.",
      channel: channel || "?"
    )
  end

  defp confirm_label(:leave), do: dgettext("dialogs", "Leave call")
  defp confirm_label(:close), do: dgettext("dialogs", "Leave call")
  defp confirm_label(:switch), do: dgettext("dialogs", "Switch call")
  defp confirm_label(:end_call), do: dgettext("dialogs", "End call")
end
