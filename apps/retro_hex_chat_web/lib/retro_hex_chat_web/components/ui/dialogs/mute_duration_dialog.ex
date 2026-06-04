defmodule RetroHexChatWeb.Components.UI.MuteDurationDialog do
  @moduledoc """
  Small Win98-style prompt for collecting an optional channel mute duration.
  """

  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  attr :id, :string, default: "mute-duration-dialog"
  attr :show, :boolean, default: false
  attr :target_nick, :string, default: nil
  attr :on_submit, :any, default: "mute_duration_submit"
  attr :on_cancel, :any, default: "mute_duration_cancel"

  @spec mute_duration_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def mute_duration_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_cancel} class="max-w-sm">
      <.dialog_header
        id={@id}
        title={dgettext("dialogs", "Mute user: %{nick}", nick: display_nick(@target_nick))}
        on_close={@on_cancel}
      >
        <:icon><Icons.icon_mute class="w-4 h-4" /></:icon>
      </.dialog_header>
      <.dialog_body>
        <form id={"#{@id}-form"} phx-submit={@on_submit} class="space-y-retro-8">
          <input type="hidden" name="nick" value={@target_nick || ""} />

          <div class="flex flex-col gap-retro-4">
            <label class="text-xs font-bold" for={"#{@id}-duration"}>
              {dgettext("dialogs", "Duration")}:
            </label>
            <.input
              type="text"
              id={"#{@id}-duration"}
              name="duration"
              autofocus
              class="w-full"
              placeholder={dgettext("dialogs", "30m")}
              data-testid="mute-duration-input"
            />
            <p class="text-[10px] text-muted-foreground">
              {dgettext("dialogs", "blank = permanent; 30s/5m/1h/1d")}
            </p>
          </div>

          <div class="flex justify-end gap-retro-4">
            <.button type="submit" size="sm">
              <:icon><Icons.icon_checkmark /></:icon>
              {dgettext("dialogs", "OK")}
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

  defp display_nick(nil), do: dgettext("dialogs", "unknown")
  defp display_nick(nick), do: nick
end
