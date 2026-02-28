defmodule RetroHexChatWeb.Components.UI.FileTransfer do
  @moduledoc """
  File transfer component for the showcase design system.

  Composed from progress + button + badge primitives.
  File name, percentage, speed, cancel button.

  ## Usage

      <.file_transfer
        filename="document.pdf"
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
  attr :filename, :string, required: true
  attr :progress, :integer, default: 0
  attr :speed, :string, default: nil
  attr :size, :string, default: nil
  attr :direction, :string, default: "receiving", values: ~w(sending receiving)

  attr :state, :atom,
    default: :transferring,
    values: [:pending, :transferring, :complete, :failed]

  attr :on_cancel, :any, default: nil, doc: "Cancel transfer callback"
  attr :on_accept, :any, default: nil, doc: "Accept incoming transfer callback"
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
        <span class="font-bold flex-1 truncate">{@filename}</span>
        <.badge variant="outline" class="text-[10px] px-1 py-0">
          {if @direction == "sending", do: "Sending", else: "Receiving"}
        </.badge>
      </div>

      <%!-- Progress --%>
      <.progress value={@progress} class="h-3" />

      <%!-- Stats row --%>
      <div class="flex items-center gap-retro-8 text-muted-foreground">
        <span :if={@state == :transferring}>{@progress}%</span>
        <span :if={@state == :complete} class="text-success font-bold">Complete</span>
        <span :if={@state == :failed} class="text-error font-bold">Failed</span>
        <span :if={@state == :pending} class="italic">Pending...</span>
        <span :if={@speed && @state == :transferring}>{@speed}</span>
        <span :if={@size}>{@size}</span>
        <div class="flex-1" />
        <.button
          :if={@state == :pending && @direction == "receiving"}
          size="sm"
          variant="default"
          phx-click={@on_accept}
          data-testid="file-transfer-accept"
        >
          <:icon><Icons.icon_checkmark class="w-3 h-3" /></:icon>
          Accept
        </.button>
        <.button
          :if={@state in [:pending, :transferring]}
          size="sm"
          variant="outline"
          phx-click={@on_cancel}
          data-testid="file-transfer-cancel"
        >
          <:icon><Icons.icon_close class="w-3 h-3" /></:icon>
          Cancel
        </.button>
      </div>
    </div>
    """
  end
end
