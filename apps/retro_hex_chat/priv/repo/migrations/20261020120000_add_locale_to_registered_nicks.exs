defmodule RetroHexChat.Repo.Migrations.AddLocaleToRegisteredNicks do
  use Ecto.Migration

  # The language the person last used the chat in, drawn as a flag beside
  # their nickname — kept on the row so a message read after they left still
  # says who wrote it in which language.
  def change do
    alter table(:registered_nicks) do
      add :locale, :string, size: 16
    end
  end
end
