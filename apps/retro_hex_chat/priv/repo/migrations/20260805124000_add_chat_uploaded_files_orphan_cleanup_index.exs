defmodule RetroHexChat.Repo.Migrations.AddChatUploadedFilesOrphanCleanupIndex do
  use Ecto.Migration

  def change do
    create index(:chat_uploaded_files, [:status, :inserted_at],
             name: :chat_uploaded_files_orphan_cleanup_idx,
             where: "status IN ('reserved', 'uploaded')"
           )
  end
end
