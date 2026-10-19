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

    # Whether the channel agreed to be readable from outside, and from when.
    # The instant is the ethical half: nothing said before it is ever
    # published, and turning the archive off keeps it so that turning it back
    # on cannot publish the stretch it was off for.
    field :public_archive, :boolean, default: false
    field :archive_since, :utc_datetime_usec

    # Kept by the server rather than by a founder — a Retro Game's own channel.
    # Nobody registered it, so it never expires for want of activity and
    # nobody can drop it.
    field :system, :boolean, default: false

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

  @doc """
  A channel the server keeps for itself: founded by a service, published, and
  exempt from expiry. Only the server writes one, which is why `changeset/2`
  never casts these fields.
  """
  @spec system_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def system_changeset(channel, attrs) do
    channel
    |> changeset(attrs)
    |> change(system: true)
  end

  defp put_registered_at(%Ecto.Changeset{valid?: true, data: %{registered_at: nil}} = changeset) do
    put_change(changeset, :registered_at, DateTime.utc_now())
  end

  defp put_registered_at(changeset), do: changeset
end
