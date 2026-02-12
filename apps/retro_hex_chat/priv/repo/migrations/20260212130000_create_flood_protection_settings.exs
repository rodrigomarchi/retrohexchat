defmodule RetroHexChat.Repo.Migrations.CreateFloodProtectionSettings do
  use Ecto.Migration

  def change do
    create table(:flood_protection_settings, primary_key: false) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          primary_key: true,
          size: 16

      add :flood_threshold, :integer, null: false, default: 10
      add :flood_window_seconds, :integer, null: false, default: 15
      add :auto_ignore_duration_seconds, :integer, null: false, default: 300
      add :spam_threshold, :integer, null: false, default: 3
      add :spam_window_seconds, :integer, null: false, default: 10
      add :ctcp_reply_limit, :integer, null: false, default: 2
      add :ctcp_reply_window_seconds, :integer, null: false, default: 10

      timestamps(type: :utc_datetime_usec)
    end

    create constraint(:flood_protection_settings, :flood_threshold_range,
             check: "flood_threshold > 0 AND flood_threshold <= 100"
           )

    create constraint(:flood_protection_settings, :flood_window_seconds_range,
             check: "flood_window_seconds > 0 AND flood_window_seconds <= 300"
           )

    create constraint(:flood_protection_settings, :auto_ignore_duration_seconds_range,
             check: "auto_ignore_duration_seconds > 0 AND auto_ignore_duration_seconds <= 86400"
           )

    create constraint(:flood_protection_settings, :spam_threshold_range,
             check: "spam_threshold > 0 AND spam_threshold <= 50"
           )

    create constraint(:flood_protection_settings, :spam_window_seconds_range,
             check: "spam_window_seconds > 0 AND spam_window_seconds <= 120"
           )

    create constraint(:flood_protection_settings, :ctcp_reply_limit_range,
             check: "ctcp_reply_limit > 0 AND ctcp_reply_limit <= 20"
           )

    create constraint(:flood_protection_settings, :ctcp_reply_window_seconds_range,
             check: "ctcp_reply_window_seconds > 0 AND ctcp_reply_window_seconds <= 120"
           )
  end
end
