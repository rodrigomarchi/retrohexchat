defmodule RetroHexChat.Repo.Migrations.AddEmailToRegisteredNicks do
  use Ecto.Migration

  # An address is optional, private, and the only way back into an account whose
  # password is gone. It is never shown to anybody: nothing joins on it and no
  # query selects it for another person.
  def change do
    alter table(:registered_nicks) do
      add :email, :string, size: 254
      add :email_verified_at, :utc_datetime_usec
      add :email_token_hash, :string, size: 64
      add :email_token_sent_at, :utc_datetime_usec
    end

    # Partial, and on the lowercased address: one address belongs to one
    # nickname, while every nickname without one is free to have none. A plain
    # unique index would let the first two address-less registrations collide.
    create unique_index(:registered_nicks, ["lower(email)"],
             where: "email IS NOT NULL",
             name: :idx_registered_nicks_email
           )
  end
end
