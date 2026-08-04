defmodule RetroHexChat.Chat.Attachments do
  @moduledoc """
  Domain entry point for file attachments backed by S3-compatible storage.
  """

  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Chat.{Attachment, PrivateMessage, Queries, UploadedFile}
  alias RetroHexChat.Chat.Attachments.Preview
  alias RetroHexChat.Chat.Message

  @default_content_type "application/octet-stream"
  @default_max_size_mb 25

  @type upload_metadata :: %{
          optional(:filename) => String.t(),
          optional(:content_type) => String.t(),
          optional(:byte_size) => non_neg_integer(),
          optional(:directory_path) => String.t()
        }

  @spec max_size_bytes() :: pos_integer()
  def max_size_bytes do
    max_size_mb() * 1_024 * 1_024
  end

  @spec directory_path_for(:channel | :private | :uploads, String.t(), String.t(), Date.t()) ::
          String.t()
  def directory_path_for(kind, scope, owner_nickname, date \\ Date.utc_today())

  def directory_path_for(:channel, channel_name, owner_nickname, date) do
    absolute_path([
      "chat",
      "channels",
      path_component(channel_name),
      date.year,
      pad(date.month),
      pad(date.day),
      path_component(owner_nickname)
    ])
  end

  def directory_path_for(:private, peer_nickname, owner_nickname, date) do
    absolute_path([
      "chat",
      "private",
      path_component(peer_nickname),
      date.year,
      pad(date.month),
      pad(date.day),
      path_component(owner_nickname)
    ])
  end

  def directory_path_for(:uploads, scope, owner_nickname, date) do
    absolute_path([
      "chat",
      "uploads",
      path_component(scope),
      date.year,
      pad(date.month),
      pad(date.day),
      path_component(owner_nickname)
    ])
  end

  @spec prepare_direct_upload(String.t(), upload_metadata()) ::
          {:ok, UploadedFile.t(), map()} | {:error, term()}
  def prepare_direct_upload(owner_nickname, metadata) do
    attrs = file_attrs(owner_nickname, metadata, nil, "reserved")

    with :ok <- validate_size(attrs.byte_size),
         {:ok, upload} <-
           storage().presigned_put_url(attrs.storage_bucket, attrs.storage_key,
             content_type: attrs.content_type,
             byte_size: attrs.byte_size,
             expires_in: 300
           ),
         {:ok, uploaded_file} <- Queries.insert_uploaded_file(attrs) do
      {:ok, uploaded_file, Map.merge(upload, %{uploader: "S3Direct", file_id: uploaded_file.id})}
    end
  end

  @spec confirm_uploaded_files([integer() | String.t()], String.t()) ::
          {:ok, [UploadedFile.t()]} | {:error, :attachment_not_found}
  def confirm_uploaded_files(ids, owner_nickname) do
    Queries.mark_uploaded_files(ids, owner_nickname)
  end

  @spec store_upload(String.t(), Path.t(), upload_metadata()) ::
          {:ok, UploadedFile.t()} | {:error, term()}
  def store_upload(owner_nickname, path, metadata) do
    byte_size = upload_size(path, Map.get(metadata, :byte_size))
    attrs = file_attrs(owner_nickname, Map.put(metadata, :byte_size, byte_size), nil, "uploaded")

    with :ok <- validate_size(byte_size),
         {:ok, checksum_sha256} <- checksum_sha256(path),
         {:ok, _stored} <-
           storage().put_file(path, attrs.storage_key,
             bucket: attrs.storage_bucket,
             content_type: attrs.content_type,
             byte_size: attrs.byte_size
           ) do
      attrs
      |> Map.put(:checksum_sha256, checksum_sha256)
      |> Queries.insert_uploaded_file()
    end
  end

  @spec get_attachment(integer() | String.t()) :: Attachment.t() | nil
  def get_attachment(id), do: Queries.get_attachment(id)

  @spec download_url(Attachment.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def download_url(%Attachment{file: %UploadedFile{} = file}, opts \\ []) do
    storage().presigned_get_url(file.storage_bucket, file.storage_key, opts)
  end

  @spec inline_preview?(Attachment.t() | UploadedFile.t() | map()) :: boolean()
  def inline_preview?(%Attachment{file: %UploadedFile{} = file}), do: Preview.inline?(file)
  def inline_preview?(%UploadedFile{} = file), do: Preview.inline?(file)
  def inline_preview?(%{} = file), do: Preview.inline?(file)

  @spec visible_to?(Attachment.t(), String.t()) :: boolean()
  def visible_to?(%Attachment{private_message: %PrivateMessage{deleted_at: nil} = pm}, nickname) do
    nickname in [pm.sender_nickname, pm.recipient_nickname]
  end

  def visible_to?(%Attachment{message: %Message{deleted_at: nil}}, nickname)
      when is_binary(nickname) do
    nickname != ""
  end

  def visible_to?(_attachment, _nickname), do: false

  @spec bucket() :: String.t()
  def bucket, do: Keyword.fetch!(config(), :bucket)

  @spec storage() :: module()
  def storage, do: Keyword.fetch!(config(), :storage)

  @spec payload(Attachment.t() | map()) :: map() | nil
  def payload(%Attachment{file: %Ecto.Association.NotLoaded{}}), do: nil

  def payload(%Attachment{file: %UploadedFile{} = file} = attachment) do
    payload_from_file(attachment, file)
  end

  def payload(%{file: %Ecto.Association.NotLoaded{}}), do: nil

  def payload(%{file: %UploadedFile{} = file} = attachment) do
    payload_from_file(attachment, file)
  end

  def payload(%{id: _id} = attachment), do: attachment
  def payload(_attachment), do: nil

  defp payload_from_file(attachment, file) do
    %{
      id: Map.get(attachment, :id),
      file_id: file.id,
      filename: Map.get(attachment, :display_filename) || file.original_filename,
      content_type: file.content_type,
      byte_size: file.byte_size,
      directory_path: file.directory_path,
      logical_path: file.logical_path,
      preview_kind:
        file.preview_kind || Preview.classify(file.original_filename, file.content_type),
      preview_status: file.preview_status || "none",
      preview_metadata: file.preview_metadata || %{}
    }
  end

  defp config do
    Application.get_env(:retro_hex_chat, :chat_uploads, [])
  end

  defp max_size_mb do
    Keyword.get(config(), :max_size_mb, @default_max_size_mb)
  end

  defp upload_size(_path, byte_size) when is_integer(byte_size) and byte_size > 0, do: byte_size

  defp upload_size(path, _byte_size) do
    case File.stat(path) do
      {:ok, %{size: size}} -> size
      _ -> 0
    end
  end

  defp validate_size(byte_size) when byte_size > 0 do
    if byte_size <= max_size_bytes(), do: :ok, else: max_size_error()
  end

  defp validate_size(0), do: {:error, dgettext("chat", "Attachment is empty")}
  defp validate_size(_byte_size), do: max_size_error()

  defp max_size_error do
    {:error,
     dgettext("chat", "Attachment exceeds the %{mb} MB limit",
       mb: Integer.to_string(max_size_mb())
     )}
  end

  defp file_attrs(owner_nickname, metadata, checksum_sha256, status) do
    uuid = Ecto.UUID.generate()
    original_filename = clean_filename(Map.get(metadata, :filename, dgettext("chat", "file")))
    content_type = clean_content_type(Map.get(metadata, :content_type))
    byte_size = Map.get(metadata, :byte_size, 0)
    directory_path = clean_directory_path(Map.get(metadata, :directory_path), owner_nickname)
    preview_kind = Preview.classify(original_filename, content_type)

    %{
      owner_nickname: owner_nickname,
      original_filename: original_filename,
      content_type: content_type,
      byte_size: byte_size,
      checksum_sha256: checksum_sha256,
      storage_provider: "s3",
      storage_bucket: bucket(),
      storage_key: object_key(owner_nickname, uuid),
      directory_path: directory_path,
      logical_path: Path.join(directory_path, logical_filename(uuid, original_filename)),
      preview_kind: preview_kind,
      preview_status: Preview.initial_status(preview_kind, content_type),
      preview_metadata: %{},
      status: status
    }
  end

  defp checksum_sha256(path) do
    case File.read(path) do
      {:ok, body} ->
        checksum =
          body
          |> then(&:crypto.hash(:sha256, &1))
          |> Base.encode16(case: :lower)

        {:ok, checksum}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp object_key(owner_nickname, uuid) do
    date = Date.utc_today()
    safe_owner = path_component(owner_nickname)

    "chat/#{date.year}/#{pad(date.month)}/#{pad(date.day)}/#{safe_owner}/#{uuid}"
  end

  defp pad(value) when value < 10, do: "0#{value}"
  defp pad(value), do: Integer.to_string(value)

  defp clean_directory_path(nil, owner_nickname),
    do: directory_path_for(:uploads, "composer", owner_nickname)

  defp clean_directory_path(path, owner_nickname) when is_binary(path) do
    path
    |> String.split("/", trim: true)
    |> Enum.map(&path_component/1)
    |> Enum.reject(&(&1 == ""))
    |> case do
      [] -> directory_path_for(:uploads, "composer", owner_nickname)
      segments -> absolute_path(segments)
    end
  end

  defp clean_directory_path(_path, owner_nickname),
    do: directory_path_for(:uploads, "composer", owner_nickname)

  defp logical_filename(uuid, filename) do
    "#{uuid}-#{path_component(filename)}"
  end

  defp absolute_path(segments) do
    "/" <>
      (segments
       |> Enum.map(&to_string/1)
       |> Enum.map(&path_component/1)
       |> Enum.reject(&(&1 == ""))
       |> Enum.join("/"))
  end

  defp path_component(value) do
    value
    |> to_string()
    |> String.replace(~r/[^A-Za-z0-9._-]+/, "_")
    |> String.replace(~r/(^[._-]+|[._-]+$)/, "")
    |> case do
      "" -> "item"
      clean -> String.slice(clean, 0, 120)
    end
  end

  defp clean_filename(filename) when is_binary(filename) do
    filename
    |> Path.basename()
    |> String.replace(~r/[\x00-\x1F\x7F]/, "")
    |> String.trim()
    |> case do
      "" -> dgettext("chat", "file")
      clean -> String.slice(clean, 0, 255)
    end
  end

  defp clean_filename(_filename), do: dgettext("chat", "file")

  defp clean_content_type(content_type) when is_binary(content_type) and content_type != "" do
    String.slice(content_type, 0, 255)
  end

  defp clean_content_type(_content_type), do: @default_content_type
end
