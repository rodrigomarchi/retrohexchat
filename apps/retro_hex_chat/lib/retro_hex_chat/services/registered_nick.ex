defmodule RetroHexChat.Services.RegisteredNick do
  @moduledoc """
  Ecto schema for NickServ-registered nicknames.
  """
  use Ecto.Schema
  use Gettext, backend: RetroHexChat.Gettext

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "registered_nicks" do
    field :nickname, :string
    field :password_hash, :string
    field :password, :string, virtual: true, redact: true
    field :registered_at, :utc_datetime_usec
    field :last_seen_at, :utc_datetime_usec
    field :email, :string
    field :email_verified_at, :utc_datetime_usec
    field :email_token_hash, :string, redact: true
    field :email_token_sent_at, :utc_datetime_usec
    field :avatar, :string

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
    |> put_last_seen_at()
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(nick, attrs) do
    nick
    |> cast(attrs, [:last_seen_at])
  end

  @doc """
  The optional address, and the pending link that confirms it.

  The address is downcased on the way in because the unique index is on
  `lower(email)`: without it the constraint would fire as a crash instead of a
  changeset error for anybody who typed theirs with a capital.
  """
  @spec email_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def email_changeset(nick, attrs) do
    nick
    |> cast(attrs, [:email, :email_verified_at, :email_token_hash, :email_token_sent_at])
    |> update_change(:email, &normalize_email/1)
    |> validate_length(:email, max: 254)
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@.]+\.[^\s@]+$/,
      message: dgettext("services", "is not a valid address")
    )
    |> unique_constraint(:email, name: :idx_registered_nicks_email)
  end

  @doc """
  A new password from a reset link.

  The same length rule registration applies, because a password chosen through
  recovery is the same password.
  """
  @spec password_reset_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def password_reset_changeset(nick, attrs) do
    nick
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 5, max: 100)
    |> hash_password()
    |> put_change(:email_token_hash, nil)
  end

  defp normalize_email(nil), do: nil

  defp normalize_email(email) when is_binary(email),
    do: email |> String.trim() |> String.downcase()

  defp normalize_email(email), do: email

  defp hash_password(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
  end

  defp hash_password(changeset), do: changeset

  defp put_registered_at(%Ecto.Changeset{valid?: true} = changeset) do
    put_change(changeset, :registered_at, DateTime.utc_now())
  end

  defp put_registered_at(changeset), do: changeset

  defp put_last_seen_at(%Ecto.Changeset{valid?: true} = changeset) do
    put_change(changeset, :last_seen_at, DateTime.utc_now())
  end

  defp put_last_seen_at(changeset), do: changeset

  @spec verify_password(t(), String.t()) :: boolean()
  def verify_password(%__MODULE__{password_hash: hash}, password) do
    Bcrypt.verify_pass(password, hash)
  end
end
