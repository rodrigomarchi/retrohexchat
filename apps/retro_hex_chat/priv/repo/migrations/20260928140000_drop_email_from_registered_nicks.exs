defmodule RetroHexChat.Repo.Migrations.DropEmailFromRegisteredNicks do
  use Ecto.Migration

  # The product does not send mail. Recovery by e-mail was the one thing that
  # made this server need a relay it does not host, and it is gone — so the
  # columns holding an address, its confirmation and the hash of a pending link
  # hold nothing anybody can act on. A column kept "in case" is a column that
  # still has to be reasoned about on every read of this table, and an address
  # is the kind of data whose safest state is absent.
  #
  # `up` drops the address itself, not only the plumbing: leaving the column
  # while removing the feature would keep personal data on a server that has no
  # use for it.
  def up do
    drop_if_exists index(:registered_nicks, ["lower(email)"], name: :idx_registered_nicks_email)

    alter table(:registered_nicks) do
      remove :email
      remove :email_verified_at
      remove :email_token_hash
      remove :email_token_sent_at
    end
  end

  # Reversible in shape, never in content. Rolling back restores the columns and
  # the index; the addresses are not coming back, which is the point.
  def down do
    alter table(:registered_nicks) do
      add :email, :string, size: 254
      add :email_verified_at, :utc_datetime_usec
      add :email_token_hash, :string, size: 64
      add :email_token_sent_at, :utc_datetime_usec
    end

    create unique_index(:registered_nicks, ["lower(email)"],
             where: "email IS NOT NULL",
             name: :idx_registered_nicks_email
           )
  end
end
