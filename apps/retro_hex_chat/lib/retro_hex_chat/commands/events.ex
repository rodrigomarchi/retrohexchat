defmodule RetroHexChat.Commands.Events do
  @moduledoc """
  Telemetry events for the Commands context.
  """

  @spec emit_command_executed(String.t(), String.t()) :: :ok
  def emit_command_executed(command_name, nickname) do
    :telemetry.execute(
      [:retro_hex_chat, :commands, :command_executed],
      %{count: 1},
      %{command: command_name, nickname: nickname}
    )
  end
end
