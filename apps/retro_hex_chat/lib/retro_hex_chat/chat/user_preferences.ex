defmodule RetroHexChat.Chat.UserPreferences do
  @moduledoc """
  Domain module for centralized user preferences.

  Manages in-memory CRUD for display preferences,
  and persistence for registered users.
  """

  alias RetroHexChat.Chat.Schemas.UserPreference
  alias RetroHexChat.Repo

  @valid_display_keys ~w(show_toolbar show_conversations show_switchbar show_statusbar)a

  # ---------------------------------------------------------------------------
  # In-Memory CRUD
  # ---------------------------------------------------------------------------

  @spec new() :: map()
  def new do
    %{display: default_display()}
  end

  @spec get_display(map()) :: map()
  def get_display(%{display: display}), do: display

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
      display_settings: stringify_map(prefs.display)
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
      show_conversations: true,
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

    %{display: atomize_display(display_data)}
  end

  defp atomize_display(data) when data == %{}, do: default_display()

  defp atomize_display(data) do
    defaults = default_display()

    Map.new(defaults, fn {key, default_val} ->
      str_key = Atom.to_string(key)

      value =
        if Map.has_key?(data, str_key),
          do: Map.get(data, str_key),
          else: display_fallback(data, key, default_val)

      {key, value}
    end)
  end

  # Backward compat: show_treebar → show_conversations
  defp display_fallback(data, :show_conversations, default),
    do: Map.get(data, "show_treebar", default)

  defp display_fallback(_data, _key, default), do: default
end
