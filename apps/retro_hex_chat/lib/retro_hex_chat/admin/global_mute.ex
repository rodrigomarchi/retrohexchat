defmodule RetroHexChat.Admin.GlobalMute do
  @moduledoc "Durable server-wide mute record."

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "global_mutes" do
    field :nickname, :string
    field :normalized_nickname, :string
    field :operator_nickname, :string
    field :reason, :string
    field :expires_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec
    field :revoked_by_nickname, :string
    field :revoke_reason, :string

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(mute, attrs) do
    mute
    |> cast(attrs, [
      :nickname,
      :normalized_nickname,
      :operator_nickname,
      :reason,
      :expires_at,
      :revoked_at,
      :revoked_by_nickname,
      :revoke_reason
    ])
    |> normalize_nickname()
    |> validate_required([:nickname, :normalized_nickname, :operator_nickname])
    |> validate_length(:nickname, max: 16)
    |> validate_length(:normalized_nickname, max: 16)
    |> validate_length(:operator_nickname, max: 16)
    |> validate_length(:reason, max: 255)
    |> validate_length(:revoked_by_nickname, max: 16)
    |> validate_length(:revoke_reason, max: 100)
    |> unique_constraint(:normalized_nickname, name: :idx_global_mutes_active_nickname)
  end

  defp normalize_nickname(changeset) do
    case get_field(changeset, :nickname) do
      nickname when is_binary(nickname) ->
        put_change(changeset, :normalized_nickname, String.downcase(nickname))

      _nickname ->
        changeset
    end
  end
end
