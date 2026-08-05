defmodule RetroHexChatWeb.ChatLive.Components.SystemMetricsDialog do
  @moduledoc """
  Stateful island behind the Metrics window.

  Owns the lifecycle of one `SystemMetrics.Collector`: started when a group is
  chosen, replaced when the choice changes, and taken down with the LiveView
  it is linked to. Only the selected group is ever subscribed, so the number of
  live telemetry handlers is bounded by what is on screen rather than by the
  size of the metric catalogue.

  The series reach the browser on a timer rather than per event. The collector
  already absorbs the event rate; this decides how often the picture is worth
  redrawing, which is a question about eyes rather than about the server.

  Charts are addressed by index within the group, because a metric's event name
  is not unique — `phoenix.endpoint.stop.duration` can be declared twice with
  different tags, and both are legitimately different charts.
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.System.MetricsPanel

  alias RetroHexChatWeb.ChatLive.AdminOps
  alias RetroHexChatWeb.SystemMetrics.Collector
  alias RetroHexChatWeb.Telemetry

  @id "system-metrics-dialog"
  @refresh_ms 1_000

  @spec id() :: String.t()
  def id, do: @id

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(:id, @id)
     |> assign(groups: [], group: nil, charts: [], collector: nil, timer: nil)}
  end

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{tick: true}, socket) do
    {:ok, socket |> push_series() |> schedule()}
  end

  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if socket.assigns.groups == [] do
      grouped = grouped_metrics()
      groups = Map.keys(grouped)

      {:ok, socket |> assign(groups: groups, grouped: grouped) |> select(List.first(groups))}
    else
      {:ok, socket}
    end
  end

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  @doc """
  Answers a chart that has just finished loading with the current snapshot.

  The chart renderer is a lazily loaded hook, so it can mount a beat after the
  window does — and after a refresh has already gone out. Without this it would
  sit blank until the next tick.
  """
  def handle_event("metric_chart_ready", _params, socket) do
    {:noreply, push_series(socket)}
  end

  def handle_event("system_metrics_select_group", %{"group" => group}, socket) do
    cond do
      not AdminOps.admin?(socket) ->
        {:noreply, AdminOps.error_event(socket, AdminOps.restricted_message())}

      group not in socket.assigns.groups ->
        {:noreply, socket}

      true ->
        {:noreply, select(socket, group)}
    end
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.metrics_panel
        id={@id}
        groups={@groups}
        group={@group}
        charts={@charts}
        target={@myself}
        on_select_group="system_metrics_select_group"
      />
    </div>
    """
  end

  # Switching groups tears the previous subscription down before installing the
  # next, so an operator flipping between tabs never accumulates collectors.
  defp select(socket, nil), do: socket

  defp select(socket, group) do
    stop_collector(socket.assigns.collector)

    metrics = Map.fetch!(socket.assigns.grouped, group)
    {:ok, collector} = Collector.start(metrics)

    socket
    |> assign(group: group, collector: collector, charts: charts(metrics))
    |> push_event("system_metric_series", %{charts: %{}})
    |> schedule()
  end

  defp stop_collector(nil), do: :ok

  defp stop_collector(collector) do
    if Process.alive?(collector), do: GenServer.stop(collector, :normal)
    :ok
  end

  # The tick is delivered through the host's window-update path, which is the
  # only way a LiveComponent can be woken by a timer: it owns no process, so
  # the message has to land in the LiveView and be routed back here.
  defp schedule(socket) do
    if socket.assigns.timer, do: Process.cancel_timer(socket.assigns.timer)

    # The id has to travel with the tick: `send_update/2` addresses a component
    # by it, and without one the host's forwarding raises rather than waking
    # this island.
    timer =
      Process.send_after(
        self(),
        {:window_send_update, __MODULE__, [id: @id, tick: true]},
        @refresh_ms
      )

    assign(socket, timer: timer)
  end

  defp push_series(%{assigns: %{collector: nil}} = socket), do: socket

  defp push_series(%{assigns: %{collector: collector}} = socket) do
    series =
      collector
      |> Collector.snapshot()
      |> Map.new(fn {index, lines} -> {to_string(index), Enum.map(lines, &encode/1)} end)

    push_event(socket, "system_metric_series", %{charts: series})
  end

  # Points travel as flat tuples rather than maps: a chart holds sixty of them
  # per series, and the key names would be most of the payload.
  defp encode(%{label: label, points: points}) do
    %{label: label, points: Enum.map(points, fn {_label, value, time} -> [time, value] end)}
  end

  defp grouped_metrics do
    Telemetry.metrics()
    |> Enum.group_by(&group_name/1)
    |> Map.new(fn {group, metrics} -> {group, metrics} end)
  end

  defp group_name(metric) do
    to_string(metric.reporter_options[:nav] || hd(metric.name))
  end

  defp charts(metrics) do
    metrics
    |> Enum.with_index()
    |> Enum.map(fn {metric, index} ->
      %{
        id: to_string(index),
        title: title(metric.name),
        full_title: Enum.join(metric.name, "."),
        description: metric.description,
        unit: unit_label(metric)
      }
    end)
  end

  # Every metric this application declares is prefixed with its own name, so
  # the prefix distinguishes nothing and costs the width that the rest of the
  # name needs. The full event name stays available on hover.
  defp title([:retro_hex_chat | rest]) when rest != [], do: Enum.join(rest, ".")
  defp title(name), do: Enum.join(name, ".")

  defp unit_label(%{unit: :unit}), do: ""
  defp unit_label(%{unit: {_from, to}}), do: to_string(to)
  defp unit_label(%{unit: unit}), do: to_string(unit)
end
