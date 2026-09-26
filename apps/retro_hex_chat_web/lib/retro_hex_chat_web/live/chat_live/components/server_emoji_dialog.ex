defmodule RetroHexChatWeb.ChatLive.Components.ServerEmojiDialog do
  @moduledoc """
  Stateful island behind the Server Emoji window.

  Owns the upload, because an upload is state: LiveView keeps the entries and
  the progress, and the island is where `allow_upload/3` can live without the
  whole chat carrying it.

  The picture goes up by the same presigned direct-upload path an attachment
  uses — that is what gives this feature a size limit, a storage backend and
  orphan cleanup without any of the three being written a second time. The
  emoji row is written only once the file is there, so a failed upload leaves
  no name pointing at nothing.

  The permission is checked here and again where the write happens. Drawing a
  form is a convenience; refusing is the server's.
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.ServerEmojiDialog

  alias RetroHexChat.Accounts.ServerRoles
  alias RetroHexChat.Chat.Attachments
  alias RetroHexChat.Chat.CustomEmojis

  @id "server-emoji-dialog"

  # A joke-sized picture. The attachment ceiling is for files somebody sends on
  # purpose; an emoji is drawn on every line it appears in.
  @max_bytes 512 * 1024

  @doc "Stable DOM/component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(
       id: @id,
       nickname: nil,
       identified: false,
       name: "",
       error: nil,
       emojis: CustomEmojis.all()
     )
     |> allow_upload(:emoji,
       accept: ~w(.png .gif .webp .jpg .jpeg),
       auto_upload: true,
       external: &presign/2,
       max_entries: 1,
       max_file_size: @max_bytes
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign(emojis: CustomEmojis.all())}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("server_emoji_validate", params, socket) do
    {:noreply, assign(socket, name: Map.get(params, "name", ""), error: nil)}
  end

  def handle_event("server_emoji_add", params, socket) do
    name = params |> Map.get("name", "") |> String.trim()

    if admin?(socket) do
      {:noreply, add(socket, name)}
    else
      {:noreply, assign(socket, error: dgettext("dialogs", "Server administrators only."))}
    end
  end

  def handle_event("server_emoji_remove", %{"id" => id}, socket) do
    if admin?(socket) do
      id |> to_integer() |> CustomEmojis.remove()
      {:noreply, assign(socket, emojis: CustomEmojis.all(), error: nil)}
    else
      {:noreply, assign(socket, error: dgettext("dialogs", "Server administrators only."))}
    end
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.server_emoji_panel
        id={@id}
        emojis={@emojis}
        max_count={CustomEmojis.max_count()}
        upload={@uploads.emoji}
        name={@name}
        error={@error}
        target={@myself}
      />
    </div>
    """
  end

  # The file ids the browser has finished putting into storage. Consuming them
  # is what marks the upload done; a name is written only against one of these.
  defp add(socket, name) do
    case consume_uploaded_entries(socket, :emoji, fn meta, _entry -> {:ok, meta.file_id} end) do
      [file_id | _rest] ->
        write(socket, name, file_id)

      [] ->
        assign(socket, error: dgettext("dialogs", "Choose a picture first."))
    end
  end

  defp write(socket, name, file_id) do
    case CustomEmojis.add(name, file_id, socket.assigns.nickname) do
      {:ok, _emoji} ->
        assign(socket, name: "", error: nil, emojis: CustomEmojis.all())

      {:error, message} ->
        assign(socket, error: message, emojis: CustomEmojis.all())
    end
  end

  defp presign(entry, socket) do
    metadata = %{
      filename: entry.client_name,
      content_type: entry.client_type,
      byte_size: entry.client_size,
      directory_path: Attachments.directory_path_for(:uploads, "emoji", "server")
    }

    case Attachments.prepare_direct_upload(socket.assigns.nickname || "server", metadata) do
      {:ok, _uploaded_file, meta} -> {:ok, meta, socket}
      {:error, _reason} -> {:error, %{reason: "upload_failed"}, socket}
    end
  end

  defp admin?(%{assigns: %{nickname: nickname, identified: identified}})
       when is_binary(nickname) do
    ServerRoles.admin?(nickname, identified) or
      ServerRoles.server_operator?(nickname, identified)
  end

  defp admin?(_socket), do: false

  defp to_integer(value) when is_integer(value), do: value

  defp to_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, _rest} -> id
      :error -> 0
    end
  end

  defp to_integer(_value), do: 0
end
