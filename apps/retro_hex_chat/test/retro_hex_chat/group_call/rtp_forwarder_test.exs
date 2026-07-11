defmodule RetroHexChat.GroupCall.RTPForwarderTest do
  use ExUnit.Case, async: true

  alias ExRTP.Packet
  alias RetroHexChat.GroupCall.RTPForwarder

  @moduletag :unit
  @max_sequence 0xFFFF

  test "forwards fresh packets and skips duplicate RTP sequence numbers" do
    owner = self()
    spec = RTPForwarder.prepare(%{video: "video-track"})

    packet = packet(100)

    spec =
      RTPForwarder.forward(spec, :video, packet, fn track_id, forwarded ->
        send(owner, {:forwarded, track_id, forwarded.sequence_number})
      end)

    assert_receive {:forwarded, "video-track", 100}

    _spec =
      RTPForwarder.forward(spec, :video, packet, fn track_id, forwarded ->
        send(owner, {:forwarded, track_id, forwarded.sequence_number})
      end)

    refute_receive {:forwarded, "video-track", 100}
  end

  test "resets a media kind before forwarding a new RTP stream" do
    owner = self()

    spec =
      %{video: "video-track"}
      |> RTPForwarder.prepare()
      |> RTPForwarder.forward(:video, packet(2_000), fn _track_id, _forwarded -> :ok end)
      |> RTPForwarder.reset_kind(:video)

    _spec =
      RTPForwarder.forward(spec, :video, packet(100), fn track_id, forwarded ->
        send(owner, {:forwarded, track_id, forwarded.sequence_number})
      end)

    assert_receive {:forwarded, "video-track", sequence}
    assert sequence != 100
  end

  test "accepts RTP sequence rollover" do
    owner = self()

    spec =
      %{audio: "audio-track"}
      |> RTPForwarder.prepare()
      |> RTPForwarder.forward(:audio, packet(@max_sequence), fn _track_id, _forwarded -> :ok end)

    _spec =
      RTPForwarder.forward(spec, :audio, packet(0), fn track_id, forwarded ->
        send(owner, {:forwarded, track_id, forwarded.sequence_number})
      end)

    assert_receive {:forwarded, "audio-track", 0}
  end

  defp packet(sequence_number) do
    Packet.new(<<1, 2, 3>>,
      payload_type: 96,
      sequence_number: sequence_number,
      timestamp: sequence_number * 3_000,
      ssrc: 1234
    )
  end
end
