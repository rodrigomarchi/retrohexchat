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
    <.dialog id={@id} show={@show} on_cancel={@on_cancel} class="max-w-md">
      <.dialog_header
        id={@id}
        title={dgettext("dialogs", "Request Channel Access")}
        on_close={@on_cancel}
      >
        <:icon><Icons.icon_dialog_invite class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body>
        <form
          id={"#{@id}-form"}
          phx-change={@on_change}
          phx-submit={@on_submit}
          class="space-y-retro-10"
        >
          <input type="hidden" name="channel" value={@channel || ""} />

          <p class="text-xs font-bold">
            {dgettext("dialogs", "Channel")}: {display_channel(@channel)}
          </p>

          <div class="flex flex-col gap-retro-4">
            <label class="text-xs font-bold" for={"#{@id}-message"}>
              {dgettext("dialogs", "Message (optional)")}:
            </label>
            <.textarea
              id={"#{@id}-message"}
              name="message"
              value={@message}
              rows="4"
              placeholder={
                dgettext("dialogs", "Leave a message for the channel operators (optional)")
              }
              data-testid="knock-request-message"
            />
            <p
              class={[
                "text-[10px]",
                if(@message_too_long, do: "text-destructive", else: "text-muted-foreground")
              ]}
              data-testid="knock-request-counter"
            >
              {@message_length} / {@max_message_length}
            </p>
            <p :if={@error} class="text-[10px] text-destructive" data-testid="knock-request-error">
              {@error}
            </p>
          </div>

          <div class="flex justify-end gap-retro-4">
            <.button
              type="submit"
              size="sm"
              disabled={@message_too_long}
              data-testid="knock-request-submit"
            >
              <:icon><Icons.icon_dialog_invite /></:icon>
              {dgettext("dialogs", "Send Request")}
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

  defp display_channel(nil), do: dgettext("dialogs", "unknown")
  defp display_channel(channel), do: channel
end
