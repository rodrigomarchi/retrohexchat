defmodule RetroHexChatWeb.ShowcaseLive.FileTransferPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.FileTransfer
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "File Transfer", active_page: "file-transfer")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">File Transfer</h2>

      <.showcase_card title="Receiving" description="File being received with progress.">
        <.file_transfer
          filename="vacation_photos.zip"
          progress={65}
          speed="1.2 MB/s"
          size="24.5 MB"
          direction="receiving"
        />
        <.code_example>
          &lt;.file_transfer
            filename="photos.zip"
            progress={65}
            speed="1.2 MB/s"
            size="24.5 MB"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="Sending" description="File being sent.">
        <.file_transfer
          filename="document.pdf"
          progress={30}
          speed="850 KB/s"
          size="8.2 MB"
          direction="sending"
        />
      </.showcase_card>

      <.showcase_card title="Just Started" description="Transfer just beginning.">
        <.file_transfer
          filename="setup.exe"
          progress={2}
          speed="100 KB/s"
          size="156 MB"
        />
      </.showcase_card>

      <.showcase_card title="Almost Done" description="Transfer nearly complete.">
        <.file_transfer
          filename="music.mp3"
          progress={98}
          speed="2.1 MB/s"
          size="4.8 MB"
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
