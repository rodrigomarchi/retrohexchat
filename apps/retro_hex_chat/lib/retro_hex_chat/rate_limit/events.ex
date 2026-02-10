defmodule RetroHexChat.RateLimit.Events do
  @moduledoc """
  Telemetry events for the RateLimit context.
  """

  @spec emit_rate_limited(String.t(), :message | :command) :: :ok
  def emit_rate_limited(nickname, type) do
    :telemetry.execute(
      [:retro_hex_chat, :rate_limit, :rate_limited],
      %{count: 1},
      %{nickname: nickname, type: type}
    )
  end
end
