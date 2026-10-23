defmodule RetroHexChat.Jobs.ExpirySweep do
  @moduledoc """
  One run of a registration expiry sweep (channels or nicknames): a telemetry
  span around the service's `purge`, a log line when anything was released,
  and every count the purge reports — not the released names — on the span.
  """

  alias RetroHexChat.Observability

  require Logger

  @doc """
  Runs `purge` inside the `[:retro_hex_chat, :services, kind, :expire]` span;
  `label` names the log line (`"<label>_stop"`).
  """
  @spec run(atom(), String.t(), (-> map())) :: {:ok, map()}
  def run(kind, label, purge) do
    Observability.span(
      [:retro_hex_chat, :services, kind, :expire],
      %{domain: "maintenance"},
      fn -> sweep(label, purge) end,
      &metadata/1
    )
  end

  defp sweep(label, purge) do
    result = purge.()

    Observability.set_current_span_attributes(metadata({:ok, result}))

    if result.purged_count > 0 do
      Logger.info(
        "#{label}_stop candidates=#{result.candidate_count} purged=#{result.purged_count}"
      )
    end

    {:ok, result}
  end

  defp metadata({:ok, result}), do: result |> Map.delete(:purged_names) |> Map.put(:result, "ok")
end
