defmodule RetroHexChat.Chat.UserPreferences do
  @moduledoc """
  Domain module for centralized user preferences.

  Manages in-memory CRUD for display and notification preferences,
  and persistence for registered users.
  """

  alias RetroHexChat.Chat.NotificationPreferences
  alias RetroHexChat.Chat.Schemas.UserPreference
  alias RetroHexChat.Repo

  @valid_display_keys ~w(show_toolbar show_treebar show_switchbar show_statusbar)a

  # ---------------------------------------------------------------------------
  # In-Memory CRUD
  # ---------------------------------------------------------------------------

  @spec new() :: map()
  def new do
    %{
      display: default_display(),
      notifications: NotificationPreferences.new()
    }
  end

  @spec get_display(map()) :: map()
  def get_display(%{display: display}), do: display

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

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, prefs) do
    attrs = %{
      owner_nickname: owner,
      display_settings:
        stringify_map(prefs.display)
        |> Map.put("notifications", NotificationPreferences.to_map(prefs.notifications))
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
      show_statusbar: true
    }
  end

  # ---------------------------------------------------------------------------
  # Private: Serialization
  # ---------------------------------------------------------------------------

  defp stringify_map(map) do
    Map.new(map, fn {k, v} -> {Atom.to_string(k), v} end)
  end

  defp from_persisted(db_entry) do
    display_data = db_entry.display_settings || %{}
    notif_data = Map.get(display_data, "notifications", %{})

    # Also check legacy message_settings for notifications (migration path)
    notif_data =
      if notif_data == %{} do
        msg_settings = Map.get(db_entry, :message_settings) || %{}
        Map.get(msg_settings, "notifications", %{})
      else
        notif_data
      end

    notifications = NotificationPreferences.from_map(notif_data)

    %{
      display: atomize_display(display_data),
      notifications: notifications
    }
  end

  defp atomize_display(data) when data == %{}, do: default_display()

  defp atomize_display(data) do
    defaults = default_display()

    Map.new(defaults, fn {key, default_val} ->
      str_key = Atom.to_string(key)
      {key, Map.get(data, str_key, default_val)}
    end)
  end
end
