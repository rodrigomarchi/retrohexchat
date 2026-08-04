defmodule RetroHexChat.Accounts.TrustedDevicePreference do
  @moduledoc "Namespaced settings scoped to one remembered nick on one trusted device."
  use Ecto.Schema
  import Ecto.Changeset

  alias RetroHexChat.Accounts.TrustedDevice
  alias RetroHexChat.Services.RegisteredNick

  @type t :: %__MODULE__{}

  schema "trusted_device_preferences" do
    belongs_to :trusted_device, TrustedDevice
    belongs_to :registered_nick, RegisteredNick
    field :namespace, :string
    field :settings, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(preference, attrs) do
    preference
    |> cast(attrs, [:trusted_device_id, :registered_nick_id, :namespace, :settings])
    |> validate_required([:trusted_device_id, :registered_nick_id, :namespace, :settings])
    |> validate_length(:namespace, max: 64)
    |> validate_change(:settings, &validate_settings/2)
    |> foreign_key_constraint(:trusted_device_id)
    |> foreign_key_constraint(:registered_nick_id)
    |> unique_constraint([:trusted_device_id, :registered_nick_id, :namespace],
      name: :trusted_device_preferences_device_nick_namespace_unique
    )
  end

  defp validate_settings(:settings, settings) when is_map(settings), do: []
  defp validate_settings(:settings, _settings), do: [settings: "must be a map"]
end
