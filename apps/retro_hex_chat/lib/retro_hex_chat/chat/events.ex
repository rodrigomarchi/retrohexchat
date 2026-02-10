defmodule RetroHexChat.Chat.Events do
  @moduledoc """
  Telemetry events for the Chat context.
  """

  @spec emit_message_sent(String.t(), String.t(), String.t()) :: :ok
  def emit_message_sent(channel, nickname, type) do
    :telemetry.execute(
      [:retro_hex_chat, :chat, :message_sent],
      %{count: 1},
      %{channel: channel, nickname: nickname, type: type}
    )
  end

  @spec emit_message_persisted(String.t(), integer()) :: :ok
  def emit_message_persisted(channel, message_id) do
    :telemetry.execute(
      [:retro_hex_chat, :chat, :message_persisted],
      %{count: 1},
      %{channel: channel, message_id: message_id}
    )
  end
end
