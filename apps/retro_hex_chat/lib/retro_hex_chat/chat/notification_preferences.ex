defmodule RetroHexChat.Chat.NotificationPreferences do
  @moduledoc """
  Domain module for notification preferences.

  Provides in-memory CRUD for global toggles, per-channel notification levels,
  trigger rules, DND mode, and privacy mode. Serialization to/from maps for
  persistence in the UserPreferences message_settings JSONB column and
  localStorage for guests.
  """

  @valid_channel_levels [:normal, :mentions_only, :mute]

  @type t :: %{
          sounds_enabled: boolean(),
          browser_notifications: boolean(),
          title_flash_enabled: boolean(),
          privacy_mode: boolean(),
          dnd_enabled: boolean(),
          trigger_mentions: boolean(),
          trigger_pms: boolean(),
          trigger_channel_messages: boolean(),
          trigger_joins_leaves: boolean(),
          channel_levels: %{String.t() => :normal | :mentions_only | :mute}
        }

  # ---------------------------------------------------------------------------
  # Constructor
  # ---------------------------------------------------------------------------

  @spec new() :: t()
  def new do
    %{
      sounds_enabled: true,
      browser_notifications: false,
      title_flash_enabled: true,
      privacy_mode: false,
      dnd_enabled: false,
      trigger_mentions: true,
      trigger_pms: true,
      trigger_channel_messages: false,
      trigger_joins_leaves: false,
      channel_levels: %{}
    }
  end

  # ---------------------------------------------------------------------------
  # Global Toggles
  # ---------------------------------------------------------------------------

  @spec set_sounds_enabled(t(), boolean()) :: t()
  def set_sounds_enabled(prefs, value) when is_boolean(value) do
    %{prefs | sounds_enabled: value}
  end

  @spec set_browser_notifications(t(), boolean()) :: t()
  def set_browser_notifications(prefs, value) when is_boolean(value) do
    %{prefs | browser_notifications: value}
  end

  @spec set_title_flash_enabled(t(), boolean()) :: t()
  def set_title_flash_enabled(prefs, value) when is_boolean(value) do
    %{prefs | title_flash_enabled: value}
  end

  @spec set_privacy_mode(t(), boolean()) :: t()
  def set_privacy_mode(prefs, value) when is_boolean(value) do
    %{prefs | privacy_mode: value}
  end

  @spec set_dnd_enabled(t(), boolean()) :: t()
  def set_dnd_enabled(prefs, value) when is_boolean(value) do
    %{prefs | dnd_enabled: value}
  end

  # ---------------------------------------------------------------------------
  # Trigger Rules
  # ---------------------------------------------------------------------------

  @spec set_trigger_mentions(t(), boolean()) :: t()
  def set_trigger_mentions(prefs, value) when is_boolean(value) do
    %{prefs | trigger_mentions: value}
  end

  @spec set_trigger_pms(t(), boolean()) :: t()
  def set_trigger_pms(prefs, value) when is_boolean(value) do
    %{prefs | trigger_pms: value}
  end

  @spec set_trigger_channel_messages(t(), boolean()) :: t()
  def set_trigger_channel_messages(prefs, value) when is_boolean(value) do
    %{prefs | trigger_channel_messages: value}
  end

  @spec set_trigger_joins_leaves(t(), boolean()) :: t()
  def set_trigger_joins_leaves(prefs, value) when is_boolean(value) do
    %{prefs | trigger_joins_leaves: value}
  end

  # ---------------------------------------------------------------------------
  # Per-Channel Levels
  # ---------------------------------------------------------------------------

  @spec set_channel_level(t(), String.t(), atom()) :: t()
  def set_channel_level(prefs, channel, level)
      when is_binary(channel) and level in @valid_channel_levels do
    %{prefs | channel_levels: Map.put(prefs.channel_levels, channel, level)}
  end

  def set_channel_level(prefs, _channel, _level), do: prefs

  @spec get_channel_level(t(), String.t()) :: :normal | :mentions_only | :mute
  def get_channel_level(%{channel_levels: levels}, channel) do
    Map.get(levels, channel, :normal)
  end

  @spec remove_channel_level(t(), String.t()) :: t()
  def remove_channel_level(%{channel_levels: levels} = prefs, channel) do
    %{prefs | channel_levels: Map.delete(levels, channel)}
  end

  # ---------------------------------------------------------------------------
  # Serialization
  # ---------------------------------------------------------------------------

  @spec to_map(t()) :: map()
  def to_map(prefs) do
    %{
      "sounds_enabled" => prefs.sounds_enabled,
      "browser_notifications" => prefs.browser_notifications,
      "title_flash_enabled" => prefs.title_flash_enabled,
      "privacy_mode" => prefs.privacy_mode,
      "dnd_enabled" => prefs.dnd_enabled,
      "trigger_mentions" => prefs.trigger_mentions,
      "trigger_pms" => prefs.trigger_pms,
      "trigger_channel_messages" => prefs.trigger_channel_messages,
      "trigger_joins_leaves" => prefs.trigger_joins_leaves,
      "channel_levels" => stringify_channel_levels(prefs.channel_levels)
    }
  end

  @spec from_map(map()) :: t()
  def from_map(data) when is_map(data) do
    defaults = new()

    %{
      sounds_enabled: get_bool(data, "sounds_enabled", defaults.sounds_enabled),
      browser_notifications:
        get_bool(data, "browser_notifications", defaults.browser_notifications),
      title_flash_enabled: get_bool(data, "title_flash_enabled", defaults.title_flash_enabled),
      privacy_mode: get_bool(data, "privacy_mode", defaults.privacy_mode),
      dnd_enabled: get_bool(data, "dnd_enabled", defaults.dnd_enabled),
      trigger_mentions: get_bool(data, "trigger_mentions", defaults.trigger_mentions),
      trigger_pms: get_bool(data, "trigger_pms", defaults.trigger_pms),
      trigger_channel_messages:
        get_bool(data, "trigger_channel_messages", defaults.trigger_channel_messages),
      trigger_joins_leaves: get_bool(data, "trigger_joins_leaves", defaults.trigger_joins_leaves),
      channel_levels: atomize_channel_levels(data)
    }
  end

  # ---------------------------------------------------------------------------
  # Migration
  # ---------------------------------------------------------------------------

  @spec migrate_from_muted_channels(t(), [String.t()]) :: t()
  def migrate_from_muted_channels(prefs, muted_channels) when is_list(muted_channels) do
    Enum.reduce(muted_channels, prefs, fn channel, acc ->
      if Map.has_key?(acc.channel_levels, channel) do
        acc
      else
        set_channel_level(acc, channel, :mute)
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp get_bool(data, key, default) do
    case Map.fetch(data, key) do
      {:ok, val} when is_boolean(val) ->
        val

      _ ->
        case Map.fetch(data, String.to_atom(key)) do
          {:ok, val} when is_boolean(val) -> val
          _ -> default
        end
    end
  end

  defp stringify_channel_levels(levels) do
    Map.new(levels, fn {k, v} -> {k, Atom.to_string(v)} end)
  end

  defp atomize_channel_levels(data) do
    raw = Map.get(data, "channel_levels") || Map.get(data, :channel_levels) || %{}

    Map.new(raw, fn {k, v} ->
      level =
        case to_string(v) do
          "normal" -> :normal
          "mentions_only" -> :mentions_only
          "mute" -> :mute
          _ -> :normal
        end

      {k, level}
    end)
  end
end
