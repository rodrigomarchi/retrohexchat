/**
 * Draws a metric's recent history as a retro line chart on a canvas.
 *
 * Written by hand rather than pulled from a charting library for one reason:
 * every other surface in this product is hard-edged, unantialiased, and drawn
 * from the same six colours. A modern chart library would look imported, and
 * taming one into this aesthetic is more work than the ~150 lines below.
 *
 * The server owns the data and pushes whole series; this hook owns only the
 * drawing. That split means a redraw needs no round trip — a resize repaints
 * from the series already held here.
 */

const GRID_ROWS = 4;
const SERIES_SLOTS = 6;

/**
 * Read the palette out of CSS rather than hardcoding it here.
 *
 * A canvas cannot be styled by class, but that is no reason for the colours to
 * live in JavaScript: they are declared on `.system-metric-chart` alongside
 * every other colour in the product, and read back once at mount.
 */
function readPalette(el) {
  const style = getComputedStyle(el);
  // No fallbacks: the stylesheet is the only source for these, and a colour
  // hardcoded here as a "safety net" would be a second definition that nobody
  // updates when the palette changes. A canvas ignores an empty fillStyle and
  // keeps its previous one, so a missing property degrades rather than throws.
  const value = (name) => style.getPropertyValue(name).trim();

  return {
    plotBg: value("--chart-plot-bg"),
    grid: value("--chart-grid"),
    axis: value("--chart-axis"),
    series: Array.from({ length: SERIES_SLOTS }, (_, index) =>
      value(`--chart-series-${index + 1}`),
    ),
  };
}

export const MetricChartHook = {
  mounted() {
    this.series = [];
    this.palette = readPalette(this.el);
    this.observer = new ResizeObserver(() => this.draw());
    this.observer.observe(this.el);

    // One event carries every chart's series, and each instance keeps the one
    // addressed to it. A per-chart event name would be dynamic, which the lazy
    // hook facade cannot declare ahead of time — and the server would have to
    // push once per chart instead of once per refresh.
    this.handleEvent("system_metric_series", ({ charts }) => {
      const mine = charts?.[this.el.dataset.metricId];
      if (mine === undefined) return;

      this.series = Array.isArray(mine) ? mine : [];
      this.draw();
    });

    this.draw();

    // This hook is loaded lazily, so it can mount after the server has already
    // pushed a refresh. Announcing readiness makes the server send the current
    // snapshot straight away instead of leaving the chart blank until the next
    // tick — and is what the lazy-hook contract requires of any hook that
    // handles server events.
    this.pushEvent("metric_chart_ready", { metric_id: this.el.dataset.metricId });
  },

  destroyed() {
    this.observer?.disconnect();
  },

  /**
   * Repaint from whatever series are currently held.
   *
   * The canvas backing store is sized in device pixels and scaled, or the
   * lines blur on a retina display — which would undo the whole point of a
   * crisp-edged chart.
   */
  draw() {
    const canvas = this.el.querySelector("canvas");
    if (!canvas) return;

    const ratio = window.devicePixelRatio || 1;
    const width = this.el.clientWidth;
    const height = this.el.clientHeight;
    if (width === 0 || height === 0) return;

    // Only the backing store is sized here. The canvas' displayed size is
    // already handled by its classes, so setting it again from JavaScript
    // would put a second source of truth for layout into the hook.
    canvas.width = Math.floor(width * ratio);
    canvas.height = Math.floor(height * ratio);

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    ctx.clearRect(0, 0, width, height);

    const bounds = this.bounds();
    this.drawPlotArea(ctx, width, height, bounds);

    if (bounds) {
      this.series.forEach((line, index) => {
        this.drawSeries(ctx, line, index, width, height, bounds);
      });
    }
  },

  /**
   * The value range across every series, padded so a flat line sits mid-plot
   * instead of being drawn along the very bottom edge.
   *
   * Returns null when there is nothing to draw, which the caller renders as an
   * empty plot rather than as a chart of zeroes.
   */
  bounds() {
    const values = this.series.flatMap((line) => (line.points || []).map((point) => point[1]));
    if (values.length === 0) return null;

    let min = Math.min(...values);
    let max = Math.max(...values);

    if (min === max) {
      const pad = Math.abs(min) || 1;
      min -= pad / 2;
      max += pad / 2;
    }

    return { min, max, count: Math.max(...this.series.map((l) => (l.points || []).length)) };
  },

  drawPlotArea(ctx, width, height, bounds) {
    ctx.fillStyle = this.palette.plotBg;
    ctx.fillRect(0, 0, width, height);

    // Horizontal rules only: the x axis is "recent", not a measured scale, so
    // vertical rules would imply a precision the series does not carry.
    ctx.strokeStyle = this.palette.grid;
    ctx.lineWidth = 1;
    for (let row = 1; row < GRID_ROWS; row += 1) {
      const y = Math.round((height / GRID_ROWS) * row) + 0.5;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();
    }

    ctx.strokeStyle = this.palette.axis;
    ctx.strokeRect(0.5, 0.5, width - 1, height - 1);

    if (bounds) {
      this.drawScale(ctx, width, bounds);
    }
  },

  drawScale(ctx, width, bounds) {
    ctx.fillStyle = this.palette.axis;
    ctx.font = '10px "Source Code Pro", monospace';
    ctx.textBaseline = "top";
    ctx.fillText(format(bounds.max), 3, 3);
    ctx.textBaseline = "bottom";
    ctx.fillText(format(bounds.min), 3, ctx.canvas.height / (window.devicePixelRatio || 1) - 3);
    ctx.textAlign = "right";
    ctx.textBaseline = "top";
    ctx.fillText(`${bounds.count}`, width - 3, 3);
    ctx.textAlign = "left";
  },

  drawSeries(ctx, line, index, width, height, bounds) {
    const points = line.points || [];
    if (points.length === 0) return;

    const span = bounds.max - bounds.min || 1;
    const step = points.length > 1 ? width / (points.length - 1) : 0;

    ctx.strokeStyle = this.palette.series[index % this.palette.series.length];
    ctx.lineWidth = 1.5;
    ctx.lineJoin = "miter";
    ctx.lineCap = "butt";
    ctx.beginPath();

    points.forEach((point, position) => {
      const x = points.length > 1 ? position * step : width / 2;
      const y = height - ((point[1] - bounds.min) / span) * height;
      if (position === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    });

    ctx.stroke();

    // A single reading has no line to draw, so it is marked instead — an
    // empty plot would otherwise claim nothing had been measured.
    if (points.length === 1) {
      const y = height - ((points[0][1] - bounds.min) / span) * height;
      ctx.fillStyle = this.palette.series[index % this.palette.series.length];
      ctx.fillRect(width / 2 - 2, y - 2, 4, 4);
    }
  },
};

/** Compact enough for an axis corner: 1.2k rather than 1234.56. */
function format(value) {
  const abs = Math.abs(value);
  if (abs >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M`;
  if (abs >= 1_000) return `${(value / 1_000).toFixed(1)}k`;
  if (abs >= 10) return value.toFixed(0);
  return value.toFixed(2);
}

export default MetricChartHook;
