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
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Badge

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
          "shadow-retro-raised bg-surface p-retro-8 space-y-retro-4 text-xs",
          @class
        ])
      }
      data-testid="file-transfer"
      {@rest}
    >
      <%!-- Header row --%>
      <div class="flex items-center gap-retro-4">
        <Icons.icon_file_send class="w-4 h-4 shrink-0" />
        <span class="font-bold flex-1 truncate">{@file_name}</span>
        <.badge variant="outline" class="text-[10px] px-1 py-0">
          {direction_label(@direction)}
        </.badge>
      </div>

      <%!-- Progress --%>
      <.progress value={@progress} class="h-3" />

      <%!-- Stats row --%>
      <div class="flex items-center gap-retro-8 text-muted-foreground">
        <span :if={@state in ~w(transferring paused resuming)}>{@progress}%</span>
        <span
          :if={@state == "completed"}
          data-testid="file-transfer-status"
          class="text-success font-bold"
        >
          {dgettext("p2p", "Complete")}
        </span>
        <span :if={@state == "cancelled"} data-testid="file-transfer-status" class="font-bold">
          {cancelled_label(@cancelled_by)}
        </span>
        <span
          :if={@state == "rejected"}
          data-testid="file-transfer-status"
          class="text-error font-bold"
        >
          {dgettext("p2p", "Rejected")}
        </span>
        <span
          :if={@state in ~w(failed validation_error)}
          data-testid="file-transfer-status"
          class="text-error font-bold"
        >
          {dgettext("p2p", "Failed")}
        </span>
        <span :if={@state in ~w(offering offer_received ready)} class="italic">
          {dgettext("p2p", "Pending...")}
        </span>
        <span :if={@speed && @state in ~w(transferring paused resuming)}>{@speed}</span>
        <span :if={@formatted_size}>{@formatted_size}</span>
        <div class="flex-1" />
        <.button
          :if={@state == "offer_received" && @direction == "receiving"}
          size="sm"
          variant="default"
          phx-click={@on_accept}
          data-testid="file-transfer-accept"
        >
          <:icon><Icons.icon_checkmark class="w-3 h-3" /></:icon>
          {dgettext("p2p", "Accept")}
        </.button>
        <.button
          :if={@state in ~w(offering offer_received ready transferring paused resuming)}
          size="sm"
          variant="outline"
          phx-click={@on_cancel}
          data-testid="file-transfer-cancel"
        >
          <:icon><Icons.icon_close class="w-3 h-3" /></:icon>
          {dgettext("p2p", "Cancel")}
        </.button>
      </div>
    </div>
    """
  end

  defp direction_label("sending"), do: dgettext("p2p", "Sending")
  defp direction_label(_direction), do: dgettext("p2p", "Receiving")

  defp cancelled_label(nil), do: dgettext("p2p", "Cancelled")

  defp cancelled_label(nickname),
    do: dgettext("p2p", "Cancelled by %{nickname}", nickname: nickname)
end
