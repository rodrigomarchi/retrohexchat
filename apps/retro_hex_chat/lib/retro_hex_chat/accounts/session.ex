defmodule RetroHexChat.Accounts.Session do
  @moduledoc """
  In-memory session struct representing a connected user's state.
  Lives in the LiveView socket assigns, not persisted to DB.
  """

  @type t :: %__MODULE__{
          nickname: String.t(),
          channels: [String.t()],
          active_channel: String.t() | nil,
          pm_conversations: [String.t()],
          active_pm: String.t() | nil,
          identified: boolean(),
          connected_at: DateTime.t(),
          away: boolean(),
          away_message: String.t() | nil,
          strip_formatting: boolean()
        }

  @enforce_keys [:nickname]
  defstruct [
    :nickname,
    channels: [],
    active_channel: nil,
    pm_conversations: [],
    active_pm: nil,
    identified: false,
    connected_at: nil,
    away: false,
    away_message: nil,
    strip_formatting: false
  ]

  @spec new(String.t()) :: t()
  def new(nickname) do
    %__MODULE__{nickname: nickname, connected_at: DateTime.utc_now()}
  end

  @spec update_nickname(t(), String.t()) :: t()
  def update_nickname(%__MODULE__{} = session, new_nickname) do
    %{session | nickname: new_nickname}
  end

  @spec add_channel(t(), String.t()) :: t()
  def add_channel(%__MODULE__{channels: channels} = session, channel_name) do
    if channel_name in channels do
      session
    else
      %{session | channels: channels ++ [channel_name]}
    end
  end

  @spec remove_channel(t(), String.t()) :: t()
  def remove_channel(
        %__MODULE__{channels: channels, active_channel: active} = session,
        channel_name
      ) do
    new_channels = List.delete(channels, channel_name)
    new_active = if active == channel_name, do: List.first(new_channels), else: active
    %{session | channels: new_channels, active_channel: new_active}
  end

  @spec set_identified(t(), boolean()) :: t()
  def set_identified(%__MODULE__{} = session, identified) do
    %{session | identified: identified}
  end

  @spec set_active_channel(t(), String.t() | nil) :: t()
  def set_active_channel(%__MODULE__{} = session, channel_name) do
    %{session | active_channel: channel_name, active_pm: nil}
  end

  @spec add_pm_conversation(t(), String.t()) :: t()
  def add_pm_conversation(%__MODULE__{pm_conversations: pms} = session, nickname) do
    if nickname in pms do
      session
    else
      %{session | pm_conversations: pms ++ [nickname]}
    end
  end

  @spec remove_pm_conversation(t(), String.t()) :: t()
  def remove_pm_conversation(
        %__MODULE__{pm_conversations: pms, active_pm: active} = session,
        nickname
      ) do
    new_pms = List.delete(pms, nickname)
    new_active = if active == nickname, do: nil, else: active
    %{session | pm_conversations: new_pms, active_pm: new_active}
  end

  @spec set_active_pm(t(), String.t() | nil) :: t()
  def set_active_pm(%__MODULE__{} = session, nickname) do
    %{session | active_pm: nickname, active_channel: nil}
  end

  @spec toggle_strip_formatting(t()) :: t()
  def toggle_strip_formatting(%__MODULE__{strip_formatting: current} = session) do
    %{session | strip_formatting: !current}
  end

  @spec set_away(t(), String.t() | nil) :: t()
  def set_away(%__MODULE__{} = session, nil) do
    %{session | away: false, away_message: nil}
  end

  def set_away(%__MODULE__{} = session, message) do
    %{session | away: true, away_message: message}
  end
end
