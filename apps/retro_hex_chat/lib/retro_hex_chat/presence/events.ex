defmodule RetroHexChat.Presence.Events do
  @moduledoc """
  Telemetry events for the Presence context.
  """

  @spec emit_user_online(String.t(), String.t()) :: :ok
  def emit_user_online(nickname, channel) do
    :telemetry.execute(
      [:retro_hex_chat, :presence, :user_online],
      %{count: 1},
      %{nickname: nickname, channel: channel}
    )
  end

  @spec emit_user_offline(String.t(), String.t()) :: :ok
  def emit_user_offline(nickname, channel) do
    :telemetry.execute(
      [:retro_hex_chat, :presence, :user_offline],
      %{count: 1},
      %{nickname: nickname, channel: channel}
    )
  end

  @spec emit_user_away(String.t(), boolean()) :: :ok
  def emit_user_away(nickname, away) do
    :telemetry.execute(
      [:retro_hex_chat, :presence, :user_away],
      %{count: 1},
      %{nickname: nickname, away: away}
    )
  end
end
