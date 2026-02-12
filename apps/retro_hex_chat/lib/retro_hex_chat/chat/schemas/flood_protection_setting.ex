defmodule RetroHexChat.Chat.Schemas.FloodProtectionSetting do
  @moduledoc """
  Ecto schema for flood_protection_settings table.
  Persists per-user flood protection thresholds for registered users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @fields [
    :owner_nickname,
    :flood_threshold,
    :flood_window_seconds,
    :auto_ignore_duration_seconds,
    :spam_threshold,
    :spam_window_seconds,
    :ctcp_reply_limit,
    :ctcp_reply_window_seconds
  ]

  @primary_key {:owner_nickname, :string, autogenerate: false}
  schema "flood_protection_settings" do
    field :flood_threshold, :integer, default: 10
    field :flood_window_seconds, :integer, default: 15
    field :auto_ignore_duration_seconds, :integer, default: 300
    field :spam_threshold, :integer, default: 3
    field :spam_window_seconds, :integer, default: 10
    field :ctcp_reply_limit, :integer, default: 2
    field :ctcp_reply_window_seconds, :integer, default: 10

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(settings, attrs) do
    settings
    |> cast(attrs, @fields)
    |> validate_required([:owner_nickname])
    |> validate_length(:owner_nickname, max: 16)
    |> validate_number(:flood_threshold, greater_than: 0, less_than_or_equal_to: 100)
    |> validate_number(:flood_window_seconds, greater_than: 0, less_than_or_equal_to: 300)
    |> validate_number(:auto_ignore_duration_seconds,
      greater_than: 0,
      less_than_or_equal_to: 86_400
    )
    |> validate_number(:spam_threshold, greater_than: 0, less_than_or_equal_to: 50)
    |> validate_number(:spam_window_seconds, greater_than: 0, less_than_or_equal_to: 120)
    |> validate_number(:ctcp_reply_limit, greater_than: 0, less_than_or_equal_to: 20)
    |> validate_number(:ctcp_reply_window_seconds, greater_than: 0, less_than_or_equal_to: 120)
  end
end
