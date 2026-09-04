defmodule RetroHexChat.Chat.UploadedFile do
  @moduledoc """
  Metadata for a file stored outside Postgres through an S3-compatible API.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias RetroHexChat.Chat.Attachment
  alias RetroHexChat.Chat.Attachments.Preview

  @type t :: %__MODULE__{}

  @statuses ~w(reserved uploaded attached deleted blocked)

  schema "chat_uploaded_files" do
    field :owner_nickname, :string
    field :original_filename, :string
    field :content_type, :string
    field :byte_size, :integer
    field :checksum_sha256, :string
    field :storage_provider, :string, default: "s3"
    field :storage_bucket, :string
    field :storage_key, :string
    field :directory_path, :string
    field :logical_path, :string
    field :preview_kind, :string, default: "download"
    field :preview_status, :string, default: "none"
    field :preview_metadata, :map, default: %{}
    field :status, :string, default: "uploaded"

    has_many :attachments, Attachment, foreign_key: :file_id

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(uploaded_file, attrs) do
    uploaded_file
    |> cast(attrs, [
      :owner_nickname,
      :original_filename,
      :content_type,
      :byte_size,
      :checksum_sha256,
      :storage_provider,
      :storage_bucket,
      :storage_key,
      :directory_path,
      :logical_path,
      :preview_kind,
      :preview_status,
      :preview_metadata,
      :status
    ])
    |> validate_required([
      :owner_nickname,
      :original_filename,
      :content_type,
      :byte_size,
      :storage_provider,
      :storage_bucket,
      :storage_key,
      :directory_path,
      :logical_path,
      :preview_kind,
      :preview_status,
      :preview_metadata,
      :status
    ])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_length(:original_filename, max: 255)
    |> validate_length(:content_type, max: 255)
    |> validate_length(:checksum_sha256, is: 64)
    |> validate_number(:byte_size, greater_than: 0)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:preview_kind, Preview.kinds())
    |> validate_inclusion(:preview_status, Preview.statuses())
    |> validate_absolute_path(:directory_path)
    |> validate_absolute_path(:logical_path)
    |> check_constraint(:byte_size, name: :chat_uploaded_files_byte_size_positive)
    |> check_constraint(:status, name: :chat_uploaded_files_status_check)
    |> check_constraint(:preview_kind, name: :chat_uploaded_files_preview_kind_check)
    |> check_constraint(:preview_status, name: :chat_uploaded_files_preview_status_check)
    |> check_constraint(:directory_path, name: :chat_uploaded_files_directory_path_absolute)
    |> check_constraint(:logical_path, name: :chat_uploaded_files_logical_path_absolute)
    |> unique_constraint([:storage_bucket, :storage_key])
    |> unique_constraint(:logical_path)
  end

  defp validate_absolute_path(changeset, field) do
    case get_field(changeset, field) do
      "/" <> _ -> changeset
      _ -> add_error(changeset, field, "must be absolute")
    end
  end
end
