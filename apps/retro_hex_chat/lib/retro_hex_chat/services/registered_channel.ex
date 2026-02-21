defmodule RetroHexChat.Services.RegisteredChannel do
  @moduledoc """
  Ecto schema for ChanServ-registered channels.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "registered_channels" do
    field :name, :string
    field :founder_nickname, :string
    field :topic, :string
    field :modes, :string, default: ""
    field :mode_key, :string
    field :mode_limit, :integer
    field :mode_join_throttle, :string
    field :registered_at, :utc_datetime_usec
    field :last_activity_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [
      :name,
      :founder_nickname,
      :topic,
      :modes,
      :mode_key,
      :mode_limit,
      :mode_join_throttle,
      :last_activity_at
    ])
    |> validate_required([:name, :founder_nickname])
    |> validate_length(:name, max: 50)
    |> validate_length(:founder_nickname, max: 16)
    |> unique_constraint(:name, name: :idx_registered_channels_name)
    |> put_registered_at()
  end

  defp put_registered_at(%Ecto.Changeset{valid?: true, data: %{registered_at: nil}} = changeset) do
    put_change(changeset, :registered_at, DateTime.utc_now())
  end

  defp put_registered_at(changeset), do: changeset
end
