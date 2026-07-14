defmodule RetroHexChat.GroupCall.RTPForwarder do
  @moduledoc false

  alias ExRTP.Packet
  alias ExWebRTC.RTP.Munger

  @sequence_breakpoint 0x7FFF
  @sequence_modulus 0x1_0000
  @max_reorder_cache 64

  @spec prepare(map()) :: map()
  def prepare(spec) do
    spec
    |> Map.put(:rtp_mungers, %{audio: Munger.new(:opus, 48_000), video: Munger.new(:vp8, 90_000)})
    |> Map.put(:last_rtp_sequences, %{audio: nil, video: nil})
    |> Map.put(:missing_rtp_sequences, %{audio: MapSet.new(), video: MapSet.new()})
  end

  @spec reset_kind(map(), :audio | :video) :: map()
  def reset_kind(spec, kind) when kind in [:audio, :video] do
    spec
    |> update_in([:rtp_mungers, kind], fn
      %Munger{} = munger -> Munger.update(munger)
      _missing -> new_munger(kind)
    end)
    |> put_in([:last_rtp_sequences, kind], nil)
    |> put_in([:missing_rtp_sequences, kind], MapSet.new())
  end

  @spec forward(map(), :audio | :video, Packet.t(), (String.t(), Packet.t() -> term())) :: map()
  def forward(spec, kind, %Packet{} = packet, send_packet) when kind in [:audio, :video] do
    track_id = Map.get(spec, kind)

    if track_id do
      {packet, spec} = munge_packet(spec, kind, packet)

      case classify_sequence(spec, kind, packet.sequence_number) do
        {:forward, spec} ->
          send_packet.(track_id, packet)
          spec

        {:drop, spec} ->
          spec
      end
    else
      spec
    end
  end

  defp munge_packet(spec, kind, packet) do
    munger = get_in(spec, [:rtp_mungers, kind]) || new_munger(kind)
    {packet, munger} = Munger.munge(munger, packet)
    {packet, put_in(spec, [:rtp_mungers, kind], munger)}
  end

  defp classify_sequence(spec, kind, sequence) do
    last_sequence = get_in(spec, [:last_rtp_sequences, kind])
    missing_sequences = get_in(spec, [:missing_rtp_sequences, kind]) || MapSet.new()

    cond do
      is_nil(last_sequence) ->
        {:forward, put_in(spec, [:last_rtp_sequences, kind], sequence)}

      MapSet.member?(missing_sequences, sequence) ->
        spec =
          put_in(spec, [:missing_rtp_sequences, kind], MapSet.delete(missing_sequences, sequence))

        {:forward, spec}

      distance = forward_distance(sequence, last_sequence) ->
        missing_sequences =
          missing_sequences
          |> remember_missing_sequences(last_sequence, distance)
          |> prune_missing_sequences(sequence)

        spec =
          spec
          |> put_in([:last_rtp_sequences, kind], sequence)
          |> put_in([:missing_rtp_sequences, kind], missing_sequences)

        {:forward, spec}

      true ->
        {:drop, spec}
    end
  end

  defp forward_distance(sequence, last_sequence) do
    delta = sequence - last_sequence

    cond do
      delta < -@sequence_breakpoint -> sequence + @sequence_modulus - last_sequence
      delta > 0 and delta < @sequence_breakpoint -> delta
      true -> nil
    end
  end

  defp remember_missing_sequences(missing_sequences, _last_sequence, distance)
       when distance <= 1 or distance > @max_reorder_cache,
       do: missing_sequences

  defp remember_missing_sequences(missing_sequences, last_sequence, distance) do
    1..(distance - 1)
    |> Enum.reduce(missing_sequences, fn offset, acc ->
      MapSet.put(acc, rem(last_sequence + offset, @sequence_modulus))
    end)
  end

  defp prune_missing_sequences(missing_sequences, last_sequence) do
    Enum.reduce(missing_sequences, MapSet.new(), fn sequence, acc ->
      distance = rem(last_sequence - sequence + @sequence_modulus, @sequence_modulus)

      if distance > 0 and distance <= @max_reorder_cache do
        MapSet.put(acc, sequence)
      else
        acc
      end
    end)
  end

  defp new_munger(:audio), do: Munger.new(:opus, 48_000)
  defp new_munger(:video), do: Munger.new(:vp8, 90_000)
end
