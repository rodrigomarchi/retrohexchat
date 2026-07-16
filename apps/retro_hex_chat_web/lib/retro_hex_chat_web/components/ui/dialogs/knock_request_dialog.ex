defmodule RetroHexChatWeb.Components.UI.KnockRequestDialog do
  @moduledoc """
  Small Win98-style dialog for requesting access to an invite-only channel.
  """

  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Textarea

  alias RetroHexChatWeb.Icons

  @max_message_length 200

  attr :id, :string, default: "knock-request-dialog"
  attr :show, :boolean, default: false
  attr :channel, :string, default: nil
  attr :message, :string, default: ""
  attr :error, :string, default: nil
  attr :on_change, :any, default: "knock_request_change"
  attr :on_submit, :any, default: "knock_request_submit"
  attr :on_cancel, :any, default: "knock_request_cancel"

  @spec knock_request_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def knock_request_dialog(assigns) do
    message = assigns.message || ""
    message_length = String.length(message)

    assigns =
      assigns
      |> assign(:message, message)
      |> assign(:message_length, message_length)
      |> assign(:max_message_length, @max_message_length)
      |> assign(:message_too_long, message_length > @max_message_length)

    ~H"""
    <.dialog id={@id} show={@show} on_cancel={@on_cancel} class="kr-dialog-wrap">
      <.dialog_header
        id={@id}
        title={dgettext("dialogs", "Request Channel Access")}
        on_close={@on_cancel}
      >
        <:icon><Icons.icon_dialog_invite class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body class="kr-dialog-body">
        <form
          id={"#{@id}-form"}
          phx-change={@on_change}
          phx-submit={@on_submit}
          phx-auto-recover="ignore"
          class="kr-form"
        >
          <input type="hidden" name="channel" value={@channel || ""} />

          <div class="kr-channel-card">
            <span class="kr-channel-icon" aria-hidden="true">
              <Icons.icon_dialog_invite class="w-4 h-4" />
            </span>
            <div class="kr-channel-copy">
              <p class="kr-field-label">{dgettext("dialogs", "Channel")}</p>
              <p class="kr-channel-value">{display_channel(@channel)}</p>
            </div>
          </div>

          <div class="kr-field-group">
            <label class="kr-field-label" for={"#{@id}-message"}>
              {dgettext("dialogs", "Message (optional)")}
            </label>
            <.textarea
              id={"#{@id}-message"}
              name="message"
              value={@message}
              rows="4"
              class="kr-message-input"
              placeholder={
                dgettext("dialogs", "Leave a message for the channel operators (optional)")
              }
              data-testid="knock-request-message"
            />
            <p
              class={[
                "kr-counter",
                @message_too_long && "kr-counter--error"
              ]}
              data-testid="knock-request-counter"
            >
              {@message_length} / {@max_message_length}
            </p>
            <p :if={@error} class="kr-error" data-testid="knock-request-error">
              {@error}
            </p>
          </div>

          <div class="kr-action-row">
            <.button
              type="submit"
              size="sm"
              disabled={@message_too_long}
              class="kr-action-button"
              data-testid="knock-request-submit"
            >
              <:icon><Icons.icon_dialog_invite /></:icon>
              {dgettext("dialogs", "Send Request")}
            </.button>
            <.button
              type="button"
              size="sm"
              variant="outline"
              phx-click={@on_cancel}
              class="kr-action-button"
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

  defp display_channel(nil), do: dgettext("dialogs", "unknown")
  defp display_channel(channel), do: channel
end
