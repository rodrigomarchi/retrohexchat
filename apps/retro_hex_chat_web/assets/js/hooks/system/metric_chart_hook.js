/**
 * LiveView binding for a metric's history chart.
 *
 * All drawing lives in `lib/system/metric_chart.js`, which knows nothing about
 * LiveView. This hook feeds the controller the series the server pushes and
 * announces readiness so a lazily-mounted chart gets the current snapshot at
 * once instead of waiting for the next refresh.
 */
import { createMetricChart } from "../../lib/system/metric_chart.js";

export function createMetricChartHook({ chartFactory = createMetricChart } = {}) {
  return {
    mounted() {
      this.chart = chartFactory(this.el);
      this.chart.mount();

      // One event carries every chart's series; each instance keeps the one
      // addressed to it. A per-chart event name would be dynamic, which the
      // lazy-hook facade cannot declare ahead of time.
      this.handleEvent("system_metric_series", ({ charts }) => {
        const mine = charts?.[this.el.dataset.metricId];
        if (mine === undefined) return;
        this.chart.setSeries(mine);
      });

      this.pushEvent("metric_chart_ready", { metric_id: this.el.dataset.metricId });
    },

    destroyed() {
      this.chart.destroy();
    },
  };
}

export default createMetricChartHook();
