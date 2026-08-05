defmodule RetroHexChatWeb.Components.UI.System.MetricsPanel do
  @moduledoc """
  Live charts for one group of telemetry metrics.

  Metrics are grouped the way the `Telemetry` module declares them — HTTP,
  LiveView, Database, VM, Domain — because those groups are the questions an
  operator actually has. Only one group is charted at a time: each open chart
  costs a live telemetry subscription, and a screen of forty of them would make
  the window the most expensive thing on the node.

  Charts start empty and fill as events arrive. That is a property of live
  telemetry, not a fault: nothing was measured before the window opened, and
  drawing a flat line back to the left edge would invent history.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :groups, :list, default: []
  attr :group, :string, default: nil
  attr :charts, :list, default: [], doc: "One entry per metric in the selected group"
  attr :target, :any, default: nil
  attr :on_select_group, :string, required: true
  attr :testid, :string, default: "system-metrics"

  @spec metrics_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def metrics_panel(assigns) do
    ~H"""
    <div
      id={"#{@id}-metrics"}
      class="adm-dialog flex h-full min-h-0 flex-col gap-retro-8"
      data-testid={@testid}
    >
      <h3 class="flex min-w-0 shrink-0 items-center gap-1 text-xs font-bold">
        <Icons.icon_chart_bars class="h-4 w-4 shrink-0" />
        <span class="min-w-0 flex-1 truncate">{dgettext("dialogs", "Live metrics")}</span>
        <span class="shrink-0 font-normal text-muted-foreground">
          {dgettext("dialogs", "%{count} charts", count: length(@charts))}
        </span>
      </h3>

      <nav
        class="flex shrink-0 flex-wrap gap-retro-4"
        aria-label={dgettext("dialogs", "Metric groups")}
      >
        <button
          :for={group <- @groups}
          type="button"
          class={[
            "px-retro-8 py-retro-2 text-xs shadow-retro-raised active:shadow-retro-sunken",
            group == @group && "font-bold shadow-retro-sunken"
          ]}
          phx-click={@on_select_group}
          phx-target={@target}
          phx-value-group={group}
          aria-pressed={to_string(group == @group)}
          data-testid={"system-metrics-group-#{group}"}
        >
          {group}
        </button>
      </nav>

      <div class="retro-scrollbar min-h-0 flex-1 overflow-y-auto">
        <p
          :if={@charts == []}
          class="bg-white p-2 text-xs shadow-retro-sunken"
          data-testid="system-metrics-empty"
        >
          {dgettext("dialogs", "This group declares no metrics.")}
        </p>

        <div class="grid grid-cols-1 gap-retro-6 lg:grid-cols-2">
          <.metric_chart :for={chart <- @charts} chart={chart} />
        </div>
      </div>
    </div>
    """
  end

  attr :chart, :map, required: true

  defp metric_chart(assigns) do
    ~H"""
    <figure
      class="min-w-0 border border-border bg-surface p-2 shadow-retro-sunken"
      data-testid={"system-metrics-chart-#{@chart.id}"}
    >
      <figcaption class="mb-1 min-w-0">
        <span class="block truncate text-[11px] font-bold" title={@chart.full_title}>
          {@chart.title}
        </span>
        <span :if={@chart.description} class="block truncate text-[10px] text-muted-foreground">
          {@chart.description}
        </span>
      </figcaption>

      <div
        id={"metric-chart-#{@chart.id}"}
        class="system-metric-chart h-[120px] w-full"
        phx-hook="MetricChartHook"
        phx-update="ignore"
        data-metric-id={@chart.id}
      >
        <canvas class="block h-full w-full"></canvas>
      </div>

      <p class="mt-1 truncate text-[10px] text-muted-foreground">
        {@chart.unit}
      </p>
    </figure>
    """
  end
end
