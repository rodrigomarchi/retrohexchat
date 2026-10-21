defmodule RetroHexChat.Repo.Migrations.AddLocaleToBots do
  use Ecto.Migration

  # The language a bot speaks, drawn as a flag beside its nickname like a
  # person's. Set by an admin; nil draws no flag.
  def change do
    alter table(:bots) do
      add :locale, :string, size: 16
    end
  end
end
