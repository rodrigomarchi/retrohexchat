defmodule RetroHexChat.Repo.Migrations.AddPreviewFieldsToChatUploadedFiles do
  use Ecto.Migration

  def change do
    alter table(:chat_uploaded_files) do
      add :preview_kind, :string, null: false, default: "download"
      add :preview_status, :string, null: false, default: "none"
      add :preview_storage_key, :text
      add :preview_metadata, :map, null: false, default: %{}
    end

    create index(:chat_uploaded_files, [:preview_kind])

    create constraint(:chat_uploaded_files, :chat_uploaded_files_preview_kind_check,
             check:
               "preview_kind IN ('image', 'video', 'audio', 'pdf', 'text', 'code', 'archive', 'office', 'download')"
           )

    create constraint(:chat_uploaded_files, :chat_uploaded_files_preview_status_check,
             check: "preview_status IN ('none', 'pending', 'ready', 'failed', 'blocked')"
           )
  end
end
