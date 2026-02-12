defmodule RetroHexChat.Repo.Migrations.CreateCustomMenuItems do
  use Ecto.Migration

  def change do
    create table(:custom_menu_items) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          size: 16

      add :menu_type, :string, null: false, size: 10
      add :label, :string, null: false, size: 50
      add :command, :string, null: false, size: 500
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    create index(:custom_menu_items, [:owner_nickname])

    create unique_index(
             :custom_menu_items,
             ["lower(owner_nickname)", :menu_type, "lower(label)"],
             name: :custom_menu_items_owner_type_label_unique
           )
  end
end
