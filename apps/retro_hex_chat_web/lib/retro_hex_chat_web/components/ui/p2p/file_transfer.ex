defmodule RetroHexChatWeb.Components.UI.FileTransfer do
  @moduledoc """
  File transfer component for the showcase design system.

  Composed from progress + button + badge primitives.
  File name, percentage, speed, cancel button.

  ## Usage

      <.file_transfer
        file_name="document.pdf"
        progress={65}
        speed="1.2 MB/s"
        direction="receiving"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Progress
  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.MediaSession.ActionButton

  alias RetroHexChatWeb.Icons

  @doc "Renders the file transfer display."
  attr :file_name, :string, required: true
  attr :progress, :integer, default: 0
  attr :speed, :string, default: nil
  attr :formatted_size, :string, default: nil
  attr :direction, :string, default: "receiving", values: ~w(sending receiving)

  attr :state, :string,
    default: "transferring",
    doc: "Transfer status string"

  attr :on_cancel, :any, default: nil, doc: "Cancel transfer callback"
  attr :on_accept, :any, default: nil, doc: "Accept incoming transfer callback"
  attr :cancelled_by, :string, default: nil, doc: "Nickname that cancelled the transfer"
  attr :class, :string, default: nil
  attr :rest, :global

  @spec file_transfer(map()) :: Phoenix.LiveView.Rendered.t()
  def file_transfer(assigns) do
    ~H"""
    <div
      class={
        classes([
          "border border-border bg-surface p-2 text-xs shadow-retro-raised",
          @class
        ])
      }
      data-testid="file-transfer"
      {@rest}
    >
      <div class="flex min-w-0 items-start gap-2">
        <span class="shadow-retro-sunken inline-flex h-8 w-8 shrink-0 items-center justify-center bg-canvas">
          <Icons.icon_file_send class="h-4 w-4" />
        </span>
        <div class="min-w-0 flex-1">
          <div class="flex min-w-0 flex-wrap items-center gap-x-2 gap-y-1">
            <span class="min-w-0 flex-1 truncate font-bold">{@file_name}</span>
            <.badge variant="outline" class="px-1 py-0 text-[10px]">
              {direction_label(@direction)}
            </.badge>
          </div>
          <p class="truncate text-[10px] leading-3 text-muted-foreground">
            {state_label(@state)}
          </p>
        </div>
      </div>

      <div class="mt-2">
        <.progress value={@progress} class="h-3" />
      </div>

      <div class="mt-2 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <div class="flex min-w-0 flex-wrap items-center gap-x-2 gap-y-1 text-muted-foreground">
          <span
            :if={@state in ~w(transferring paused resuming)}
            class="font-bold text-foreground"
            data-testid="file-transfer-status"
          >
            {@progress}%
          </span>
          <span
            :if={@state == "completed"}
            data-testid="file-transfer-status"
            class="font-bold text-success"
          >
            {dgettext("p2p", "Complete")}
          </span>
          <span :if={@state == "cancelled"} data-testid="file-transfer-status" class="font-bold">
            {cancelled_label(@cancelled_by)}
          </span>
          <span
            :if={@state == "rejected"}
            data-testid="file-transfer-status"
            class="font-bold text-error"
          >
            {dgettext("p2p", "Rejected")}
          </span>
          <span
            :if={@state in ~w(failed validation_error)}
            data-testid="file-transfer-status"
            class="font-bold text-error"
          >
            {dgettext("p2p", "Failed")}
          </span>
          <span :if={@state in ~w(offering offer_received ready)} class="italic">
            {dgettext("p2p", "Pending...")}
          </span>
          <span :if={@speed && @state in ~w(transferring paused resuming)}>{@speed}</span>
          <span :if={@formatted_size}>{@formatted_size}</span>
        </div>

        <div class="flex shrink-0 justify-end gap-1">
          <.media_session_action_button
            :if={@state == "offer_received" && @direction == "receiving"}
            label={dgettext("p2p", "Accept incoming file")}
            phx-click={@on_accept}
            data-testid="file-transfer-accept"
          >
            <Icons.icon_checkmark class="h-4 w-4 text-success" />
            <span>{dgettext("p2p", "Accept")}</span>
          </.media_session_action_button>
          <.media_session_action_button
            :if={@state in ~w(offering offer_received ready transferring paused resuming)}
            label={dgettext("p2p", "Cancel file transfer")}
            phx-click={@on_cancel}
            data-testid="file-transfer-cancel"
          >
            <Icons.icon_close class="h-4 w-4" />
            <span>{dgettext("p2p", "Cancel")}</span>
          </.media_session_action_button>
        </div>
      </div>
    </div>
    """
  end

  defp direction_label("sending"), do: dgettext("p2p", "Sending")
  defp direction_label(_direction), do: dgettext("p2p", "Receiving")

  defp state_label("offering"), do: dgettext("p2p", "Waiting for the peer to accept")
  defp state_label("offer_received"), do: dgettext("p2p", "Incoming file offer")
  defp state_label("transferring"), do: dgettext("p2p", "Transfer in progress")
  defp state_label("paused"), do: dgettext("p2p", "Transfer paused")
  defp state_label("resuming"), do: dgettext("p2p", "Resuming transfer")
  defp state_label("completed"), do: dgettext("p2p", "Transfer complete")
  defp state_label("cancelled"), do: dgettext("p2p", "Transfer cancelled")
  defp state_label("rejected"), do: dgettext("p2p", "Transfer rejected")

  defp state_label(state) when state in ~w(failed validation_error),
    do: dgettext("p2p", "Transfer failed")

  defp state_label(_state), do: dgettext("p2p", "Ready")

  defp cancelled_label(nil), do: dgettext("p2p", "Cancelled")

  defp cancelled_label(nickname),
    do: dgettext("p2p", "Cancelled by %{nickname}", nickname: nickname)
end
