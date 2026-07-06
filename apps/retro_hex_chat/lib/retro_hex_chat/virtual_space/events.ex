defmodule RetroHexChat.VirtualSpace.Events do
  @moduledoc """
  Telemetry events for the VirtualSpace context.

  Emitted at the domain borders (session creation, participant join, session
  end) so the metrics defined in `RetroHexChatWeb.Telemetry` can count them.
  """

  @spec emit_session_created(String.t(), String.t()) :: :ok
  def emit_session_created(token, channel) do
    :telemetry.execute(
      [:retro_hex_chat, :virtual_space, :session_created],
      %{count: 1},
      %{token: token, channel: channel}
    )
  end

  @spec emit_participant_joined(String.t()) :: :ok
  def emit_participant_joined(token) do
    :telemetry.execute(
      [:retro_hex_chat, :virtual_space, :participant_joined],
      %{count: 1},
      %{token: token}
    )
  end

  @spec emit_session_ended(String.t(), String.t()) :: :ok
  def emit_session_ended(token, status) do
    :telemetry.execute(
      [:retro_hex_chat, :virtual_space, :session_ended],
      %{count: 1},
      %{token: token, status: status}
    )
  end
end
