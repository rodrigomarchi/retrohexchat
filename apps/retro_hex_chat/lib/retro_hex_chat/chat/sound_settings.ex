defmodule RetroHexChat.Chat.SoundSettings do
  @moduledoc """
  Domain module for managing per-event sound and flash preferences.

  Provides in-memory CRUD operations on the settings map
  and persistence functions (save/2, load/1) for registered users.
  """

  alias RetroHexChat.Chat.Schemas.SoundSetting
  alias RetroHexChat.Repo

  @event_types [
    :message,
    :pm,
    :highlight,
    :join,
    :part,
    :kick,
    :connect,
    :disconnect,
    :buddy_online,
    :buddy_offline
  ]

  @sound_catalog [
    {"none", "None"},
    {"beep", "Beep"},
    {"ding_low", "Ding Low"},
    {"ding_high", "Ding High"},
    {"chime_short", "Chime Short"},
    {"chime_long", "Chime Long"},
    {"chime_high", "Chime High"},
    {"chime_low", "Chime Low"},
    {"alert", "Alert"},
    {"buzz", "Buzz"},
    {"click", "Click"},
    {"ring", "Ring"},
    {"notify", "Notify"},
    {"blip", "Blip"},
    {"whoosh", "Whoosh"}
  ]

  @valid_sound_names Enum.map(@sound_catalog, &elem(&1, 0))

  @default_sound_mappings %{
    message: "ding_low",
    pm: "chime_high",
    highlight: "alert",
    join: "click",
    part: "click",
    kick: "buzz",
    connect: "chime_short",
    disconnect: "chime_low",
    buddy_online: "notify",
    buddy_offline: "blip"
  }

  @default_flash_settings %{
    message: false,
    pm: true,
    highlight: true,
    join: false,
    part: false,
    kick: false,
    connect: false,
    disconnect: false,
    buddy_online: true,
    buddy_offline: false
  }

  # ---------------------------------------------------------------------------
  # In-Memory CRUD
  # ---------------------------------------------------------------------------

  @spec new() :: map()
  def new do
    %{
      sound_mappings: @default_sound_mappings,
      flash_settings: @default_flash_settings
    }
  end

  @spec get_sound(map(), atom()) :: String.t()
  def get_sound(%{sound_mappings: mappings}, event_type) when event_type in @event_types do
    Map.get(mappings, event_type, "none")
  end

  @spec set_sound(map(), atom(), String.t()) :: map()
  def set_sound(settings, event_type, sound_name)
      when event_type in @event_types and sound_name in @valid_sound_names do
    put_in(settings, [:sound_mappings, event_type], sound_name)
  end

  @spec get_flash(map(), atom()) :: boolean()
  def get_flash(%{flash_settings: flash}, event_type) when event_type in @event_types do
    Map.get(flash, event_type, false)
  end

  @spec set_flash(map(), atom(), boolean()) :: map()
  def set_flash(settings, event_type, enabled)
      when event_type in @event_types and is_boolean(enabled) do
    put_in(settings, [:flash_settings, event_type], enabled)
  end

  @spec get_sound_mappings(map()) :: map()
  def get_sound_mappings(%{sound_mappings: mappings}), do: mappings

  @spec get_flash_settings(map()) :: map()
  def get_flash_settings(%{flash_settings: flash}), do: flash

  @spec available_sounds() :: [{String.t(), String.t()}]
  def available_sounds, do: @sound_catalog

  @spec event_types() :: [atom()]
  def event_types, do: @event_types

  @spec valid_sound?(String.t()) :: boolean()
  def valid_sound?(name), do: name in @valid_sound_names

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, settings) do
    attrs = %{
      owner_nickname: owner,
      sound_mappings: stringify_keys(settings.sound_mappings),
      flash_settings: stringify_keys(settings.flash_settings)
    }

    case Repo.get(SoundSetting, owner) do
      nil ->
        %SoundSetting{}
        |> SoundSetting.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> SoundSetting.changeset(attrs)
        |> Repo.update()
    end
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec load(String.t()) :: {:ok, map()} | {:error, :not_found}
  def load(owner) do
    case Repo.get(SoundSetting, owner) do
      nil ->
        {:error, :not_found}

      db_entry ->
        {:ok,
         %{
           sound_mappings: atomize_keys(db_entry.sound_mappings),
           flash_settings: atomize_flash(db_entry.flash_settings)
         }}
    end
  end

  # ---------------------------------------------------------------------------
  # Private Helpers
  # ---------------------------------------------------------------------------

  defp stringify_keys(map) do
    Map.new(map, fn {k, v} -> {Atom.to_string(k), v} end)
  end

  defp atomize_keys(map) do
    Map.new(map, fn {k, v} ->
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      {key, v}
    end)
  end

  defp atomize_flash(map) do
    Map.new(map, fn {k, v} ->
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      {key, v == true || v == "true"}
    end)
  end
end
