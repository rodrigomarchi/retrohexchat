defmodule RetroHexChat.Repo.Migrations.CreateReconnectStates do
  use Ecto.Migration

  def change do
    create table(:reconnect_states, primary_key: false) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          primary_key: true,
          size: 16

      add :channels, {:array, :string}, null: false, default: []
      add :active_channel, :string
      add :active_pm, :string
      add :open_pm_tabs, {:array, :string}, null: false, default: []
      add :tab_order, {:array, :map}, null: false, default: []
      add :welcomed_channels, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime_usec)
    end
  end
end
