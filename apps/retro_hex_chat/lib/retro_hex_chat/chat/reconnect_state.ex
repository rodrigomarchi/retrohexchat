defmodule RetroHexChat.Chat.ReconnectState do
  @moduledoc """
  Persisted chat reconnect snapshots for registered users.

  The snapshot mirrors the old client payload, but this module owns all durable
  storage and defensive normalization.
  """

  alias RetroHexChat.Chat.Schemas.ReconnectState, as: ReconnectStateSchema
  alias RetroHexChat.Repo

  @type t :: %{
          nickname: String.t() | nil,
          channels: [String.t()],
          active_channel: String.t() | nil,
          active_pm: String.t() | nil,
          open_pm_tabs: [String.t()],
          welcomed_channels: [String.t()]
        }

  @max_channels 50
  @max_open_pm_tabs 20

  @spec new() :: t()
  def new do
    %{
      nickname: nil,
      channels: [],
      active_channel: nil,
      active_pm: nil,
      open_pm_tabs: [],
      welcomed_channels: []
    }
  end

  @spec normalize(map()) :: t()
  def normalize(snapshot) when is_map(snapshot) do
    channels = normalize_channels(Map.get(snapshot, :channels) || Map.get(snapshot, "channels"))

    open_pm_tabs =
      normalize_nick_list(Map.get(snapshot, :open_pm_tabs) || Map.get(snapshot, "open_pm_tabs"))

    %{
      nickname:
        normalize_optional_string(Map.get(snapshot, :nickname) || Map.get(snapshot, "nickname")),
      channels: channels,
      active_channel:
        normalize_active_channel(
          Map.get(snapshot, :active_channel) || Map.get(snapshot, "active_channel"),
          channels
        ),
      active_pm:
        normalize_active_pm(
          Map.get(snapshot, :active_pm) || Map.get(snapshot, "active_pm"),
          open_pm_tabs
        ),
      open_pm_tabs: open_pm_tabs,
      welcomed_channels:
        normalize_channels(
          Map.get(snapshot, :welcomed_channels) || Map.get(snapshot, "welcomed_channels")
        )
    }
  end

  def normalize(_snapshot), do: new()

  @spec to_client_state(String.t(), map()) :: map()
  def to_client_state(owner, snapshot) do
    snapshot
    |> normalize()
    |> Map.put(:nickname, owner)
  end

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, snapshot) when is_binary(owner) do
    normalized = to_client_state(owner, snapshot)

    attrs = %{
      owner_nickname: owner,
      channels: normalized.channels,
      active_channel: normalized.active_channel,
      active_pm: normalized.active_pm,
      open_pm_tabs: normalized.open_pm_tabs,
      welcomed_channels: normalized.welcomed_channels
    }

    case Repo.get(ReconnectStateSchema, owner) do
      nil ->
        %ReconnectStateSchema{}
        |> ReconnectStateSchema.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> ReconnectStateSchema.changeset(attrs)
        |> Repo.update()
    end
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def save(_owner, _snapshot), do: {:error, :invalid_owner}

  @spec load(String.t()) :: {:ok, t()} | {:error, :not_found}
  def load(owner) when is_binary(owner) do
    case Repo.get(ReconnectStateSchema, owner) do
      nil ->
        {:error, :not_found}

      db_entry ->
        {:ok,
         to_client_state(owner, %{
           channels: db_entry.channels,
           active_channel: db_entry.active_channel,
           active_pm: db_entry.active_pm,
           open_pm_tabs: db_entry.open_pm_tabs,
           welcomed_channels: db_entry.welcomed_channels
         })}
    end
  end

  def load(_owner), do: {:error, :not_found}

  @spec delete(String.t()) :: :ok | {:error, term()}
  def delete(owner) when is_binary(owner) do
    case Repo.get(ReconnectStateSchema, owner) do
      nil ->
        :ok

      existing ->
        case Repo.delete(existing) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def delete(_owner), do: :ok

  defp normalize_channels(channels) when is_list(channels) do
    channels
    |> Enum.filter(&valid_channel?/1)
    |> dedupe()
    |> Enum.take(@max_channels)
  end

  defp normalize_channels(_channels), do: []

  defp normalize_nick_list(nicks) when is_list(nicks) do
    nicks
    |> Enum.filter(&valid_nick?/1)
    |> dedupe()
    |> Enum.take(@max_open_pm_tabs)
  end

  defp normalize_nick_list(_nicks), do: []

  defp normalize_active_channel(channel, channels) when is_binary(channel) do
    if channel in channels, do: channel, else: nil
  end

  defp normalize_active_channel(_channel, _channels), do: nil

  defp normalize_active_pm(pm, open_pm_tabs) when is_binary(pm) do
    if pm in open_pm_tabs, do: pm, else: nil
  end

  defp normalize_active_pm(_pm, _open_pm_tabs), do: nil

  defp normalize_optional_string(value) when is_binary(value) and value != "", do: value
  defp normalize_optional_string(_value), do: nil

  defp valid_channel?(channel) when is_binary(channel) do
    String.starts_with?(channel, "#") and String.trim(channel) == channel and
      byte_size(channel) <= 128
  end

  defp valid_channel?(_channel), do: false

  defp valid_nick?(nick) when is_binary(nick) do
    String.trim(nick) == nick and nick != "" and byte_size(nick) <= 128
  end

  defp valid_nick?(_nick), do: false

  defp dedupe(values) do
    values
    |> Enum.reduce({MapSet.new(), []}, fn value, {seen, acc} ->
      if MapSet.member?(seen, value) do
        {seen, acc}
      else
        {MapSet.put(seen, value), [value | acc]}
      end
    end)
    |> elem(1)
    |> Enum.reverse()
  end
end
