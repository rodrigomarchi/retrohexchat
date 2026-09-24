defmodule RetroHexChat.Repo.Migrations.AddPublicArchiveToRegisteredChannels do
  use Ecto.Migration

  # Two columns, and the second is the ethical one. `public_archive` says a
  # channel agreed to be readable from outside; `archive_since` says when, and
  # nothing said before that instant is ever published — whoever wrote it wrote
  # it under a different expectation.
  def change do
    alter table(:registered_channels) do
      add :public_archive, :boolean, null: false, default: false
      add :archive_since, :utc_datetime_usec
    end

    # The archive index asks one question of this table: which channels are
    # published. Partial, because almost none of them are.
    create index(:registered_channels, [:name],
             where: "public_archive = true",
             name: :idx_registered_channels_public_archive
           )
  end
end
