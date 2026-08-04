defmodule RetroHexChat.Repo.Migrations.CreateChatAttachments do
  use Ecto.Migration

  def change do
    create table(:chat_uploaded_files) do
      add :owner_nickname, :string, null: false, size: 16
      add :original_filename, :string, null: false
      add :content_type, :string, null: false
      add :byte_size, :bigint, null: false
      add :checksum_sha256, :string, size: 64
      add :storage_provider, :string, null: false, default: "s3"
      add :storage_bucket, :string, null: false
      add :storage_key, :text, null: false
      add :directory_path, :text, null: false
      add :logical_path, :text, null: false
      add :status, :string, null: false, default: "uploaded"

      timestamps(type: :utc_datetime_usec)
    end

    create index(:chat_uploaded_files, [:owner_nickname])
    create index(:chat_uploaded_files, [:directory_path])
    create unique_index(:chat_uploaded_files, [:storage_bucket, :storage_key])
    create unique_index(:chat_uploaded_files, [:logical_path])

    create constraint(:chat_uploaded_files, :chat_uploaded_files_byte_size_positive,
             check: "byte_size > 0"
           )

    create constraint(:chat_uploaded_files, :chat_uploaded_files_status_check,
             check: "status IN ('reserved', 'uploaded', 'attached', 'deleted', 'blocked')"
           )

    create constraint(:chat_uploaded_files, :chat_uploaded_files_directory_path_absolute,
             check: "directory_path LIKE '/%'"
           )

    create constraint(:chat_uploaded_files, :chat_uploaded_files_logical_path_absolute,
             check: "logical_path LIKE '/%'"
           )

    create table(:chat_attachments) do
      add :file_id, references(:chat_uploaded_files, on_delete: :restrict), null: false
      add :display_filename, :string, null: false
      add :position, :integer, null: false, default: 0

      add :message_id, references(:messages, on_delete: :delete_all)
      add :private_message_id, references(:private_messages, on_delete: :delete_all)

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:chat_attachments, [:file_id])
    create index(:chat_attachments, [:message_id])
    create index(:chat_attachments, [:private_message_id])
    create unique_index(:chat_attachments, [:message_id, :file_id])
    create unique_index(:chat_attachments, [:private_message_id, :file_id])

    create constraint(:chat_attachments, :chat_attachments_one_message_target,
             check:
               "(message_id IS NOT NULL AND private_message_id IS NULL) OR (message_id IS NULL AND private_message_id IS NOT NULL)"
           )

    create constraint(:chat_attachments, :chat_attachments_position_non_negative,
             check: "position >= 0"
           )
  end
end
