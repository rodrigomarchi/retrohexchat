defmodule RetroHexChat.Accounts.ContactEntry do
  @moduledoc """
  Ecto schema for contacts table.
  Persists address book entries for registered users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "contacts" do
    field :owner_nickname, :string
    field :contact_nickname, :string
    field :note, :string
    field :first_contact_date, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:owner_nickname, :contact_nickname, :note, :first_contact_date])
    |> validate_required([:owner_nickname, :contact_nickname, :first_contact_date])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_length(:contact_nickname, max: 16)
    |> validate_length(:note, max: 200)
  end
end
