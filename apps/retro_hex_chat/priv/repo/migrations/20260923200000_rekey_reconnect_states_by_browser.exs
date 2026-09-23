defmodule RetroHexChat.Repo.Migrations.RekeyReconnectStatesByBrowser do
  use Ecto.Migration

  # What somebody had on screen is a fact about a browser, not about a person:
  # the same nickname on a desktop and on a phone are two screens with two
  # channel lists and two places they had got to. One row per person made the
  # second screen overwrite the first.
  #
  # The empty string is a browser like any other — it is what a browser with no
  # cookie sends, and what every row written before this column existed holds.
  def up do
    alter table(:reconnect_states) do
      add :browser_id, :string, null: false, default: "", size: 64
    end

    execute "ALTER TABLE reconnect_states DROP CONSTRAINT reconnect_states_pkey"

    execute "ALTER TABLE reconnect_states ADD PRIMARY KEY (owner_nickname, browser_id)"
  end

  def down do
    execute "DELETE FROM reconnect_states WHERE browser_id <> ''"

    execute "ALTER TABLE reconnect_states DROP CONSTRAINT reconnect_states_pkey"

    execute "ALTER TABLE reconnect_states ADD PRIMARY KEY (owner_nickname)"

    alter table(:reconnect_states) do
      remove :browser_id
    end
  end
end
