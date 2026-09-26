defmodule RetroHexChat.Repo.Migrations.AddAvatarToRegisteredNicks do
  use Ecto.Migration

  # Which character a person chose. It belongs to the nickname rather than to a
  # table of its own: it is identity, it is one short string, and it should go
  # when the nickname goes — which the existing row already arranges.
  #
  # Nullable on purpose. Somebody who has never walked into a space has not
  # chosen, and "has not chosen" is a different fact from "chose the default".
  def change do
    alter table(:registered_nicks) do
      add :avatar, :string, size: 20
    end
  end
end
