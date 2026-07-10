defmodule RetroHexChat.GroupCall.ScaleInspectionTest do
  use ExUnit.Case, async: false

  alias RetroHexChat.GroupCall.ScaleInspection

  @moduletag :performance

  test "fanout plan has one route per publisher, subscriber, and track" do
    routes = ScaleInspection.fanout_plan(3, 2)

    assert length(routes) == 12
    assert length(routes) == ScaleInspection.expected_route_count(3, 2)
    refute Enum.any?(routes, &(&1.publisher_id == &1.subscriber_id))

    assert Enum.any?(routes, fn route ->
             route.publisher_id == 1 and route.subscriber_id == 2 and
               route.kind == "audio" and route.source == "microphone"
           end)

    assert Enum.any?(routes, fn route ->
             route.publisher_id == 1 and route.subscriber_id == 2 and
               route.kind == "video" and route.source == "camera"
           end)
  end

  test "run returns deterministic fanout and payload baseline for participant counts" do
    report = ScaleInspection.run([3, 10])

    assert %{generated_at: %DateTime{}, participant_results: [small, larger]} = report
    assert small.fanout.route_count == 12
    assert small.fanout.route_count == small.fanout.expected_route_count
    assert small.fanout.build_time_us >= 0
    assert small.fanout.reductions >= 0

    assert larger.fanout.route_count == 180
    assert larger.fanout.route_count == larger.fanout.expected_route_count
    assert larger.payload_bytes.summary > small.payload_bytes.summary
    assert larger.largest_payload == {:summary, larger.payload_bytes.summary}
  end

  test "payload size inspection includes every UI event shape used by group calls" do
    sizes = ScaleInspection.payload_sizes(3, 2)

    assert sizes.summary > 0
    assert sizes.peer_joined > 0
    assert sizes.peer_left > 0
    assert sizes.track_added > 0
    assert sizes.track_updated > 0
    assert sizes.track_removed > 0
    assert sizes.media_state > 0
    assert sizes.summary > sizes.peer_joined
  end

  test "peer process sampling exposes BEAM pressure fields for registered peers" do
    key = {:peer, System.unique_integer([:positive]), System.unique_integer([:positive])}

    {:ok, _owner} =
      Registry.register(RetroHexChat.GroupCall.PeerRegistry, key, %{source: :scale_test})

    on_exit(fn ->
      Registry.unregister(RetroHexChat.GroupCall.PeerRegistry, key)
    end)

    sample =
      ScaleInspection.sample_peer_processes()
      |> Enum.find(&(&1.key == key))

    assert sample
    assert sample.pid == inspect(self())
    assert sample.memory_bytes > 0
    assert sample.message_queue_len >= 0
    assert sample.reductions >= 0
    assert sample.heap_size > 0
    assert sample.total_heap_size >= sample.heap_size
    assert sample.stack_size >= 0
  end
end
