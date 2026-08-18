import { afterEach, describe, expect, it, vi } from "vitest";

import {
  createMetricChart,
  drawChart,
  formatAxisValue,
  readChartPalette,
  seriesBounds,
} from "../../../js/lib/system/metric_chart.js";

describe("seriesBounds", () => {
  it("is null when there are no points", () => {
    expect(seriesBounds([])).toBeNull();
    expect(seriesBounds([{ points: [] }])).toBeNull();
  });

  it("spans the min and max across every series", () => {
    const b = seriesBounds([
      {
        points: [
          [0, 5],
          [1, 9],
        ],
      },
      {
        points: [
          [0, 2],
          [1, 7],
        ],
      },
    ]);
    expect(b.min).toBe(2);
    expect(b.max).toBe(9);
  });

  it("reports the longest series length as the count", () => {
    const b = seriesBounds([
      { points: [[0, 1]] },
      {
        points: [
          [0, 1],
          [1, 2],
          [2, 3],
        ],
      },
    ]);
    expect(b.count).toBe(3);
  });

  it("pads a flat line so it sits mid-plot", () => {
    const b = seriesBounds([
      {
        points: [
          [0, 4],
          [1, 4],
        ],
      },
    ]);
    expect(b.min).toBeLessThan(4);
    expect(b.max).toBeGreaterThan(4);
  });
});

describe("formatAxisValue", () => {
  it("abbreviates millions and thousands", () => {
    expect(formatAxisValue(2_500_000)).toBe("2.5M");
    expect(formatAxisValue(1500)).toBe("1.5k");
  });

  it("drops decimals for mid values and keeps them for small ones", () => {
    expect(formatAxisValue(42)).toBe("42");
    expect(formatAxisValue(3.14159)).toBe("3.14");
  });
});

describe("readChartPalette", () => {
  it("reads the CSS custom properties into a palette", () => {
    const style = {
      getPropertyValue: (name) =>
        ({
          "--chart-plot-bg": " #000 ",
          "--chart-grid": "#111",
          "--chart-axis": "#222",
          "--chart-series-1": "#a",
          "--chart-series-6": "#f",
        })[name] || "",
    };
    const palette = readChartPalette(style);
    expect(palette.plotBg).toBe("#000");
    expect(palette.series).toHaveLength(6);
    expect(palette.series[0]).toBe("#a");
    expect(palette.series[5]).toBe("#f");
  });
});

function recordingCtx() {
  const calls = [];
  const ctx = {
    canvas: { height: 200 },
    setTransform: () => {},
    clearRect: (...a) => calls.push(["clearRect", ...a]),
    fillRect: (...a) => calls.push(["fillRect", ...a]),
    strokeRect: () => {},
    beginPath: () => {},
    moveTo: () => {},
    lineTo: () => {},
    stroke: () => calls.push(["stroke"]),
    fillText: (...a) => calls.push(["fillText", ...a]),
    set fillStyle(v) {},
    set strokeStyle(v) {},
    set lineWidth(v) {},
    set lineJoin(v) {},
    set lineCap(v) {},
    set font(v) {},
    set textBaseline(v) {},
    set textAlign(v) {},
  };
  return { ctx, calls };
}

const palette = { plotBg: "#000", grid: "#111", axis: "#222", series: ["#a", "#b"] };

describe("drawChart", () => {
  it("fills the plot background and clears once", () => {
    const { ctx, calls } = recordingCtx();
    drawChart(ctx, { series: [], bounds: null, palette, width: 100, height: 50 });
    expect(calls.some((c) => c[0] === "clearRect")).toBe(true);
    expect(calls.some((c) => c[0] === "fillRect")).toBe(true);
  });

  it("strokes a line for a multi-point series", () => {
    const { ctx, calls } = recordingCtx();
    const series = [
      {
        points: [
          [0, 1],
          [1, 5],
          [2, 3],
        ],
      },
    ];
    drawChart(ctx, { series, bounds: seriesBounds(series), palette, width: 100, height: 50 });
    expect(calls.filter((c) => c[0] === "stroke").length).toBeGreaterThan(0);
  });

  it("marks a single reading with a rect instead of a line", () => {
    const { ctx, calls } = recordingCtx();
    const series = [{ points: [[0, 4]] }];
    drawChart(ctx, { series, bounds: seriesBounds(series), palette, width: 100, height: 50 });
    expect(calls.filter((c) => c[0] === "fillRect").length).toBeGreaterThanOrEqual(2);
  });
});

describe("createMetricChart controller", () => {
  afterEach(() => vi.restoreAllMocks());

  function fakeChartEl() {
    const { ctx } = recordingCtx();
    const canvas = { width: 0, height: 0, getContext: () => ctx };
    return {
      clientWidth: 200,
      clientHeight: 100,
      querySelector: (sel) => (sel === "canvas" ? canvas : null),
      canvas,
    };
  }

  const style = { getPropertyValue: () => "#000" };

  it("mounts, observes and draws", () => {
    const el = fakeChartEl();
    const observe = vi.fn();
    const disconnect = vi.fn();
    const chart = createMetricChart(el, {
      getComputedStyle: () => style,
      ResizeObserverImpl: class {
        observe = observe;
        disconnect = disconnect;
      },
    });

    chart.mount();
    expect(observe).toHaveBeenCalledWith(el);
    expect(el.canvas.width).toBeGreaterThan(0);

    chart.destroy();
    expect(disconnect).toHaveBeenCalledTimes(1);
  });

  it("setSeries redraws with the new data and tolerates non-arrays", () => {
    const el = fakeChartEl();
    const chart = createMetricChart(el, {
      getComputedStyle: () => style,
      ResizeObserverImpl: class {
        observe() {}
        disconnect() {}
      },
    });
    chart.mount();

    expect(() =>
      chart.setSeries([
        {
          points: [
            [0, 1],
            [1, 2],
          ],
        },
      ]),
    ).not.toThrow();
    expect(() => chart.setSeries(null)).not.toThrow();
  });

  it("skips drawing when the element has no size", () => {
    const el = fakeChartEl();
    el.clientWidth = 0;
    const chart = createMetricChart(el, {
      getComputedStyle: () => style,
      ResizeObserverImpl: class {
        observe() {}
        disconnect() {}
      },
    });
    chart.mount();
    expect(el.canvas.width).toBe(0);
  });
});
