defmodule RetroHexChat.Repo.Migrations.DropPublicArchiveFromRegisteredChannels do
  use Ecto.Migration

  # The rooms' topics promised a public archive that no longer exists. Only
  # those sentences go: a founder's own words around them stay.
  def up do
    execute("""
    UPDATE registered_channels
    SET topic = replace(
      replace(topic, ' Everything said here is published in a public archive.', ''),
      ' This channel is archived publicly.',
      ''
    )
    WHERE topic LIKE '%public archive.%' OR topic LIKE '%archived publicly.%'
    """)

    drop index(:registered_channels, [:name], name: :idx_registered_channels_public_archive)

    alter table(:registered_channels) do
      remove :public_archive
      remove :archive_since
    end
  end

  def down do
    alter table(:registered_channels) do
      add :public_archive, :boolean, null: false, default: false
      add :archive_since, :utc_datetime_usec
    end

    create index(:registered_channels, [:name],
             where: "public_archive = true",
             name: :idx_registered_channels_public_archive
           )
  end
end
