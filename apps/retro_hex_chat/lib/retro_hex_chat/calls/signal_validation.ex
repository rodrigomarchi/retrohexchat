defmodule RetroHexChat.Calls.SignalValidation do
  @moduledoc """
  What counts as an acceptable WebRTC signalling payload.

  Every value checked here arrives from a browser and is therefore hostile until
  proven otherwise. The server does not read what an SDP *says* — it is a relay,
  not a participant — but it does refuse payloads that are the wrong shape or
  large enough to be a denial-of-service rather than a call.

  Both signalling paths validate through this module: the 1:1 P2P session, whose
  envelope is assembled by `RetroHexChat.P2P.validate_signal/1`, and the SFU
  group call, whose channel validates each event as it arrives. Holding the
  limits in one place is the point — a bound relaxed for one path used to leave
  the other untouched and untested, with nothing to signal the difference.

  What a caller keeps is its own policy for a rejection. A malformed identifier
  can reasonably be dropped by one path and refuse the whole signal on another;
  what neither path gets to decide alone is the bound itself.
  """

  @max_sdp_bytes 256_000
  @max_candidate_bytes 4_096
  @max_mid_bytes 64
  @max_offer_id_bytes 80
  @max_m_line_index 128

  @type result(value) :: {:ok, value} | {:error, :invalid_signal}

  @doc """
  Accepts a session description, bounded because an SDP is attacker-sized
  otherwise and the server forwards it verbatim to the peer.
  """
  @spec validate_sdp(term()) :: result(String.t())
  def validate_sdp(sdp)
      when is_binary(sdp) and sdp != "" and byte_size(sdp) <= @max_sdp_bytes,
      do: {:ok, sdp}

  def validate_sdp(_sdp), do: {:error, :invalid_signal}

  @doc """
  Accepts an ICE candidate, rebuilt from the three fields the peer needs.

  A candidate naming neither a media section nor its index cannot be applied by
  the receiving peer, so it is refused rather than relayed. Keys absent from the
  input stay absent from the output — a candidate carrying an explicit `null`
  is not the same as one carrying an index of zero.
  """
  @spec validate_candidate(term()) :: result(map())
  def validate_candidate(%{} = candidate) do
    candidate_text = Map.get(candidate, "candidate")
    sdp_mid = Map.get(candidate, "sdpMid")
    sdp_m_line_index = Map.get(candidate, "sdpMLineIndex")

    cond do
      not valid_candidate_text?(candidate_text) ->
        {:error, :invalid_signal}

      not valid_mid?(sdp_mid) ->
        {:error, :invalid_signal}

      not valid_m_line_index?(sdp_m_line_index) ->
        {:error, :invalid_signal}

      is_nil(sdp_mid) and is_nil(sdp_m_line_index) ->
        {:error, :invalid_signal}

      true ->
        {:ok,
         %{"candidate" => candidate_text}
         |> maybe_put("sdpMid", sdp_mid)
         |> maybe_put("sdpMLineIndex", sdp_m_line_index)}
    end
  end

  def validate_candidate(_candidate), do: {:error, :invalid_signal}

  @doc """
  Accepts the identifier correlating an answer with the offer that prompted it.

  Absent is valid — not every signal carries one — so `nil` returns `{:ok, nil}`
  and a caller distinguishes "not supplied" from "supplied and malformed".
  """
  @spec validate_offer_id(term()) :: result(String.t() | nil)
  def validate_offer_id(nil), do: {:ok, nil}

  def validate_offer_id(offer_id)
      when is_binary(offer_id) and offer_id != "" and byte_size(offer_id) <= @max_offer_id_bytes,
      do: {:ok, offer_id}

  def validate_offer_id(_offer_id), do: {:error, :invalid_signal}

  defp valid_candidate_text?(text) do
    is_binary(text) and text != "" and byte_size(text) <= @max_candidate_bytes
  end

  defp valid_mid?(nil), do: true
  defp valid_mid?(mid), do: is_binary(mid) and byte_size(mid) <= @max_mid_bytes

  defp valid_m_line_index?(nil), do: true

  defp valid_m_line_index?(index),
    do: is_integer(index) and index >= 0 and index < @max_m_line_index

  defp maybe_put(candidate, _key, nil), do: candidate
  defp maybe_put(candidate, key, value), do: Map.put(candidate, key, value)
end
