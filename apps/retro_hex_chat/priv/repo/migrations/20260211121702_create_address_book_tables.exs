defmodule RetroHexChat.Repo.Migrations.CreateAddressBookTables do
  use Ecto.Migration

  def change do
    create table(:contacts) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          size: 16

      add :contact_nickname, :string, null: false, size: 16
      add :note, :string, size: 200
      add :first_contact_date, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(
             :contacts,
             ["lower(owner_nickname)", "lower(contact_nickname)"],
             name: :idx_contacts_owner_contact
           )

    create index(:contacts, [:owner_nickname], name: :idx_contacts_owner)

    create table(:nick_color_overrides) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          size: 16

      add :target_nickname, :string, null: false, size: 16
      add :color_index, :integer, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(
             :nick_color_overrides,
             ["lower(owner_nickname)", "lower(target_nickname)"],
             name: :idx_nick_colors_owner_target
           )

    create index(:nick_color_overrides, [:owner_nickname], name: :idx_nick_colors_owner)
  end
end
