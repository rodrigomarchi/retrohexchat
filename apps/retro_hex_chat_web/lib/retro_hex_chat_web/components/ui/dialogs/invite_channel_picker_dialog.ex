defmodule RetroHexChatWeb.Components.UI.InviteChannelPickerDialog do
  @moduledoc """
  Small Win98-style dialog for sending a channel invite to a selected nickname.
  """

  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog

  alias RetroHexChatWeb.Icons

  attr :id, :string, default: "invite-channel-picker-dialog"
  attr :show, :boolean, default: false
  attr :target_nick, :string, default: nil
  attr :channels, :list, default: []
  attr :selected_channel, :string, default: nil
  attr :error, :string, default: nil
  attr :on_submit, :any, default: "invite_channel_picker_submit"
  attr :on_cancel, :any, default: "invite_channel_picker_cancel"

  @spec invite_channel_picker_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def invite_channel_picker_dialog(assigns) do
    assigns =
      assigns
      |> assign(:selected_channel, selected_channel(assigns.channels, assigns.selected_channel))
      |> assign(:has_channels, assigns.channels != [])

    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_cancel} class="max-w-sm">
      <.dialog_header
        id={@id}
        title={dgettext("dialogs", "Invite to Channel")}
        on_close={@on_cancel}
      >
        <:icon><Icons.icon_dialog_invite class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body>
        <form id={"#{@id}-form"} phx-submit={@on_submit} class="space-y-retro-10">
          <input type="hidden" name="target" value={@target_nick || ""} />

          <p class="text-xs font-bold">
            {dgettext("dialogs", "Inviting")}: {display_nick(@target_nick)}
          </p>

          <div class="flex flex-col gap-retro-4">
            <label class="text-xs font-bold" for={"#{@id}-channel"}>
              {dgettext("dialogs", "Channel")}:
            </label>
            <select
              id={"#{@id}-channel"}
              name="channel"
              class="flex h-10 w-full border-none shadow-retro-field bg-white px-3 py-2 text-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-black disabled:cursor-not-allowed disabled:opacity-50"
              disabled={!@has_channels}
              data-testid="invite-channel-picker-select"
            >
              <option
                :for={channel <- @channels}
                value={channel}
                selected={channel == @selected_channel}
              >
                {channel}
              </option>
            </select>
            <p :if={!@has_channels} class="text-[10px] text-muted-foreground">
              {dgettext("dialogs", "You must be in a channel to invite someone")}
            </p>
            <p :if={@error} class="text-[10px] text-destructive" data-testid="invite-channel-error">
              {@error}
            </p>
          </div>

          <div class="flex justify-end gap-retro-4">
            <.button
              type="submit"
              size="sm"
              disabled={!@has_channels}
              data-testid="invite-channel-submit"
            >
              <:icon><Icons.icon_dialog_invite /></:icon>
              {dgettext("dialogs", "Send Invite")}
            </.button>
            <.button type="button" size="sm" variant="outline" phx-click={@on_cancel}>
              <:icon><Icons.icon_close /></:icon>
              {dgettext("dialogs", "Cancel")}
            </.button>
          </div>
        </form>
      </.dialog_body>
    </.dialog>
    """
  end

  defp selected_channel([], _selected), do: nil

  defp selected_channel(channels, selected) do
    if Enum.member?(channels, selected), do: selected, else: List.first(channels)
  end

  defp display_nick(nil), do: dgettext("dialogs", "unknown")
  defp display_nick(nick), do: nick
end
