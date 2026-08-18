/**
 * A hand-drawn retro line chart for a metric's recent history.
 *
 * Written by hand rather than pulled from a charting library for one reason:
 * every other surface in this product is hard-edged, unantialiased, and drawn
 * from the same six colours. A modern chart library would look imported.
 *
 * This module has two halves. The pure drawing functions know only a canvas
 * context and plain numbers, so they are tested without a DOM. `createMetricChart`
 * is the controller that owns the canvas sizing, the palette read and the
 * ResizeObserver; the hook binds it and feeds it server-pushed series.
 *
 * @module system/metric_chart
 */

const GRID_ROWS = 4;
const SERIES_SLOTS = 6;

/**
 * The value range across every series, padded so a flat line sits mid-plot
 * instead of along the bottom edge. Null when there is nothing to draw.
 *
 * @param {Array<{points?: Array<[number, number]>}>} series
 * @returns {{min: number, max: number, count: number}|null}
 */
export function seriesBounds(series) {
  const values = series.flatMap((line) => (line.points || []).map((point) => point[1]));
  if (values.length === 0) return null;

  let min = Math.min(...values);
  let max = Math.max(...values);

  if (min === max) {
    const pad = Math.abs(min) || 1;
    min -= pad / 2;
    max += pad / 2;
  }

  return { min, max, count: Math.max(...series.map((line) => (line.points || []).length)) };
}

/** Compact enough for an axis corner: 1.2k rather than 1234.56. */
export function formatAxisValue(value) {
  const abs = Math.abs(value);
  if (abs >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M`;
  if (abs >= 1_000) return `${(value / 1_000).toFixed(1)}k`;
  if (abs >= 10) return value.toFixed(0);
  return value.toFixed(2);
}

/**
 * Read the chart palette from a computed style.
 *
 * The colours are declared on `.system-metric-chart` in CSS alongside every
 * other colour in the product; a canvas cannot be styled by class, so they are
 * read back here. No fallbacks: a missing property leaves the canvas' previous
 * fill rather than introducing a second definition nobody maintains.
 *
 * @param {CSSStyleDeclaration} style
 * @returns {{plotBg: string, grid: string, axis: string, series: string[]}}
 */
export function readChartPalette(style) {
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

/**
 * Paint the whole chart into a context already scaled to CSS pixels.
 *
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} params
 * @param {Array<{points?: Array<[number, number]>}>} params.series
 * @param {{min: number, max: number, count: number}|null} params.bounds
 * @param {{plotBg: string, grid: string, axis: string, series: string[]}} params.palette
 * @param {number} params.width css pixels
 * @param {number} params.height css pixels
 * @param {number} [params.devicePixelRatio]
 */
export function drawChart(ctx, { series, bounds, palette, width, height, devicePixelRatio = 1 }) {
  ctx.clearRect(0, 0, width, height);
  drawPlotArea(ctx, width, height, bounds, palette, devicePixelRatio);

  if (bounds) {
    series.forEach((line, index) => drawSeries(ctx, line, index, width, height, bounds, palette));
  }
}

function drawPlotArea(ctx, width, height, bounds, palette, devicePixelRatio) {
  ctx.fillStyle = palette.plotBg;
  ctx.fillRect(0, 0, width, height);

  // Horizontal rules only: the x axis is "recent", not a measured scale.
  ctx.strokeStyle = palette.grid;
  ctx.lineWidth = 1;
  for (let row = 1; row < GRID_ROWS; row += 1) {
    const y = Math.round((height / GRID_ROWS) * row) + 0.5;
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(width, y);
    ctx.stroke();
  }

  ctx.strokeStyle = palette.axis;
  ctx.strokeRect(0.5, 0.5, width - 1, height - 1);

  if (bounds) drawScale(ctx, width, bounds, palette, devicePixelRatio);
}

function drawScale(ctx, width, bounds, palette, devicePixelRatio) {
  ctx.fillStyle = palette.axis;
  ctx.font = '10px "Source Code Pro", monospace';
  ctx.textBaseline = "top";
  ctx.fillText(formatAxisValue(bounds.max), 3, 3);
  ctx.textBaseline = "bottom";
  ctx.fillText(formatAxisValue(bounds.min), 3, ctx.canvas.height / devicePixelRatio - 3);
  ctx.textAlign = "right";
  ctx.textBaseline = "top";
  ctx.fillText(`${bounds.count}`, width - 3, 3);
  ctx.textAlign = "left";
}

function drawSeries(ctx, line, index, width, height, bounds, palette) {
  const points = line.points || [];
  if (points.length === 0) return;

  const span = bounds.max - bounds.min || 1;
  const step = points.length > 1 ? width / (points.length - 1) : 0;
  const colour = palette.series[index % palette.series.length];

  ctx.strokeStyle = colour;
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

  // A single reading has no line to draw, so it is marked instead.
  if (points.length === 1) {
    const y = height - ((points[0][1] - bounds.min) / span) * height;
    ctx.fillStyle = colour;
    ctx.fillRect(width / 2 - 2, y - 2, 4, 4);
  }
}

/**
 * The controller: owns the canvas backing store, the palette and the resize
 * observer. Knows nothing about LiveView — the hook feeds it series.
 *
 * @param {HTMLElement} el the `.system-metric-chart` element
 * @param {object} [deps]
 * @param {(el: Element) => CSSStyleDeclaration} [deps.getComputedStyle]
 * @param {typeof ResizeObserver} [deps.ResizeObserverImpl]
 * @returns {{mount(): void, setSeries(series: unknown): void, draw(): void, destroy(): void}}
 */
export function createMetricChart(el, deps = {}) {
  const readStyle = deps.getComputedStyle || ((node) => window.getComputedStyle(node));
  const RO =
    deps.ResizeObserverImpl || (typeof ResizeObserver !== "undefined" ? ResizeObserver : null);

  let series = [];
  let palette = null;
  let observer = null;

  const chart = {
    mount() {
      palette = readChartPalette(readStyle(el));
      if (RO) {
        observer = new RO(() => this.draw());
        observer.observe(el);
      }
      this.draw();
    },

    setSeries(next) {
      series = Array.isArray(next) ? next : [];
      this.draw();
    },

    draw() {
      const canvas = el.querySelector("canvas");
      if (!canvas) return;

      const ratio = window.devicePixelRatio || 1;
      const width = el.clientWidth;
      const height = el.clientHeight;
      if (width === 0 || height === 0) return;

      // Only the backing store is sized here; the displayed size is CSS-owned.
      canvas.width = Math.floor(width * ratio);
      canvas.height = Math.floor(height * ratio);

      const ctx = canvas.getContext("2d");
      if (!ctx) return;

      ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
      drawChart(ctx, {
        series,
        bounds: seriesBounds(series),
        palette,
        width,
        height,
        devicePixelRatio: ratio,
      });
    },

    destroy() {
      observer?.disconnect();
      observer = null;
    },
  };

  return chart;
}
