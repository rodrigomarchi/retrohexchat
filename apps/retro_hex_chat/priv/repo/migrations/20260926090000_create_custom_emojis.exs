defmodule RetroHexChat.Repo.Migrations.CreateCustomEmojis do
  use Ecto.Migration

  # An emoji belongs to the server, not to a channel. A self-hosted server is
  # the unit of belonging in this product; a per-channel set would be a shared
  # vocabulary with no one to own it, and the same picture uploaded five times.
  def change do
    create table(:custom_emojis) do
      add :name, :string, null: false, size: 32
      add :uploaded_file_id, references(:chat_uploaded_files, on_delete: :delete_all), null: false
      add :added_by, :string, null: false, size: 16

      timestamps(type: :utc_datetime_usec)
    end

    # One picture per name, whatever case it was typed in: `:Shrug:` and
    # `:shrug:` are the same word to the person typing them.
    create unique_index(:custom_emojis, ["lower(name)"], name: :custom_emojis_lower_name_index)
    create index(:custom_emojis, [:uploaded_file_id])
  end
end
