defmodule RetroHexChat.Channels.ChannelMute do
  @moduledoc "Durable channel-level mute record."

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "channel_mutes" do
    field :channel_name, :string
    field :target_nickname, :string
    field :normalized_target, :string
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
      :channel_name,
      :target_nickname,
      :normalized_target,
      :operator_nickname,
      :reason,
      :expires_at,
      :revoked_at,
      :revoked_by_nickname,
      :revoke_reason
    ])
    |> normalize_target()
    |> validate_required([
      :channel_name,
      :target_nickname,
      :normalized_target,
      :operator_nickname
    ])
    |> validate_length(:channel_name, max: 100)
    |> validate_length(:target_nickname, max: 16)
    |> validate_length(:normalized_target, max: 16)
    |> validate_length(:operator_nickname, max: 16)
    |> validate_length(:reason, max: 255)
    |> validate_length(:revoked_by_nickname, max: 16)
    |> validate_length(:revoke_reason, max: 100)
    |> unique_constraint([:channel_name, :normalized_target],
      name: :idx_channel_mutes_active_target
    )
  end

  defp normalize_target(changeset) do
    case get_field(changeset, :target_nickname) do
      target when is_binary(target) ->
        put_change(changeset, :normalized_target, String.downcase(target))

      _target ->
        changeset
    end
  end
end
