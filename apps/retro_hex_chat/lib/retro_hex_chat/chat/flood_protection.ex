defmodule RetroHexChat.Chat.FloodProtection do
  @moduledoc """
  Domain module for managing flood protection settings.

  Provides in-memory CRUD operations on the settings map
  and persistence functions (save/2, load/1) for registered users.
  """

  alias RetroHexChat.Chat.Schemas.FloodProtectionSetting
  alias RetroHexChat.Repo

  @default_flood_threshold 10
  @default_flood_window_seconds 15
  @default_auto_ignore_duration_seconds 300
  @default_spam_threshold 3
  @default_spam_window_seconds 10

  # ---------------------------------------------------------------------------
  # In-Memory CRUD
  # ---------------------------------------------------------------------------

  @spec new() :: map()
  def new do
    %{
      flood_threshold: @default_flood_threshold,
      flood_window_seconds: @default_flood_window_seconds,
      auto_ignore_duration_seconds: @default_auto_ignore_duration_seconds,
      spam_threshold: @default_spam_threshold,
      spam_window_seconds: @default_spam_window_seconds
    }
  end

  # Getters

  @spec get_flood_threshold(map()) :: pos_integer()
  def get_flood_threshold(%{flood_threshold: v}), do: v

  @spec get_flood_window_seconds(map()) :: pos_integer()
  def get_flood_window_seconds(%{flood_window_seconds: v}), do: v

  @spec get_auto_ignore_duration_seconds(map()) :: pos_integer()
  def get_auto_ignore_duration_seconds(%{auto_ignore_duration_seconds: v}), do: v

  @spec get_spam_threshold(map()) :: pos_integer()
  def get_spam_threshold(%{spam_threshold: v}), do: v

  @spec get_spam_window_seconds(map()) :: pos_integer()
  def get_spam_window_seconds(%{spam_window_seconds: v}), do: v

  # Setters

  @spec set_flood_threshold(map(), integer()) :: map() | {:error, :invalid_value}
  def set_flood_threshold(settings, value)
      when is_integer(value) and value > 0 and value <= 100 do
    %{settings | flood_threshold: value}
  end

  def set_flood_threshold(_settings, _value), do: {:error, :invalid_value}

  @spec set_flood_window_seconds(map(), integer()) :: map() | {:error, :invalid_value}
  def set_flood_window_seconds(settings, value)
      when is_integer(value) and value > 0 and value <= 300 do
    %{settings | flood_window_seconds: value}
  end

  def set_flood_window_seconds(_settings, _value), do: {:error, :invalid_value}

  @spec set_auto_ignore_duration_seconds(map(), integer()) :: map() | {:error, :invalid_value}
  def set_auto_ignore_duration_seconds(settings, value)
      when is_integer(value) and value > 0 and value <= 86_400 do
    %{settings | auto_ignore_duration_seconds: value}
  end

  def set_auto_ignore_duration_seconds(_settings, _value), do: {:error, :invalid_value}

  @spec set_spam_threshold(map(), integer()) :: map() | {:error, :invalid_value}
  def set_spam_threshold(settings, value) when is_integer(value) and value > 0 and value <= 50 do
    %{settings | spam_threshold: value}
  end

  def set_spam_threshold(_settings, _value), do: {:error, :invalid_value}

  @spec set_spam_window_seconds(map(), integer()) :: map() | {:error, :invalid_value}
  def set_spam_window_seconds(settings, value)
      when is_integer(value) and value > 0 and value <= 120 do
    %{settings | spam_window_seconds: value}
  end

  def set_spam_window_seconds(_settings, _value), do: {:error, :invalid_value}

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, settings) do
    attrs = %{
      owner_nickname: owner,
      flood_threshold: settings.flood_threshold,
      flood_window_seconds: settings.flood_window_seconds,
      auto_ignore_duration_seconds: settings.auto_ignore_duration_seconds,
      spam_threshold: settings.spam_threshold,
      spam_window_seconds: settings.spam_window_seconds
    }

    case Repo.get(FloodProtectionSetting, owner) do
      nil ->
        %FloodProtectionSetting{}
        |> FloodProtectionSetting.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> FloodProtectionSetting.changeset(attrs)
        |> Repo.update()
    end
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec load(String.t()) :: {:ok, map()} | {:error, :not_found}
  def load(owner) do
    case Repo.get(FloodProtectionSetting, owner) do
      nil ->
        {:error, :not_found}

      db_entry ->
        {:ok,
         %{
           flood_threshold: db_entry.flood_threshold,
           flood_window_seconds: db_entry.flood_window_seconds,
           auto_ignore_duration_seconds: db_entry.auto_ignore_duration_seconds,
           spam_threshold: db_entry.spam_threshold,
           spam_window_seconds: db_entry.spam_window_seconds
         }}
    end
  end
end
