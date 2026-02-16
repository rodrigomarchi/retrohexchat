defmodule RetroHexChat.P2P.SignalingRateLimit do
  @moduledoc """
  Behaviour for signaling message rate limiting.
  Implementations must provide a `check_signal_rate/2` callback.
  The default implementation (Noop) allows all signals.
  """

  @callback check_signal_rate(session_token :: String.t(), user_id :: integer()) ::
              :ok | {:error, :rate_limited}

  @spec configured_module() :: module()
  def configured_module do
    Application.get_env(:retro_hex_chat, :signaling_rate_limiter, __MODULE__.Noop)
  end
end

defmodule RetroHexChat.P2P.SignalingRateLimit.Noop do
  @moduledoc false
  @behaviour RetroHexChat.P2P.SignalingRateLimit

  @impl true
  @spec check_signal_rate(String.t(), integer()) :: :ok
  def check_signal_rate(_session_token, _user_id), do: :ok
end
