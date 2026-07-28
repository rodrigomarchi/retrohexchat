defmodule RetroHexChatWeb.CallsHealthControllerTest do
  use RetroHexChatWeb.ConnCase, async: false

  setup do
    restore_on_exit([
      :turn_listener_count,
      :turn_relay_port_range,
      :group_call_enabled?,
      :sfu_ice_port_range
    ])

    :ok
  end

  test "GET /api/calls/healthz returns degraded call readiness when TURN is disabled", %{
    conn: conn
  } do
    Application.put_env(:retro_hex_chat, :turn_listener_count, 0)
    Application.put_env(:retro_hex_chat, :group_call_enabled?, true)
    Application.put_env(:retro_hex_chat, :sfu_ice_port_range, [0])

    conn = get(conn, ~p"/api/calls/healthz")

    body = json_response(conn, 200)
    assert body["status"] == "degraded"
    assert body["checks"]["p2p_signaling"]["status"] == "ok"
    assert body["checks"]["turn"]["status"] == "degraded"
    assert "turn_disabled" in body["checks"]["turn"]["reasons"]
    assert body["checks"]["turn"]["details"]["ice_server_types"] == ["stun"]
    assert body["checks"]["conference"]["status"] == "ok"
  end

  test "GET /api/calls/healthz returns 503 when conference ICE config is unusable", %{
    conn: conn
  } do
    Application.put_env(:retro_hex_chat, :turn_listener_count, 0)
    Application.put_env(:retro_hex_chat, :group_call_enabled?, true)
    Application.put_env(:retro_hex_chat, :sfu_ice_port_range, [])

    conn = get(conn, ~p"/api/calls/healthz")

    body = json_response(conn, 503)
    assert body["status"] == "down"
    assert body["checks"]["conference"]["status"] == "down"
    assert "conference_ice_port_range_empty" in body["checks"]["conference"]["reasons"]
    assert body["checks"]["conference"]["details"]["ice_port_count"] == 0
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
end
