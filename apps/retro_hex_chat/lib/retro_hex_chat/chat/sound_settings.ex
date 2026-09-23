defmodule RetroHexChat.Chat.SoundSettings do
  @moduledoc """
  Domain module for managing per-event sound, flash and desktop-notification
  preferences.

  Provides in-memory CRUD operations on the settings map
  and persistence functions (save/2, load/1) for registered users.
  """
  use Gettext, backend: RetroHexChat.Gettext

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
    {"none", dgettext("chat", "None")},
    {"beep", dgettext("chat", "Beep")},
    {"ding_low", dgettext("chat", "Ding Low")},
    {"ding_high", dgettext("chat", "Ding High")},
    {"chime_short", dgettext("chat", "Chime Short")},
    {"chime_long", dgettext("chat", "Chime Long")},
    {"chime_high", dgettext("chat", "Chime High")},
    {"chime_low", dgettext("chat", "Chime Low")},
    {"alert", dgettext("chat", "Alert")},
    {"buzz", dgettext("chat", "Buzz")},
    {"click", dgettext("chat", "Click")},
    {"ring", dgettext("chat", "Ring")},
    {"notify", dgettext("chat", "Notify")},
    {"blip", dgettext("chat", "Blip")},
    {"whoosh", dgettext("chat", "Whoosh")}
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

  # A desktop notification is the one of the three that leaves the page, so it
  # starts on only for the events that are about *you*. Notifying on every line
  # of every channel is how the feature gets switched off on the first day.
  @default_notify_settings %{
    message: false,
    pm: true,
    highlight: true,
    join: false,
    part: false,
    kick: false,
    connect: false,
    disconnect: false,
    buddy_online: false,
    buddy_offline: false
  }

  # ---------------------------------------------------------------------------
  # In-Memory CRUD
  # ---------------------------------------------------------------------------

  @spec new() :: map()
  def new do
    %{
      sound_mappings: @default_sound_mappings,
      flash_settings: @default_flash_settings,
      notify_settings: @default_notify_settings,
      muted: false
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

  @spec get_notify(map(), atom()) :: boolean()
  def get_notify(%{notify_settings: notify}, event_type) when event_type in @event_types do
    Map.get(notify, event_type, false)
  end

  def get_notify(_settings, event_type) when event_type in @event_types, do: false

  @spec set_notify(map(), atom(), boolean()) :: map()
  def set_notify(settings, event_type, enabled)
      when event_type in @event_types and is_boolean(enabled) do
    put_in(settings, [:notify_settings, event_type], enabled)
  end

  @spec get_notify_settings(map()) :: map()
  def get_notify_settings(%{notify_settings: notify}), do: notify
  def get_notify_settings(_settings), do: @default_notify_settings

  @spec get_sound_mappings(map()) :: map()
  def get_sound_mappings(%{sound_mappings: mappings}), do: mappings

  @spec get_flash_settings(map()) :: map()
  def get_flash_settings(%{flash_settings: flash}), do: flash

  @spec muted?(map()) :: boolean()
  def muted?(%{muted: true}), do: true
  def muted?(_settings), do: false

  @spec set_muted(map(), term()) :: map()
  def set_muted(settings, muted) when is_map(settings) and is_boolean(muted),
    do: Map.put(settings, :muted, muted)

  def set_muted(settings, _muted), do: settings

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
      flash_settings: stringify_keys(settings.flash_settings),
      notify_settings: stringify_keys(get_notify_settings(settings)),
      muted: muted?(settings)
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
           flash_settings: atomize_flash(db_entry.flash_settings),
           notify_settings: load_notify(db_entry.notify_settings),
           muted: db_entry.muted == true
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

  # A row written before this setting existed carries an empty map, and coming
  # back with every notification off is not what that row meant — it meant
  # nothing at all. An absent setting falls back to the default, per event.
  defp load_notify(stored) when is_map(stored) do
    stored = atomize_flash(stored)
    Map.merge(@default_notify_settings, stored)
  end

  defp load_notify(_absent), do: @default_notify_settings

  defp atomize_flash(map) do
    Map.new(map, fn {k, v} ->
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      {key, v == true || v == "true"}
    end)
  end
end
