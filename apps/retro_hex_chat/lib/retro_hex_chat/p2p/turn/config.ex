defmodule RetroHexChat.P2P.Turn.Config do
  @moduledoc """
  Centralized TURN server configuration.
  Replaces all `Application.fetch_env!(:rel, ...)` calls from the extracted rel modules.
  """

  @type t :: %__MODULE__{
          listen_ip: :inet.ip_address(),
          listen_port: :inet.port_number(),
          relay_ip: :inet.ip_address(),
          relay_port_range: {non_neg_integer(), non_neg_integer()},
          listener_count: non_neg_integer(),
          realm: String.t(),
          auth_secret: binary(),
          nonce_secret: binary(),
          credentials_lifetime: non_neg_integer(),
          nonce_lifetime: non_neg_integer(),
          default_allocation_lifetime: non_neg_integer(),
          max_allocation_lifetime: non_neg_integer(),
          permission_lifetime: non_neg_integer(),
          channel_lifetime: non_neg_integer()
        }

  @enforce_keys [
    :listen_ip,
    :listen_port,
    :relay_ip,
    :relay_port_range,
    :listener_count,
    :realm,
    :auth_secret,
    :nonce_secret,
    :credentials_lifetime,
    :nonce_lifetime,
    :default_allocation_lifetime,
    :max_allocation_lifetime,
    :permission_lifetime,
    :channel_lifetime
  ]

  defstruct @enforce_keys

  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct!(__MODULE__, attrs)
  end

  @spec from_application_env() :: t()
  def from_application_env do
    relay_ip = resolve_relay_ip(Application.get_env(:retro_hex_chat, :turn_relay_ip, :auto))

    new(%{
      listen_ip: Application.get_env(:retro_hex_chat, :turn_listen_ip, {0, 0, 0, 0}),
      listen_port: Application.get_env(:retro_hex_chat, :turn_listen_port, 3478),
      relay_ip: relay_ip,
      relay_port_range:
        Application.get_env(:retro_hex_chat, :turn_relay_port_range, {49_152, 65_535}),
      listener_count: Application.get_env(:retro_hex_chat, :turn_listener_count, 1),
      realm: Application.fetch_env!(:retro_hex_chat, :turn_realm),
      auth_secret: Application.fetch_env!(:retro_hex_chat, :turn_auth_secret),
      nonce_secret: Application.fetch_env!(:retro_hex_chat, :turn_nonce_secret),
      credentials_lifetime: Application.fetch_env!(:retro_hex_chat, :turn_credentials_lifetime),
      nonce_lifetime: Application.fetch_env!(:retro_hex_chat, :turn_nonce_lifetime),
      default_allocation_lifetime:
        Application.fetch_env!(:retro_hex_chat, :turn_default_allocation_lifetime),
      max_allocation_lifetime:
        Application.fetch_env!(:retro_hex_chat, :turn_max_allocation_lifetime),
      permission_lifetime: Application.fetch_env!(:retro_hex_chat, :turn_permission_lifetime),
      channel_lifetime: Application.fetch_env!(:retro_hex_chat, :turn_channel_lifetime)
    })
  end

  @spec guess_external_ip() :: :inet.ip_address()
  def guess_external_ip do
    case :inet.getifaddrs() do
      {:ok, ifaddrs} ->
        ifaddrs
        |> Enum.flat_map(fn {_name, opts} -> Keyword.get_values(opts, :addr) end)
        |> Enum.find({127, 0, 0, 1}, fn
          {127, _, _, _} -> false
          {a, _, _, _} when a in [10, 172, 192] -> true
          {_, _, _, _} -> true
          _ -> false
        end)

      {:error, _} ->
        {127, 0, 0, 1}
    end
  end

  defp resolve_relay_ip(:auto), do: guess_external_ip()
  defp resolve_relay_ip(ip) when is_tuple(ip), do: ip
end
