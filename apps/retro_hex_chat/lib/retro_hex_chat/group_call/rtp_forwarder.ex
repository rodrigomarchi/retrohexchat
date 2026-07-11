defmodule RetroHexChat.GroupCall.RTPForwarder do
  @moduledoc false

  alias ExRTP.Packet
  alias ExWebRTC.RTP.Munger

  @sequence_breakpoint 0x7FFF

  @spec prepare(map()) :: map()
  def prepare(spec) do
    spec
    |> Map.put(:rtp_mungers, %{audio: Munger.new(:opus, 48_000), video: Munger.new(:vp8, 90_000)})
    |> Map.put(:last_rtp_sequences, %{audio: nil, video: nil})
  end

  @spec reset_kind(map(), :audio | :video) :: map()
  def reset_kind(spec, kind) when kind in [:audio, :video] do
    spec
    |> update_in([:rtp_mungers, kind], fn
      %Munger{} = munger -> Munger.update(munger)
      _missing -> new_munger(kind)
    end)
    |> put_in([:last_rtp_sequences, kind], nil)
  end

  @spec forward(map(), :audio | :video, Packet.t(), (String.t(), Packet.t() -> term())) :: map()
  def forward(spec, kind, %Packet{} = packet, send_packet) when kind in [:audio, :video] do
    track_id = Map.get(spec, kind)

    if track_id do
      {packet, spec} = munge_packet(spec, kind, packet)

      if fresh_sequence?(packet.sequence_number, get_in(spec, [:last_rtp_sequences, kind])) do
        send_packet.(track_id, packet)
        put_in(spec, [:last_rtp_sequences, kind], packet.sequence_number)
      else
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

  defp fresh_sequence?(_sequence, nil), do: true

  defp fresh_sequence?(sequence, last_sequence) do
    delta = sequence - last_sequence
    delta < -@sequence_breakpoint or (delta > 0 and delta < @sequence_breakpoint)
  end

  defp new_munger(:audio), do: Munger.new(:opus, 48_000)
  defp new_munger(:video), do: Munger.new(:vp8, 90_000)
end
