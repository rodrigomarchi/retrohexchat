defmodule RetroHexChatWeb.Components.UI.Lobby.FilePanel do
  @moduledoc """
  File-transfer panel for the universal lobby — the body of the "Files" window.

  Hosts the `FileTransferHook` (kept mounted for the whole connection so the data
  channel always has an `onmessage` handler and incoming offers surface). Renders the
  drop zone / browse control and the active-transfer progress widget. Composed from
  the button primitive and the shared `file_transfer` widget.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.FileTransfer

  alias RetroHexChatWeb.Icons

  attr :connected, :boolean, default: false
  attr :file_transfer, :map, default: nil
  attr :nickname, :string, required: true
  attr :max_file_size_mb, :integer, required: true
  attr :blocked_file_extensions, :list, required: true

  @spec file_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def file_panel(assigns) do
    ~H"""
    <p :if={!@connected} class="text-muted-foreground flex items-center gap-2 p-2 text-xs">
      <Icons.icon_file_send class="h-4 w-4 shrink-0" />
      {dgettext("lobby", "Connect to send a file.")}
    </p>

    <section
      :if={@connected}
      id="lobby-file-transfer"
      phx-hook="FileTransferHook"
      data-webrtc-id="lobby-webrtc"
      data-max-size-mb={@max_file_size_mb}
      data-blocked-extensions={Enum.join(@blocked_file_extensions, ",")}
      class="bg-accent p-1"
      data-testid="lobby-file-panel"
    >
      <input type="file" id="lobby-file-input" class="file-transfer-input u-hidden" />

      <div
        :if={
          @file_transfer && @file_transfer[:status] in ["ready", "validation_error"] &&
            !@file_transfer[:file_name]
        }
        class="shadow-retro-field bg-white p-4 text-center text-xs"
      >
        <Icons.icon_file_send class="mx-auto mb-2 h-6 w-6" />
        <p
          :if={@file_transfer[:validation_error]}
          class="text-error mb-2 font-bold"
          data-testid="lobby-ft-validation-error"
        >
          {@file_transfer[:validation_error]}
        </p>
        <p class="mb-2">
          {dgettext(
            "lobby",
            "Drop a file here, or browse. Transfers run alongside your call and game."
          )}
        </p>
        <p class="text-muted-foreground mb-2">
          {dgettext("lobby", "Max: %{size} MB", size: @max_file_size_mb)}
        </p>
        <label for="lobby-file-input">
          <.button type="button" size="sm">
            <:icon><Icons.icon_choose_file class="h-4 w-4" /></:icon>
            {dgettext("lobby", "Browse files")}
          </.button>
        </label>
      </div>

      <.file_transfer
        :if={@file_transfer && @file_transfer[:file_name]}
        file_name={@file_transfer[:file_name]}
        progress={@file_transfer[:percent] || 0}
        speed={@file_transfer[:speed]}
        formatted_size={@file_transfer[:formatted_size]}
        state={@file_transfer[:status] || "ready"}
        direction={ft_direction(@file_transfer, @nickname)}
        cancelled_by={@file_transfer[:cancelled_by]}
        on_cancel="ft_cancel"
        on_accept="ft_accept_offer"
      />
    </section>
    """
  end

  @spec ft_direction(map(), String.t()) :: String.t()
  defp ft_direction(ft, nickname) do
    if Map.get(ft, :sender_nick) == nickname, do: "sending", else: "receiving"
  end
end
