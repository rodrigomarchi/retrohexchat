defmodule RetroHexChat.Chat.UserPreferences do
  @moduledoc """
  Domain module for centralized user preferences.

  Manages in-memory CRUD for 4 preference categories (display, messages,
  key_bindings, notifications) and persistence for registered users.
  """

  alias RetroHexChat.Chat.KeyBindings
  alias RetroHexChat.Chat.NotificationPreferences
  alias RetroHexChat.Chat.Schemas.UserPreference
  alias RetroHexChat.Repo

  @valid_display_keys ~w(show_toolbar show_treebar show_switchbar show_statusbar compact_mode line_shading show_contextual_tips)a
  @valid_timestamp_formats [:hh_mm, :hh_mm_ss, :dd_mm_hh_mm, :none]
  @valid_command_help_levels [:beginner, :expert, :off]

  # ---------------------------------------------------------------------------
  # In-Memory CRUD
  # ---------------------------------------------------------------------------

  @spec new() :: map()
  def new do
    %{
      display: default_display(),
      messages: default_messages(),
      key_bindings: KeyBindings.defaults(),
      notifications: NotificationPreferences.new()
    }
  end

  @spec get_display(map()) :: map()
  def get_display(%{display: display}), do: display

  @spec get_messages(map()) :: map()
  def get_messages(%{messages: messages}), do: messages

  @spec get_key_bindings(map()) :: map()
  def get_key_bindings(%{key_bindings: bindings}), do: bindings

  @spec get_notifications(map()) :: NotificationPreferences.t()
  def get_notifications(%{notifications: notifications}), do: notifications

  @spec set_notifications(map(), NotificationPreferences.t()) :: map()
  def set_notifications(prefs, notifications) when is_map(notifications) do
    %{prefs | notifications: notifications}
  end

  @spec set_display(map(), atom(), boolean()) :: map()
  def set_display(prefs, key, value) when key in @valid_display_keys and is_boolean(value) do
    put_in(prefs, [:display, key], value)
  end

  @spec set_routing(map(), :notice_routing, atom()) :: map()
  def set_routing(prefs, :notice_routing, value) when value in [:active, :status, :sender] do
    put_in(prefs, [:messages, :notice_routing], value)
  end

  @spec get_timestamp_format(map()) :: atom()
  def get_timestamp_format(%{display: display}) do
    Map.get(display, :timestamp_format, :hh_mm)
  end

  @spec get_command_help_level(map()) :: atom()
  def get_command_help_level(%{display: display}) do
    Map.get(display, :command_help_level, :beginner)
  end

  @spec set_command_help_level(map(), atom()) :: map()
  def set_command_help_level(prefs, level) when level in @valid_command_help_levels do
    put_in(prefs, [:display, :command_help_level], level)
  end

  @spec set_timestamp_format(map(), atom()) :: map()
  def set_timestamp_format(prefs, format) when format in @valid_timestamp_formats do
    put_in(prefs, [:display, :timestamp_format], format)
  end

  @spec get_quit_message(map()) :: String.t()
  def get_quit_message(%{display: display}) do
    Map.get(display, :quit_message, "Leaving")
  end

  @spec set_quit_message(map(), String.t()) :: map()
  def set_quit_message(prefs, message) when is_binary(message) and byte_size(message) > 0 do
    truncated = String.slice(message, 0, 200)
    put_in(prefs, [:display, :quit_message], truncated)
  end

  @spec get_muted_channels(map()) :: [String.t()]
  def get_muted_channels(%{messages: messages}) do
    Map.get(messages, :muted_channels, [])
  end

  @spec set_muted_channels(map(), [String.t()]) :: map()
  def set_muted_channels(prefs, channels) when is_list(channels) do
    put_in(prefs, [:messages, :muted_channels], channels)
  end

  @spec toggle_mute_channel(map(), String.t()) :: map()
  def toggle_mute_channel(prefs, channel) when is_binary(channel) do
    current = get_muted_channels(prefs)

    updated =
      if channel in current do
        List.delete(current, channel)
      else
        [channel | current]
      end

    set_muted_channels(prefs, updated)
  end

  @spec set_key_binding(map(), atom(), KeyBindings.binding() | nil) :: map()
  def set_key_binding(prefs, action, binding) do
    put_in(prefs, [:key_bindings, action], binding)
  end

  @spec set_key_bindings(map(), KeyBindings.bindings_map()) :: map()
  def set_key_bindings(prefs, bindings) do
    %{prefs | key_bindings: bindings}
  end

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, prefs) do
    attrs = %{
      owner_nickname: owner,
      display_settings: stringify_map(prefs.display),
      message_settings:
        stringify_map(prefs.messages)
        |> Map.put("notifications", NotificationPreferences.to_map(prefs.notifications)),
      key_bindings: KeyBindings.to_persistable(prefs.key_bindings)
    }

    case Repo.get(UserPreference, owner) do
      nil ->
        %UserPreference{}
        |> UserPreference.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> UserPreference.changeset(attrs)
        |> Repo.update()
    end
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec load(String.t()) :: {:ok, map()} | {:error, :not_found}
  def load(owner) do
    case Repo.get(UserPreference, owner) do
      nil ->
        {:error, :not_found}

      db_entry ->
        {:ok, from_persisted(db_entry)}
    end
  end

  # ---------------------------------------------------------------------------
  # Private: Defaults
  # ---------------------------------------------------------------------------

  defp default_display do
    %{
      show_toolbar: true,
      show_treebar: true,
      show_switchbar: true,
      show_statusbar: true,
      compact_mode: false,
      line_shading: false,
      show_contextual_tips: true,
      timestamp_format: :hh_mm,
      command_help_level: :beginner
    }
  end

  defp default_messages do
    %{
      notice_routing: :active,
      muted_channels: []
    }
  end

  # ---------------------------------------------------------------------------
  # Private: Serialization
  # ---------------------------------------------------------------------------

  defp stringify_map(map) do
    Map.new(map, fn {k, v} -> {Atom.to_string(k), v} end)
  end

  defp from_persisted(db_entry) do
    msg_settings = db_entry.message_settings || %{}
    notif_data = Map.get(msg_settings, "notifications", %{})
    notifications = NotificationPreferences.from_map(notif_data)

    # Migrate muted_channels to channel_levels if needed
    messages = atomize_messages(msg_settings)

    notifications =
      case Map.get(messages, :muted_channels, []) do
        [] -> notifications
        muted -> NotificationPreferences.migrate_from_muted_channels(notifications, muted)
      end

    %{
      display: atomize_display(db_entry.display_settings),
      messages: messages,
      key_bindings: KeyBindings.from_persisted(db_entry.key_bindings),
      notifications: notifications
    }
  end

  defp atomize_display(data) when data == %{}, do: default_display()

  defp atomize_display(data) do
    defaults = default_display()

    Map.new(defaults, fn {key, default_val} ->
      str_key = Atom.to_string(key)
      raw = Map.get(data, str_key, default_val)

      value =
        case key do
          :command_help_level when is_binary(raw) ->
            atomize_command_help_level(raw)

          :timestamp_format when is_binary(raw) ->
            String.to_existing_atom(raw)

          _ ->
            raw
        end

      {key, value}
    end)
  end

  defp atomize_command_help_level("beginner"), do: :beginner
  defp atomize_command_help_level("expert"), do: :expert
  defp atomize_command_help_level("off"), do: :off
  defp atomize_command_help_level(_), do: :beginner

  defp atomize_messages(data) when data == %{}, do: default_messages()

  defp atomize_messages(data) do
    defaults = default_messages()

    Map.new(defaults, fn {key, default_val} ->
      str_key = Atom.to_string(key)
      raw = Map.get(data, str_key)
      {key, atomize_message_value(key, raw, default_val)}
    end)
  end

  defp atomize_message_value(:muted_channels, raw, default_val) do
    if is_list(raw), do: raw, else: default_val
  end

  defp atomize_message_value(_key, raw, _default_val) when is_binary(raw) do
    String.to_existing_atom(raw)
  end

  defp atomize_message_value(_key, raw, default_val), do: raw || default_val
end
