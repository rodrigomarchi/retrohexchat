defmodule RetroHexChat.Calls.Health do
  @moduledoc """
  Operational health snapshot for call infrastructure.

  This is intentionally a backend readiness view. A real TURN connectivity probe
  requires ICE gathering from a WebRTC client, so this module checks whether the
  server-side pieces needed to serve that flow are configured and supervised.
  """

  alias RetroHexChat.GroupCall
  alias RetroHexChat.P2P
  alias RetroHexChat.P2P.RateLimitTable
  alias RetroHexChat.P2P.Turn
  alias RetroHexChat.P2P.Turn.AllocationRegistry
  alias RetroHexChat.P2P.Turn.AllocationSupervisor
  alias RetroHexChat.P2P.Turn.ListenerSupervisor
  alias RetroHexChat.P2P.Turn.Supervisor, as: TurnSupervisor

  @type status :: :ok | :degraded | :down

  @status_rank %{ok: 0, degraded: 1, down: 2}

  @spec check() :: map()
  def check do
    checks = %{
      p2p_signaling: p2p_signaling_check(),
      turn: turn_check(),
      conference: conference_check()
    }

    %{
      status: checks |> Map.values() |> aggregate_status() |> Atom.to_string(),
      checks: stringify_checks(checks)
    }
  end

  @spec http_status(map()) :: 200 | 503
  def http_status(%{status: "down"}), do: 503
  def http_status(_result), do: 200

  defp p2p_signaling_check do
    processes = %{
      pubsub: named_process_alive?(RetroHexChat.PubSub),
      lobby_supervisor: named_process_alive?(RetroHexChat.Lobby.Supervisor),
      session_registry: named_process_alive?(RetroHexChat.Lobby.SessionRegistry),
      rate_limit_table: p2p_rate_limit_table_ready?()
    }

    down_reasons =
      processes
      |> Enum.reject(fn {_name, alive?} -> alive? end)
      |> Enum.map(fn {name, _alive?} -> "p2p_#{name}_not_running" end)

    result_status(down_reasons, [], %{
      pubsub_ready: processes.pubsub,
      lobby_supervisor_ready: processes.lobby_supervisor,
      session_registry_ready: processes.session_registry,
      rate_limit_table_ready: processes.rate_limit_table
    })
  end

  defp turn_check do
    data = turn_health_data()

    result_status(turn_down_reasons(data), turn_degraded_reasons(data), %{
      configured: data.configured?,
      listener_count: %{
        expected: data.expected_listeners,
        active: data.active_listeners
      },
      ice_server_types: data.ice_server_types,
      relay_ports: data.relay_ports
    })
  end

  defp turn_health_data do
    configured? = P2P.turn_configured?()
    expected_listeners = Application.get_env(:retro_hex_chat, :turn_listener_count, 0)

    %{
      configured?: configured?,
      expected_listeners: expected_listeners,
      active_listeners: active_listener_count(),
      ice_server_types: ice_server_types(),
      relay_ports: turn_relay_ports()
    }
  end

  defp turn_down_reasons(%{configured?: configured?} = data) do
    turn_process_down_reasons(configured?) ++ turn_capacity_down_reasons(data)
  end

  defp turn_process_down_reasons(false), do: []

  defp turn_process_down_reasons(true) do
    [
      {TurnSupervisor, "turn_supervisor_not_running"},
      {ListenerSupervisor, "turn_listener_supervisor_not_running"},
      {AllocationSupervisor, "turn_allocation_supervisor_not_running"},
      {AllocationRegistry, "turn_allocation_registry_not_running"}
    ]
    |> Enum.reject(fn {process, _reason} -> named_process_alive?(process) end)
    |> Enum.map(fn {_process, reason} -> reason end)
  end

  defp turn_capacity_down_reasons(data) do
    []
    |> maybe_reason(data.configured? and data.active_listeners == 0, "turn_listeners_not_running")
    |> maybe_reason(
      data.configured? and data.relay_ports.total <= 0,
      "turn_relay_port_range_invalid"
    )
    |> maybe_reason(data.ice_server_types == [], "turn_ice_config_unavailable")
  end

  defp turn_degraded_reasons(data) do
    []
    |> maybe_reason(not data.configured?, "turn_disabled")
    |> maybe_reason(listeners_below_expected?(data), "turn_listeners_below_expected")
    |> maybe_reason(listeners_above_expected?(data), "turn_listeners_above_expected")
    |> maybe_reason(data.configured? and data.relay_ports.exhausted, "turn_relay_ports_exhausted")
  end

  defp listeners_below_expected?(data) do
    data.configured? and data.active_listeners > 0 and
      data.active_listeners < data.expected_listeners
  end

  defp listeners_above_expected?(data) do
    data.configured? and data.active_listeners > data.expected_listeners
  end

  defp conference_check do
    config = GroupCall.Config.from_application_env()
    enabled? = Map.fetch!(config, :enabled?)
    ice_port_count = config |> Map.fetch!(:ice_port_range) |> enumerable_count()

    down_reasons =
      []
      |> maybe_reason(
        enabled? and not named_process_alive?(RetroHexChat.GroupCall.Supervisor),
        "conference_supervisor_not_running"
      )
      |> maybe_reason(
        enabled? and not named_process_alive?(RetroHexChat.GroupCall.RoomSupervisor),
        "conference_room_supervisor_not_running"
      )
      |> maybe_reason(
        enabled? and not named_process_alive?(RetroHexChat.GroupCall.PeerSupervisor),
        "conference_peer_supervisor_not_running"
      )
      |> maybe_reason(
        enabled? and not named_process_alive?(RetroHexChat.GroupCall.RoomRegistry),
        "conference_room_registry_not_running"
      )
      |> maybe_reason(
        enabled? and not named_process_alive?(RetroHexChat.GroupCall.PeerRegistry),
        "conference_peer_registry_not_running"
      )
      |> maybe_reason(enabled? and ice_port_count <= 0, "conference_ice_port_range_empty")

    degraded_reasons =
      []
      |> maybe_reason(not enabled?, "conference_disabled")

    result_status(down_reasons, degraded_reasons, %{
      enabled: enabled?,
      room_supervisor_ready: named_process_alive?(RetroHexChat.GroupCall.RoomSupervisor),
      peer_supervisor_ready: named_process_alive?(RetroHexChat.GroupCall.PeerSupervisor),
      room_registry_ready: named_process_alive?(RetroHexChat.GroupCall.RoomRegistry),
      peer_registry_ready: named_process_alive?(RetroHexChat.GroupCall.PeerRegistry),
      ice_port_count: ice_port_count
    })
  end

  defp result_status(down_reasons, degraded_reasons, details) do
    status =
      cond do
        down_reasons != [] -> :down
        degraded_reasons != [] -> :degraded
        true -> :ok
      end

    %{
      status: status,
      reasons: Enum.reverse(down_reasons) ++ Enum.reverse(degraded_reasons),
      details: details
    }
  end

  defp aggregate_status(checks) do
    checks
    |> Enum.map(& &1.status)
    |> Enum.max_by(&Map.fetch!(@status_rank, &1), fn -> :ok end)
  end

  defp stringify_checks(checks) do
    Map.new(checks, fn {name, check} ->
      {name,
       %{
         status: Atom.to_string(check.status),
         reasons: check.reasons,
         details: check.details
       }}
    end)
  end

  defp maybe_reason(reasons, true, reason), do: [reason | reasons]
  defp maybe_reason(reasons, false, _reason), do: reasons

  defp named_process_alive?(name) when is_atom(name) do
    case Process.whereis(name) do
      pid when is_pid(pid) -> Process.alive?(pid)
      _other -> false
    end
  end

  defp p2p_rate_limit_table_ready? do
    named_process_alive?(RateLimitTable) and
      :ets.whereis(RateLimitTable.table_name()) != :undefined
  end

  defp active_listener_count do
    case supervisor_children(ListenerSupervisor) do
      %{active: active} -> active
      _children -> 0
    end
  end

  defp supervisor_children(name) do
    if named_process_alive?(name) do
      Supervisor.count_children(name)
    end
  catch
    :exit, _reason -> nil
  end

  defp registry_count(name) do
    if named_process_alive?(name), do: Registry.count(name), else: 0
  catch
    :exit, _reason -> 0
  end

  defp ice_server_types do
    "__healthcheck__"
    |> P2P.ice_servers()
    |> Enum.flat_map(fn server -> Map.get(server, :urls, []) end)
    |> Enum.map(&ice_server_type/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  catch
    _kind, _reason -> []
  end

  defp ice_server_type("turn:" <> _rest), do: "turn"
  defp ice_server_type("turns:" <> _rest), do: "turn"
  defp ice_server_type("stun:" <> _rest), do: "stun"
  defp ice_server_type("stuns:" <> _rest), do: "stun"
  defp ice_server_type(_url), do: nil

  defp turn_relay_ports do
    config = Turn.Config.from_application_env()
    {first, last} = config.relay_port_range
    total = max(last - first + 1, 0)
    active_allocations = registry_count(AllocationRegistry)

    %{
      total: total,
      exhausted: total > 0 and active_allocations >= total
    }
  catch
    _kind, _reason -> %{total: 0, exhausted: false}
  end

  defp enumerable_count(enumerable) do
    Enum.count(enumerable)
  catch
    _kind, _reason -> 0
  end
end
