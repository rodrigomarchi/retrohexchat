defmodule RetroHexChat.GroupCall.Config do
  @moduledoc """
  Runtime configuration for embedded group-call SFU processes.
  """

  @type t :: %{
          enabled?: boolean(),
          max_participants: pos_integer(),
          ready_timeout_ms: pos_integer(),
          reconnect_timeout_ms: pos_integer(),
          peerless_timeout_ms: pos_integer(),
          ice_port_range: Enumerable.t(non_neg_integer()),
          ice_transport_policy: :all | :relay,
          host_to_srflx_ip_mapper: (:inet.ip_address() -> :inet.ip_address() | nil) | nil
        }

  @spec from_application_env() :: t()
  def from_application_env do
    %{
      enabled?: Application.get_env(:retro_hex_chat, :group_call_enabled?, true),
      max_participants: Application.get_env(:retro_hex_chat, :group_call_max_participants, 100),
      ready_timeout_ms:
        Application.get_env(:retro_hex_chat, :group_call_ready_timeout_ms, 10_000),
      reconnect_timeout_ms:
        Application.get_env(:retro_hex_chat, :group_call_reconnect_timeout_ms, 30_000),
      peerless_timeout_ms:
        Application.get_env(:retro_hex_chat, :group_call_peerless_timeout_ms, 60_000),
      ice_port_range: Application.get_env(:retro_hex_chat, :sfu_ice_port_range, 50_000..50_100),
      ice_transport_policy: Application.get_env(:retro_hex_chat, :sfu_ice_transport_policy, :all),
      host_to_srflx_ip_mapper:
        public_ip_mapper(Application.get_env(:retro_hex_chat, :sfu_public_ip))
    }
  end

  defp public_ip_mapper(nil), do: nil

  defp public_ip_mapper(public_ip) when is_tuple(public_ip) do
    if local_ip?(public_ip) do
      nil
    else
      fn _host_ip -> public_ip end
    end
  end

  defp local_ip?(ip) do
    case :inet.getifaddrs() do
      {:ok, ifaddrs} ->
        Enum.any?(ifaddrs, fn {_name, opts} ->
          Enum.any?(Keyword.get_values(opts, :addr), &(&1 == ip))
        end)

      {:error, _reason} ->
        false
    end
  end
end
