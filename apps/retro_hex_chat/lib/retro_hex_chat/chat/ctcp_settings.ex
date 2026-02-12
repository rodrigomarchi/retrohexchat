defmodule RetroHexChat.Chat.CtcpSettings do
  @moduledoc """
  Domain module for managing CTCP reply settings.

  Provides in-memory CRUD operations on the settings map
  and persistence functions (save/2, load/1) for registered users.
  """

  alias RetroHexChat.Chat.Schemas.CtcpSetting
  alias RetroHexChat.Repo

  @max_string_length 200
  @default_version "RetroHexChat v1.0"

  # ---------------------------------------------------------------------------
  # In-Memory CRUD
  # ---------------------------------------------------------------------------

  @spec new() :: map()
  def new do
    %{enabled: true, version_string: @default_version, finger_text: nil}
  end

  @spec get_enabled(map()) :: boolean()
  def get_enabled(%{enabled: enabled}), do: enabled

  @spec get_version_string(map()) :: String.t()
  def get_version_string(%{version_string: version_string}), do: version_string

  @spec get_finger_text(map()) :: String.t() | nil
  def get_finger_text(%{finger_text: finger_text}), do: finger_text

  @spec set_enabled(map(), boolean()) :: map()
  def set_enabled(settings, enabled) when is_boolean(enabled) do
    %{settings | enabled: enabled}
  end

  @spec set_version_string(map(), String.t()) :: map()
  def set_version_string(settings, version_string) do
    truncated = String.slice(version_string, 0, @max_string_length)
    %{settings | version_string: truncated}
  end

  @spec set_finger_text(map(), String.t() | nil) :: map()
  def set_finger_text(settings, nil) do
    %{settings | finger_text: nil}
  end

  def set_finger_text(settings, finger_text) do
    truncated = String.slice(finger_text, 0, @max_string_length)
    %{settings | finger_text: truncated}
  end

  # ---------------------------------------------------------------------------
  # Persistence
  # ---------------------------------------------------------------------------

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, settings) do
    attrs = %{
      owner_nickname: owner,
      enabled: settings.enabled,
      version_string: settings.version_string,
      finger_text: settings.finger_text
    }

    case Repo.get(CtcpSetting, owner) do
      nil ->
        %CtcpSetting{}
        |> CtcpSetting.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> CtcpSetting.changeset(attrs)
        |> Repo.update()
    end
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec load(String.t()) :: {:ok, map()} | {:error, :not_found}
  def load(owner) do
    case Repo.get(CtcpSetting, owner) do
      nil ->
        {:error, :not_found}

      db_entry ->
        {:ok,
         %{
           enabled: db_entry.enabled,
           version_string: db_entry.version_string,
           finger_text: db_entry.finger_text
         }}
    end
  end
end
