defmodule RetroHexChatWeb.ShowcaseLive.P2P.FileTransferPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.FileTransfer
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("File Transfer"), active_page: "file-transfer")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("File Transfer")}</h2>

      <.showcase_card title={gettext("Receiving")} description="File being received with progress.">
        <.file_transfer
          file_name="vacation_photos.zip"
          progress={65}
          speed="1.2 MB/s"
          formatted_size="24.5 MB"
          direction="receiving"
          state="transferring"
        />
        <.code_example>
          &lt;.file_transfer
          file_name="photos.zip"
          progress={65} speed="1.2 MB/s"
          formatted_size="24.5 MB"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title={gettext("Sending")} description="File being sent.">
        <.file_transfer
          file_name="document.pdf"
          progress={30}
          speed="850 KB/s"
          formatted_size="8.2 MB"
          direction="sending"
          state="transferring"
        />
      </.showcase_card>

      <.showcase_card title={gettext("Pending (Incoming)")} description="Waiting for acceptance.">
        <.file_transfer
          file_name="setup.exe"
          progress={0}
          formatted_size="156 MB"
          direction="receiving"
          state="offer_received"
        />
      </.showcase_card>

      <.showcase_card title={gettext("Complete")} description="Transfer finished.">
        <.file_transfer
          file_name="music.mp3"
          progress={100}
          formatted_size="4.8 MB"
          state="completed"
        />
      </.showcase_card>

      <.showcase_card title={gettext("Failed")} description="Transfer failed.">
        <.file_transfer
          file_name="large_file.iso"
          progress={42}
          formatted_size="2.1 GB"
          state="failed"
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
