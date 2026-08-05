defmodule RetroHexChatWeb.SystemMetrics.Datapoint do
  @moduledoc """
  Reading one telemetry event through the lens of one metric definition.

  `Telemetry.Metrics` only *describes* metrics — which event feeds them, which
  measurement to take, how to derive tags. Turning an event into a datapoint is
  the reporter's job, and this is that step, kept separate from the process
  that buffers them so it can be tested without one.

  The series label comes from the metric's tags, which is what splits one
  definition into several lines on a chart: `phoenix.router_dispatch.stop`
  tagged by route yields one series per route from a single metric.

  Extraction is pure and total: an event that the metric declines to keep, or
  whose measurement is absent, yields `nil` rather than a zero. A missing
  reading and a reading of zero are different facts, and only one of them
  belongs on a chart.
  """

  @type point :: {label :: String.t() | nil, value :: number(), time_ms :: integer()}

  @doc """
  Extracts a datapoint, or `nil` if this event does not feed this metric.

  The timestamp is taken here rather than at render, so a point carries the
  moment it happened rather than the moment somebody looked.
  """
  @spec extract(Telemetry.Metrics.t(), map(), map()) :: point() | nil
  def extract(metric, measurements, metadata) do
    with true <- keep?(metric, metadata),
         value when is_number(value) <- measure(metric, measurements, metadata) do
      {label(metric, metadata), convert(metric, value), System.system_time(:millisecond)}
    else
      _other -> nil
    end
  end

  defp keep?(%{keep: keep}, metadata) when is_function(keep, 1), do: keep.(metadata)
  defp keep?(_metric, _metadata), do: true

  defp measure(%{measurement: fun}, measurements, metadata) when is_function(fun, 2) do
    fun.(measurements, metadata)
  end

  defp measure(%{measurement: fun}, measurements, _metadata) when is_function(fun, 1) do
    fun.(measurements)
  end

  defp measure(%{measurement: key}, measurements, _metadata), do: Map.get(measurements, key)

  # A duration in native units is meaningless to a reader; the metric declares
  # what it should be shown in, so the conversion belongs with the reading.
  defp convert(%{unit: {from, to}}, value), do: System.convert_time_unit(value, from, to)
  defp convert(_metric, value), do: value

  # Tag values compose the series name. A metric with no tags is a single
  # series and carries no label at all, rather than an empty one.
  defp label(%{tags: []}, _metadata), do: nil

  defp label(%{tags: tags, tag_values: tag_values}, metadata) do
    values = tag_values.(metadata)

    tags
    |> Enum.flat_map(fn tag ->
      case values do
        %{^tag => value} -> [to_string(value)]
        _missing -> []
      end
    end)
    |> case do
      [] -> nil
      parts -> Enum.join(parts, " ")
    end
  end
end
