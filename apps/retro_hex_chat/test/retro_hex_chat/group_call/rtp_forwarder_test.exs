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

  test "forwards late packets that fill small sequence gaps once" do
    spec = RTPForwarder.prepare(%{video: "video-track"})

    {_spec, forwarded} = forward_sequences(spec, :video, [100, 102, 101, 101, 103])

    assert forwarded == [100, 102, 101, 103]
  end

  test "keeps gap cache across RTP sequence rollover" do
    spec = RTPForwarder.prepare(%{audio: "audio-track"})

    {_spec, forwarded} =
      forward_sequences(spec, :audio, [
        @max_sequence - 1,
        1,
        @max_sequence,
        0,
        @max_sequence,
        2
      ])

    assert forwarded == [@max_sequence - 1, 1, @max_sequence, 0, 2]
  end

  defp packet(sequence_number) do
    Packet.new(<<1, 2, 3>>,
      payload_type: 96,
      sequence_number: sequence_number,
      timestamp: sequence_number * 3_000,
      ssrc: 1234
    )
  end

  defp forward_sequences(spec, kind, sequences) do
    owner = self()

    spec =
      Enum.reduce(sequences, spec, fn sequence, spec ->
        RTPForwarder.forward(spec, kind, packet(sequence), fn _track_id, forwarded ->
          send(owner, {:forwarded, forwarded.sequence_number})
        end)
      end)

    {spec, collect_forwarded([])}
  end

  defp collect_forwarded(acc) do
    receive do
      {:forwarded, sequence} -> collect_forwarded([sequence | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
