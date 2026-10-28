defmodule RetroHexChatWeb.ChatLive.DirectUpload do
  @moduledoc """
  A file the browser sends straight to storage: a LiveView upload's `external`
  callback reserves its row under its owner and folder, and answers with the
  presigned address the browser puts the bytes to.

  The composer's attachments and recordings and Hex Paint's drawings all
  arrive this way; each says only who owns the file, where it is filed and
  what is known about it beforehand.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Chat.Attachments

  @doc "The `external:` answer for `entry`: its reservation, or why it could not be made."
  @spec presign(map(), Phoenix.LiveView.Socket.t(), String.t(), String.t(), map()) ::
          {:ok, map(), Phoenix.LiveView.Socket.t()}
          | {:error, %{reason: String.t()}, Phoenix.LiveView.Socket.t()}
  def presign(entry, socket, owner, directory_path, preview_metadata \\ %{}) do
    metadata = %{
      filename: entry.client_name,
      content_type: entry.client_type,
      byte_size: entry.client_size,
      directory_path: directory_path,
      preview_metadata: preview_metadata
    }

    case Attachments.prepare_direct_upload(owner, metadata) do
      {:ok, _uploaded_file, meta} -> {:ok, meta, socket}
      {:error, reason} -> {:error, %{reason: store_error(reason)}, socket}
    end
  end

  @doc "Why a file could not be stored, in words."
  @spec store_error(term()) :: String.t()
  def store_error(reason) when is_binary(reason), do: reason

  def store_error(reason) do
    dgettext("chat", "Could not store attachment: %{reason}", reason: inspect(reason))
  end
end
