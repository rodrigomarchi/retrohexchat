defmodule RetroHexChat.Services.RegisteredNick do
  @moduledoc """
  Ecto schema for NickServ-registered nicknames.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "registered_nicks" do
    field :nickname, :string
    field :password_hash, :string
    field :password, :string, virtual: true, redact: true
    field :registered_at, :utc_datetime_usec
    field :last_seen_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @spec registration_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def registration_changeset(nick, attrs) do
    nick
    |> cast(attrs, [:nickname, :password])
    |> validate_required([:nickname, :password])
    |> validate_length(:nickname, max: 16)
    |> validate_length(:password, min: 5, max: 100)
    |> unique_constraint(:nickname, name: :idx_registered_nicks_nickname)
    |> hash_password()
    |> put_registered_at()
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(nick, attrs) do
    nick
    |> cast(attrs, [:last_seen_at])
  end

  defp hash_password(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
  end

  defp hash_password(changeset), do: changeset

  defp put_registered_at(%Ecto.Changeset{valid?: true} = changeset) do
    put_change(changeset, :registered_at, DateTime.utc_now())
  end

  defp put_registered_at(changeset), do: changeset

  @spec verify_password(t(), String.t()) :: boolean()
  def verify_password(%__MODULE__{password_hash: hash}, password) do
    Bcrypt.verify_pass(password, hash)
  end
end
