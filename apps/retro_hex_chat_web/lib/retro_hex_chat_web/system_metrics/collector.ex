defmodule RetroHexChatWeb.SystemMetrics.Collector do
  @moduledoc """
  Buffers telemetry datapoints for one open Metrics window.

  A `:telemetry` handler runs inside whichever process emitted the event, so
  whatever it does is paid for by the request, the query, the render that
  triggered it. Sending straight to the LiveView would make the window's cost
  scale with the server's traffic and — worse — flood the LiveView's mailbox
  with one message per database query on a busy node.

  So the handler does the least possible: it casts one datapoint into this
  process and returns. This process absorbs the rate, keeps a bounded window of
  recent points per series, and hands over a snapshot when asked. The window
  polls it on a timer, which decouples what the screen costs from what the
  server is doing.

  Buffers are bounded by count, not by age: a series that stops receiving
  events keeps its last points rather than emptying, because a metric that went
  quiet is itself worth seeing.

  One collector per open window, monitoring the LiveView that asked for it —
  closing the window, navigating away or crashing all take the collector and
  its handlers with it. Deliberately *monitored* rather than linked: a link
  runs both ways, and a fault while charting a metric would then take down the
  chat session the window is floating above. Diagnostics must not be able to
  break the thing they are diagnosing.
  """

  use GenServer, restart: :temporary

  alias RetroHexChatWeb.SystemMetrics.Datapoint

  @buffer_size 60

  @type series :: %{label: String.t() | nil, points: [Datapoint.point()]}

  @doc """
  Starts a collector attached to `metrics`, watching the calling process.

  The monitor is the whole lifecycle: there is no unsubscribe to forget, and no
  handler can outlive the window that installed it.
  """
  @spec start([Telemetry.Metrics.t()]) :: GenServer.on_start()
  def start(metrics) when is_list(metrics) do
    GenServer.start(__MODULE__, {self(), metrics})
  end

  @doc """
  Every series collected so far, keyed by metric index.

  Returns an empty map if the collector has gone away, so a window whose
  collector crashed renders empty rather than crashing with it.
  """
  @spec snapshot(pid()) :: %{non_neg_integer() => [series()]}
  def snapshot(collector) do
    GenServer.call(collector, :snapshot)
  catch
    :exit, _reason -> %{}
  end

  @doc false
  @spec handle_event(:telemetry.event_name(), map(), map(), term()) :: :ok
  def handle_event(_event, measurements, metadata, {collector, metrics}) do
    for {metric, index} <- metrics,
        point = Datapoint.extract(metric, measurements, metadata) do
      GenServer.cast(collector, {:point, index, point})
    end

    :ok
  end

  @impl true
  def init({owner, metrics}) do
    Process.flag(:trap_exit, true)
    Process.monitor(owner)

    indexed = Enum.with_index(metrics)

    for {event, group} <- Enum.group_by(indexed, fn {metric, _index} -> metric.event_name end) do
      :telemetry.attach(
        handler_id(event),
        event,
        &__MODULE__.handle_event/4,
        {self(), group}
      )
    end

    {:ok, %{series: %{}, events: indexed |> Enum.map(&elem(&1, 0).event_name) |> Enum.uniq()}}
  end

  @impl true
  def handle_cast({:point, index, point}, state) do
    {:noreply, %{state | series: append(state.series, index, point)}}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply, materialise(state.series), state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:stop, :shutdown, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    Enum.each(state.events, &:telemetry.detach(handler_id(&1)))
  end

  # Points accumulate newest-first so trimming is a slice off the tail rather
  # than a walk of the whole buffer on every single event.
  defp append(series, index, {label, _value, _time} = point) do
    Map.update(series, {index, label}, [point], fn points ->
      Enum.take([point | points], @buffer_size)
    end)
  end

  defp materialise(series) do
    series
    |> Enum.group_by(fn {{index, _label}, _points} -> index end)
    |> Map.new(fn {index, entries} ->
      {index,
       Enum.map(entries, fn {{_index, label}, points} ->
         %{label: label, points: Enum.reverse(points)}
       end)}
    end)
  end

  # Scoped to this process so two open windows never share or detach each
  # other's handlers.
  defp handler_id(event), do: {__MODULE__, self(), event}
end
