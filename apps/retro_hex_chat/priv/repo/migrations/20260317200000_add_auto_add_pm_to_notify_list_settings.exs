defmodule RetroHexChat.Repo.Migrations.AddAutoAddPmToNotifyListSettings do
  use Ecto.Migration

  def change do
    alter table(:notify_list_settings) do
      add :auto_add_pm, :boolean, null: false, default: true
    end
  end
end
