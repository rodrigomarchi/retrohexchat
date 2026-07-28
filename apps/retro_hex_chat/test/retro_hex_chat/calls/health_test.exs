defmodule RetroHexChat.Calls.HealthTest do
  use ExUnit.Case, async: false

  alias RetroHexChat.Calls.Health

  @moduletag :unit

  setup do
    restore_on_exit([
      :turn_listener_count,
      :turn_relay_port_range,
      :group_call_enabled?,
      :sfu_ice_port_range
    ])

    :ok
  end

  describe "check/0" do
    test "reports disabled TURN as degraded without exposing secrets" do
      Application.put_env(:retro_hex_chat, :turn_listener_count, 0)
      Application.put_env(:retro_hex_chat, :group_call_enabled?, true)
      Application.put_env(:retro_hex_chat, :sfu_ice_port_range, [0])

      result = Health.check()

      assert result.status == "degraded"
      assert result.checks.p2p_signaling.status == "ok"
      assert result.checks.turn.status == "degraded"
      assert "turn_disabled" in result.checks.turn.reasons
      assert result.checks.turn.details.configured == false
      assert result.checks.turn.details.ice_server_types == ["stun"]
      assert result.checks.conference.status == "ok"

      refute inspect(result) =~ "test-auth-secret"
      refute inspect(result) =~ "test-nonce-secret"
      refute inspect(result) =~ "credential"
    end

    test "reports configured TURN listener drift as degraded or down" do
      active_listeners = active_turn_listeners()
      Application.put_env(:retro_hex_chat, :turn_listener_count, active_listeners + 1)
      Application.put_env(:retro_hex_chat, :turn_relay_port_range, {49_152, 49_152})
      Application.put_env(:retro_hex_chat, :group_call_enabled?, true)
      Application.put_env(:retro_hex_chat, :sfu_ice_port_range, [0])

      result = Health.check()

      if active_listeners == 0 do
        assert result.status == "down"
        assert result.checks.turn.status == "down"
        assert "turn_listeners_not_running" in result.checks.turn.reasons
      else
        assert result.status == "degraded"
        assert result.checks.turn.status == "degraded"
        assert "turn_listeners_below_expected" in result.checks.turn.reasons
      end

      assert result.checks.turn.details.configured == true

      assert result.checks.turn.details.listener_count == %{
               expected: active_listeners + 1,
               active: active_listeners
             }

      assert result.checks.turn.details.ice_server_types == ["turn"]
      assert result.checks.turn.details.relay_ports == %{total: 1, exhausted: false}
    end

    test "reports disabled conference as degraded" do
      Application.put_env(:retro_hex_chat, :turn_listener_count, 0)
      Application.put_env(:retro_hex_chat, :group_call_enabled?, false)
      Application.put_env(:retro_hex_chat, :sfu_ice_port_range, [0])

      result = Health.check()

      assert result.status == "degraded"
      assert result.checks.conference.status == "degraded"
      assert "conference_disabled" in result.checks.conference.reasons
      assert result.checks.conference.details.enabled == false
    end

    test "reports enabled conference with empty ICE port range as down" do
      Application.put_env(:retro_hex_chat, :turn_listener_count, 0)
      Application.put_env(:retro_hex_chat, :group_call_enabled?, true)
      Application.put_env(:retro_hex_chat, :sfu_ice_port_range, [])

      result = Health.check()

      assert result.status == "down"
      assert result.checks.conference.status == "down"
      assert "conference_ice_port_range_empty" in result.checks.conference.reasons
      assert result.checks.conference.details.ice_port_count == 0
    end
  end

  describe "http_status/1" do
    test "returns 503 only for down status" do
      assert Health.http_status(%{status: "ok"}) == 200
      assert Health.http_status(%{status: "degraded"}) == 200
      assert Health.http_status(%{status: "down"}) == 503
    end
  end

  defp restore_on_exit(keys) do
    previous = Map.new(keys, &{&1, Application.fetch_env(:retro_hex_chat, &1)})

    on_exit(fn ->
      Enum.each(previous, fn
        {key, {:ok, value}} -> Application.put_env(:retro_hex_chat, key, value)
        {key, :error} -> Application.delete_env(:retro_hex_chat, key)
      end)
    end)
  end

  defp active_turn_listeners do
    case Process.whereis(RetroHexChat.P2P.Turn.ListenerSupervisor) do
      pid when is_pid(pid) ->
        %{active: active} = Supervisor.count_children(RetroHexChat.P2P.Turn.ListenerSupervisor)
        active

      _other ->
        0
    end
  end
end
