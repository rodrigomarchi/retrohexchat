defmodule RetroHexChat.Services.Events do
  @moduledoc "Telemetry events for NickServ/ChanServ services."

  @spec emit_nick_registered(String.t()) :: :ok
  def emit_nick_registered(nickname) do
    :telemetry.execute(
      [:retro_hex_chat, :nickserv, :registered],
      %{count: 1},
      %{nickname: nickname}
    )
  end

  @spec emit_nick_identified(String.t()) :: :ok
  def emit_nick_identified(nickname) do
    :telemetry.execute(
      [:retro_hex_chat, :nickserv, :identified],
      %{count: 1},
      %{nickname: nickname}
    )
  end
end
