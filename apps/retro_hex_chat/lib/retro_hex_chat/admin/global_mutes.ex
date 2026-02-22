defmodule RetroHexChat.Admin.GlobalMutes do
  @moduledoc "Context for global mute management (ephemeral, ETS-backed)."

  alias RetroHexChat.Admin.GlobalMuteTable

  @spec mute(String.t(), String.t() | nil, non_neg_integer() | :permanent) :: :ok
  def mute(nickname, _reason \\ nil, duration \\ :permanent) do
    GlobalMuteTable.mute(nickname, duration)
  end

  @spec unmute(String.t()) :: :ok
  def unmute(nickname) do
    GlobalMuteTable.unmute(nickname)
  end

  @spec muted?(String.t()) :: boolean()
  def muted?(nickname) do
    GlobalMuteTable.muted?(nickname)
  end

  @spec list_mutes() :: [{String.t(), :permanent | integer()}]
  def list_mutes do
    GlobalMuteTable.list_mutes()
  end
end
