defmodule RetroHexChat.Presence.NotifyListSettings do
  @moduledoc """
  Ecto schema for notify_list_settings table.
  Stores per-user global settings for the notify list.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:owner_nickname, :string, autogenerate: false}
  schema "notify_list_settings" do
    field :auto_whois, :boolean, default: false

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [:owner_nickname, :auto_whois])
    |> validate_required([:owner_nickname])
  end
end
