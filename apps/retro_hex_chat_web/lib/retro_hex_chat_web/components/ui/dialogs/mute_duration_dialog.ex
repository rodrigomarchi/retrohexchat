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
    <.dialog id={@id} show={@show} on_cancel={@on_cancel} class="mud-dialog-wrap">
      <.dialog_header
        id={@id}
        title={dgettext("dialogs", "Mute User")}
        on_close={@on_cancel}
      >
        <:icon><Icons.icon_mute class="w-4 h-4" /></:icon>
      </.dialog_header>
      <.dialog_body class="mud-dialog-body">
        <form id={"#{@id}-form"} phx-submit={@on_submit} class="mud-form">
          <input type="hidden" name="nick" value={@target_nick || ""} />

          <div class="mud-target-card">
            <span class="mud-target-icon" aria-hidden="true">
              <Icons.icon_mute class="w-4 h-4" />
            </span>
            <div class="mud-target-copy">
              <p class="mud-field-label">{dgettext("dialogs", "Muting")}</p>
              <p class="mud-target-value">{display_nick(@target_nick)}</p>
            </div>
          </div>

          <div class="mud-field-group">
            <label class="mud-field-label" for={"#{@id}-duration"}>
              {dgettext("dialogs", "Duration")}
            </label>
            <.input
              type="text"
              id={"#{@id}-duration"}
              name="duration"
              autofocus
              class="mud-duration-input"
              placeholder={dgettext("dialogs", "30m")}
              data-testid="mute-duration-input"
            />
            <p class="mud-help-text">
              {dgettext("dialogs", "blank = permanent; 30s/5m/1h/1d")}
            </p>
          </div>

          <div class="mud-action-row">
            <.button type="submit" size="sm" class="mud-action-button">
              <:icon><Icons.icon_checkmark /></:icon>
              {dgettext("dialogs", "OK")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click={@on_cancel}
              class="mud-action-button"
            >
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
