defmodule RetroHexChat.Accounts.Events do
  @moduledoc """
  Telemetry events for the Accounts context.
  """

  @spec emit_connected(String.t()) :: :ok
  def emit_connected(nickname) do
    :telemetry.execute(
      [:retro_hex_chat, :accounts, :connected],
      %{count: 1},
      %{nickname: nickname}
    )
  end

  @spec emit_disconnected(String.t()) :: :ok
  def emit_disconnected(nickname) do
    :telemetry.execute(
      [:retro_hex_chat, :accounts, :disconnected],
      %{count: 1},
      %{nickname: nickname}
    )
  end

  @spec emit_nick_changed(String.t(), String.t()) :: :ok
  def emit_nick_changed(old_nick, new_nick) do
    :telemetry.execute(
      [:retro_hex_chat, :accounts, :nick_changed],
      %{count: 1},
      %{old_nickname: old_nick, new_nickname: new_nick}
    )
  end
end
