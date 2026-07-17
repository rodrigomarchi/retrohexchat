defmodule RetroHexChatWeb.Components.UI.Lobby.FilePanel do
  @moduledoc """
  File-transfer activity for the P2P session console.

  Hosts the `FileTransferHook` (kept mounted for the whole connection so the data
  channel always has an `onmessage` handler and incoming offers surface). Renders the
  drop zone / browse control and the active-transfer progress widget. Composed from
  media-session primitives and the shared `file_transfer` widget.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.FileTransfer
  import RetroHexChatWeb.Components.UI.MediaSession.ActionButton
  import RetroHexChatWeb.Components.UI.MediaSession.StatusHeader

  alias RetroHexChatWeb.Icons

  attr :connected, :boolean, default: false
  attr :file_transfer, :map, default: nil
  attr :nickname, :string, required: true
  attr :peer_nick, :string, default: nil
  attr :max_file_size_mb, :integer, required: true
  attr :blocked_file_extensions, :list, required: true

  @spec file_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def file_panel(assigns) do
    ~H"""
    <section
      :if={!@connected}
      class="flex h-full min-h-[180px] flex-col gap-2 bg-surface p-2"
      data-testid="p2p-files-disconnected"
    >
      <.media_session_status_header
        title={dgettext("lobby", "Files")}
        testid="p2p-files-activity-header"
        class="border border-border bg-canvas p-2 shadow-retro-field"
      >
        <:icon>
          <Icons.icon_file_send class="h-5 w-5 shrink-0" />
        </:icon>
        <:meta>
          <span>{dgettext("lobby", "Waiting for P2P connection")}</span>
        </:meta>
        <:facets>
          <span class="border border-border bg-muted px-1.5 py-0.5 text-[10px] font-bold text-muted-foreground shadow-retro-sunken">
            {dgettext("chat", "Offline")}
          </span>
        </:facets>
      </.media_session_status_header>

      <div class="shadow-retro-field flex min-h-0 flex-1 items-center justify-center bg-white p-4 text-center text-xs text-muted-foreground">
        <div class="max-w-[18rem] space-y-2">
          <Icons.icon_file_send class="mx-auto h-6 w-6" />
          <p>{dgettext("lobby", "Connect to send a file.")}</p>
        </div>
      </div>
    </section>

    <section
      :if={@connected}
      id="lobby-file-transfer"
      phx-hook="FileTransferHook"
      data-webrtc-id="lobby-webrtc"
      data-max-size-mb={@max_file_size_mb}
      data-blocked-extensions={Enum.join(@blocked_file_extensions, ",")}
      class="flex h-full min-h-[220px] flex-col gap-2 bg-surface p-2"
      data-testid="lobby-file-panel"
    >
      <input type="file" id="lobby-file-input" class="file-transfer-input u-hidden" />

      <.media_session_status_header
        title={dgettext("lobby", "Files")}
        testid="p2p-files-activity-header"
        class="border border-border bg-canvas p-2 shadow-retro-field"
      >
        <:icon>
          <Icons.icon_file_send class="h-5 w-5 shrink-0" />
        </:icon>
        <:meta>
          <span>{dgettext("lobby", "Peer %{peer}", peer: peer_label(@peer_nick))}</span>
          <span>{dgettext("lobby", "Max %{size} MB", size: @max_file_size_mb)}</span>
        </:meta>
        <:facets>
          <span class={file_status_badge_class(@file_transfer)}>
            {file_status_label(@file_transfer)}
          </span>
        </:facets>
      </.media_session_status_header>

      <div
        :if={!@file_transfer}
        class="shadow-retro-field flex min-h-[180px] flex-1 items-center justify-center bg-white p-4 text-center text-xs text-muted-foreground sm:min-h-[240px]"
        data-testid="p2p-files-preparing"
      >
        <div class="max-w-[18rem] space-y-2">
          <Icons.icon_clock class="mx-auto h-5 w-5 animate-spin" />
          <p>{dgettext("lobby", "Preparing file transfer.")}</p>
        </div>
      </div>

      <div
        :if={
          @file_transfer && @file_transfer[:status] in ["ready", "validation_error"] &&
            !@file_transfer[:file_name]
        }
        class="shadow-retro-field flex min-h-[220px] flex-1 items-center justify-center bg-white p-4 text-center text-xs sm:min-h-[300px]"
        data-testid="p2p-files-dropzone"
      >
        <div class="max-w-[28rem] space-y-3">
          <Icons.icon_file_send class="mx-auto h-7 w-7" />
          <div class="space-y-1">
            <p
              :if={@file_transfer[:validation_error]}
              class="text-error font-bold"
              data-testid="lobby-ft-validation-error"
            >
              {@file_transfer[:validation_error]}
            </p>
            <p class="font-bold">
              {dgettext("lobby", "Drop a file here or browse.")}
            </p>
            <p class="text-muted-foreground">
              {dgettext("lobby", "Call and game stay active with %{peer}.",
                peer: peer_label(@peer_nick)
              )}
            </p>
          </div>
          <label
            for="lobby-file-input"
            class={media_session_action_button_class("default", "mx-auto cursor-pointer")}
          >
            <Icons.icon_choose_file class="h-4 w-4" />
            <span>{dgettext("lobby", "Browse files")}</span>
          </label>
        </div>
      </div>

      <div
        :if={@file_transfer && @file_transfer[:file_name]}
        class="shadow-retro-field flex min-h-[220px] flex-1 items-center justify-center overflow-auto bg-white p-3 sm:min-h-[300px]"
        data-testid="p2p-files-transfer-stage"
      >
        <.file_transfer
          class="w-full max-w-[36rem]"
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
      </div>
    </section>
    """
  end

  @spec peer_label(String.t() | nil) :: String.t()
  defp peer_label(peer) when is_binary(peer) and peer != "", do: peer
  defp peer_label(_peer), do: dgettext("lobby", "peer")

  @spec file_status_label(map() | nil) :: String.t()
  defp file_status_label(%{status: "validation_error"}), do: dgettext("lobby", "Check file")
  defp file_status_label(%{status: "offer_received"}), do: dgettext("lobby", "Incoming")
  defp file_status_label(%{status: "offering"}), do: dgettext("lobby", "Offering")
  defp file_status_label(%{status: "transferring"}), do: dgettext("lobby", "Active")
  defp file_status_label(%{status: "paused"}), do: dgettext("lobby", "Paused")

  defp file_status_label(%{file_name: name}) when is_binary(name) and name != "",
    do: dgettext("lobby", "Active")

  defp file_status_label(_file_transfer), do: dgettext("lobby", "Ready")

  @spec file_status_badge_class(map() | nil) :: String.t()
  defp file_status_badge_class(%{status: "validation_error"}) do
    "border border-destructive bg-destructive/10 px-1.5 py-0.5 text-[10px] font-bold text-destructive shadow-retro-sunken"
  end

  defp file_status_badge_class(%{status: "offer_received"}) do
    "border border-warning bg-warning-light px-1.5 py-0.5 text-[10px] font-bold text-foreground shadow-retro-sunken"
  end

  defp file_status_badge_class(%{file_name: name}) when is_binary(name) and name != "" do
    "border border-success bg-white px-1.5 py-0.5 text-[10px] font-bold text-success shadow-retro-sunken"
  end

  defp file_status_badge_class(_file_transfer) do
    "border border-border bg-muted px-1.5 py-0.5 text-[10px] font-bold text-muted-foreground shadow-retro-sunken"
  end

  @spec ft_direction(map(), String.t()) :: String.t()
  defp ft_direction(ft, nickname) do
    if Map.get(ft, :sender_nick) == nickname, do: "sending", else: "receiving"
  end
end
