defmodule RetroHexChatWeb.ChatLive.Components.PaintWindow do
  @moduledoc """
  Island for Hex Paint's window body: the drawing (drawn in the browser by
  `PaintHook`), and posting it.

  The picture never round-trips through the server while it is drawn. When
  somebody chooses File ▸ Post to channel…, the hook makes the PNG, uploads it
  straight to storage through this island's `:drawing` upload and asks for the
  Post dialog; the dialog shows the uploaded picture, a conversation to post
  into and a line of text. Post files the upload and hands the message to the
  desktop (`ToolPost.post/3`), which sends it like a recording.

  Mounted inside a server-managed window: closing it unmounts the island, and
  the browser keeps the drawing as a draft for the next time it opens.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.Paint, only: [paint_canvas: 1, tools: 0]
  import RetroHexChatWeb.Components.UI.PostToDialog
  import RetroHexChatWeb.Components.UI.Form, only: [form_description: 1]

  alias RetroHexChat.Chat.Attachments
  alias RetroHexChatWeb.ChatLive.{DirectUpload, ToolPost}

  use RetroHexChatWeb.ChatLive.Components.DialogIsland,
    id: "hex-paint-window",
    known: [:session]

  # A 128-pixel drawing posted at twice its size is far below this.
  @max_png_bytes 2 * 1_024 * 1_024

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(id: @id, session: nil, posting?: false, post_error: nil)
     |> allow_upload(:drawing,
       accept: ~w(.png),
       auto_upload: true,
       external: &presign/2,
       max_entries: 1,
       max_file_size: @max_png_bytes
     )}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("paint_upload_change", _params, socket), do: {:noreply, socket}

  def handle_event("paint_post_open", _params, socket) do
    {:noreply, assign(socket, posting?: true, post_error: nil)}
  end

  def handle_event("paint_post_cancel", _params, socket) do
    {:noreply, socket |> cancel_drawing() |> assign(posting?: false, post_error: nil)}
  end

  def handle_event("paint_post", params, socket) do
    with {:ok, target} <- ToolPost.target(socket.assigns.session, params["target"]),
         {:ok, file_id} <- consume_drawing(socket) do
      :ok = ToolPost.post(target, String.trim(params["caption"] || ""), attachment_ids: [file_id])

      {:noreply, assign(socket, posting?: false, post_error: nil)}
    else
      {:error, reason} -> {:noreply, assign(socket, post_error: reason)}
      :error -> {:noreply, assign(socket, post_error: dgettext("ui", "Choose where to post it."))}
    end
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns =
      assign(assigns,
        entry: List.first(assigns.uploads.drawing.entries),
        options: ToolPost.options(assigns.session),
        upload_errors: upload_errors(assigns.uploads.drawing)
      )

    ~H"""
    <div
      id="hex-paint"
      phx-hook="PaintHook"
      phx-target={@myself}
      tabindex="-1"
      class="relative flex min-h-0 flex-1 flex-col outline-none"
      data-testid="hex-paint"
    >
      <.paint_canvas tools={tools()} />

      <.form
        for={%{}}
        id="hex-paint-upload"
        phx-change="paint_upload_change"
        phx-target={@myself}
        class="hidden"
      >
        <.live_file_input upload={@uploads.drawing} />
      </.form>

      <.post_to_dialog
        :if={@posting?}
        id="hex-paint-post"
        target={@myself}
        title={dgettext("ui", "Post drawing")}
        options={@options}
        selected={ToolPost.default(@session)}
        caption?
        ready?={@entry != nil and @entry.done?}
        error={@post_error || upload_error(@upload_errors, @entry, @uploads.drawing)}
        submit="paint_post"
        cancel="paint_post_cancel"
      >
        <:preview>
          <.live_img_preview :if={@entry} entry={@entry} class="hex-paint__posted" />
          <.form_description :if={@entry && !@entry.done?}>
            {dgettext("ui", "Preparing the picture…")}
          </.form_description>
        </:preview>
      </.post_to_dialog>
    </div>
    """
  end

  defp presign(entry, socket) do
    owner = socket.assigns.session.nickname

    DirectUpload.presign(
      entry,
      socket,
      owner,
      Attachments.directory_path_for(:uploads, "paint", owner)
    )
  end

  defp consume_drawing(socket) do
    case consume_uploaded_entries(socket, :drawing, fn meta, _entry -> {:ok, meta.file_id} end) do
      [file_id] ->
        case Attachments.confirm_uploaded_files([file_id], socket.assigns.session.nickname) do
          {:ok, _files} ->
            {:ok, file_id}

          {:error, _reason} ->
            {:error, dgettext("chat", "Attachment upload could not be confirmed")}
        end

      _none ->
        {:error, dgettext("ui", "The picture is still being prepared.")}
    end
  end

  defp cancel_drawing(socket) do
    Enum.reduce(
      socket.assigns.uploads.drawing.entries,
      socket,
      &cancel_upload(&2, :drawing, &1.ref)
    )
  end

  defp upload_error([error | _], _entry, _upload), do: upload_error_text(error)

  defp upload_error(_none, entry, upload) when not is_nil(entry) do
    case upload_errors(upload, entry) do
      [error | _] -> upload_error_text(error)
      [] -> nil
    end
  end

  defp upload_error(_none, _entry, _upload), do: nil

  defp upload_error_text(:too_large), do: dgettext("ui", "The picture is too large to post.")
  defp upload_error_text(_error), do: dgettext("chat", "Attachment upload failed")
end
