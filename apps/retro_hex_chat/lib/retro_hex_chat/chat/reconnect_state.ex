defmodule RetroHexChat.Chat.ReconnectState do
  @moduledoc """
  Persisted chat reconnect snapshots for registered users.

  The snapshot mirrors the old client payload, but this module owns all durable
  storage and defensive normalization.

  A snapshot is addressed by a nickname **and a browser**, because what somebody
  had on screen is a fact about a screen: a desktop and a phone signed in as the
  same person hold two channel lists and two places they had read to. A browser
  with no id is addressed by the empty string, which is what a browser that
  blocks the cookie sends and what every row written before this existed holds.
  """

  alias RetroHexChat.Chat.Schemas.ReconnectState, as: ReconnectStateSchema
  alias RetroHexChat.Repo

  @type t :: %{
          nickname: String.t() | nil,
          channels: [String.t()],
          active_channel: String.t() | nil,
          active_pm: String.t() | nil,
          open_pm_tabs: [String.t()],
          welcomed_channels: [String.t()],
          read_markers: %{String.t() => pos_integer()}
        }

  @max_channels 50
  @max_open_pm_tabs 20

  # Where somebody had read to, per conversation. Kept even for a channel they
  # left — that is precisely what they want when they come back to it — so the
  # only thing bounding the map is this ceiling. It is generous on purpose: a
  # person with a hundred conversations behind them is a person the product is
  # working for.
  @max_read_markers 100

  @spec new() :: t()
  def new do
    %{
      nickname: nil,
      channels: [],
      active_channel: nil,
      active_pm: nil,
      open_pm_tabs: [],
      welcomed_channels: [],
      read_markers: %{}
    }
  end

  @doc "How many conversations a snapshot remembers a position in."
  @spec max_read_markers() :: pos_integer()
  def max_read_markers, do: @max_read_markers

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
        ),
      read_markers:
        normalize_read_markers(
          Map.get(snapshot, :read_markers) || Map.get(snapshot, "read_markers")
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

  @spec save(String.t(), map(), String.t()) :: :ok | {:error, term()}
  def save(owner, snapshot, browser_id \\ "")

  def save(owner, snapshot, browser_id) when is_binary(owner) do
    normalized = to_client_state(owner, snapshot)
    browser_id = browser_key(browser_id)

    attrs = %{
      owner_nickname: owner,
      browser_id: browser_id,
      channels: normalized.channels,
      active_channel: normalized.active_channel,
      active_pm: normalized.active_pm,
      open_pm_tabs: normalized.open_pm_tabs,
      welcomed_channels: normalized.welcomed_channels,
      read_markers: normalized.read_markers
    }

    case row(owner, browser_id) do
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

  def save(_owner, _snapshot, _browser_id), do: {:error, :invalid_owner}

  @spec load(String.t(), String.t()) :: {:ok, t()} | {:error, :not_found}
  def load(owner, browser_id \\ "")

  def load(owner, browser_id) when is_binary(owner) do
    case row(owner, browser_key(browser_id)) do
      nil ->
        {:error, :not_found}

      db_entry ->
        {:ok,
         to_client_state(owner, %{
           channels: db_entry.channels,
           active_channel: db_entry.active_channel,
           active_pm: db_entry.active_pm,
           open_pm_tabs: db_entry.open_pm_tabs,
           welcomed_channels: db_entry.welcomed_channels,
           read_markers: db_entry.read_markers
         })}
    end
  end

  def load(_owner, _browser_id), do: {:error, :not_found}

  @spec delete(String.t(), String.t()) :: :ok | {:error, term()}
  def delete(owner, browser_id \\ "")

  def delete(owner, browser_id) when is_binary(owner) do
    case row(owner, browser_key(browser_id)) do
      nil ->
        :ok

      existing ->
        case Repo.delete(existing) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def delete(_owner, _browser_id), do: :ok

  defp row(owner, browser_id) do
    Repo.get_by(ReconnectStateSchema, owner_nickname: owner, browser_id: browser_id)
  end

  defp browser_key(browser_id) when is_binary(browser_id), do: browser_id
  defp browser_key(_browser_id), do: ""

  # A snapshot is written by a browser, so every part of it can arrive wrong: a
  # key that is not a conversation, a value that is not an id, more entries than
  # anybody could have conversations. None of that may reach a row, and none of
  # it may raise — a malformed snapshot taking the mount down is far worse than
  # a forgotten position.
  defp normalize_read_markers(markers) when is_map(markers) do
    markers
    |> Enum.filter(fn {key, value} -> conversation_key?(key) and message_id?(value) end)
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Enum.take(@max_read_markers)
    |> Map.new()
  end

  defp normalize_read_markers(_markers), do: %{}

  defp conversation_key?(key) when is_binary(key) do
    String.starts_with?(key, "#") or String.starts_with?(key, "pm:")
  end

  defp conversation_key?(_key), do: false

  defp message_id?(value) when is_integer(value) and value > 0, do: true
  defp message_id?(_value), do: false

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
