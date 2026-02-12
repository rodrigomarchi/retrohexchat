defmodule RetroHexChat.Repo.Migrations.CreateNoticeRoutingSettings do
  use Ecto.Migration

  def change do
    create table(:notice_routing_settings, primary_key: false) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          primary_key: true,
          size: 16

      add :routing, :string, null: false, default: "active"

      timestamps(type: :utc_datetime_usec)
    end

    create constraint(:notice_routing_settings, :routing_valid_values,
             check: "routing IN ('active', 'status', 'sender')"
           )
  end
end
