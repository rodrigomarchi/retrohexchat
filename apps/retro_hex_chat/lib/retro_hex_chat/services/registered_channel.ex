defmodule RetroHexChat.Services.RegisteredChannel do
  @moduledoc """
  Ecto schema for ChanServ-registered channels.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias RetroHexChat.Channels.Categories
  alias RetroHexChat.Locales

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

    # Exempt from the expiry that clears a founder's quiet channel. No path in
    # the application sets it: `changeset/2` never casts it.
    field :system, :boolean, default: false

    # The language the channel is spoken in (`"pt_BR"`), drawn as a flag
    # beside its name. Only its founder sets it; nil draws no flag.
    field :locale, :string

    # What the channel is about (`"news"`), drawn as a coloured plaque beside
    # its name — one of `RetroHexChat.Channels.Categories`. Founder's to set.
    field :category, :string

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
      :last_activity_at,
      :locale,
      :category
    ])
    |> validate_required([:name, :founder_nickname])
    |> validate_length(:name, max: 50)
    |> validate_length(:founder_nickname, max: 16)
    |> validate_inclusion(:locale, Locales.codes())
    |> validate_inclusion(:category, Categories.codes())
    |> unique_constraint(:name, name: :idx_registered_channels_name)
    |> put_registered_at()
  end

  defp put_registered_at(%Ecto.Changeset{valid?: true, data: %{registered_at: nil}} = changeset) do
    put_change(changeset, :registered_at, DateTime.utc_now())
  end

  defp put_registered_at(changeset), do: changeset
end
