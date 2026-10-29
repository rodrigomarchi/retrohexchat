/**
 * What the Hex devices draw on their displays — Hex Radio and the players of
 * the chat's sounds: a spectrum of bars with falling peaks, or the
 * oscilloscope's line.
 *
 * Real when the station shares its sound with the page (an analyser's
 * frequency and wave data); otherwise bars that move like music without
 * hearing it, because the browser keeps the samples of that stream out of
 * the page. The colours are the stylesheet's (`--device-*` on the canvas).
 *
 * @module hex_device/visualizer
 */

/** How many bars the spectrum draws. */
export const BAR_COUNT = 24;

/** How far a peak falls each frame, in the height of the display. */
const PEAK_FALL = 0.012;

/**
 * Frequency data (0–255 per bin) folded into `count` bars of 0–1, spread on
 * a logarithmic scale the way an ear hears them: the low bins are bars of
 * their own, the high ones share.
 */
export function spectrumBars(data, count = BAR_COUNT) {
  const length = data.length;
  const bars = new Array(count).fill(0);
  if (length === 0) return bars;
  for (let i = 0; i < count; i++) {
    const low = Math.min(length - 1, Math.floor(length ** (i / count)) - 1);
    const high = Math.max(low + 1, Math.min(length, Math.floor(length ** ((i + 1) / count))));
    let sum = 0;
    for (let bin = low; bin < high; bin++) sum += data[bin];
    bars[i] = sum / (high - low) / 255;
  }
  return bars;
}

/**
 * Bars that move like music at `time` (milliseconds) without hearing it:
 * each its own slow wave, all of them breathing on one beat.
 */
export function simulatedBars(time, count = BAR_COUNT) {
  const beat = 0.75 + 0.25 * Math.abs(Math.sin(time * 0.0042));
  return Array.from({ length: count }, (_value, i) => {
    const wave =
      0.45 +
      0.25 * Math.sin(time * 0.0031 * (1 + i * 0.11) + i * 1.3) +
      0.18 * Math.sin(time * 0.0097 + i * 2.1);
    // The low end carries more than the high, as music does.
    const tilt = 1 - (i / count) * 0.45;
    return Math.max(0.02, Math.min(1, wave * tilt * beat));
  });
}

/** Peaks that hold the highest bar and fall slowly back to it. */
export function fallPeaks(peaks, bars) {
  return bars.map((bar, i) => Math.max(bar, (peaks[i] ?? 0) - PEAK_FALL));
}

/** The oscilloscope's points for wave data (0–255, 128 silent) in a `width`×`height` box. */
export function scopePoints(data, width, height) {
  const length = data.length;
  if (length < 2) return [];
  return Array.from(data, (sample, i) => [(i / (length - 1)) * width, (sample / 255) * height]);
}

/** The display's colours, as the stylesheet sets them on the canvas. */
export function readColours(canvas) {
  const style = canvas.ownerDocument.defaultView.getComputedStyle(canvas);
  const read = (name) => style.getPropertyValue(name).trim();
  return {
    bar: read("--device-bar"),
    peak: read("--device-peak"),
    line: read("--device-line"),
    curve: read("--device-curve"),
    curveOff: read("--device-curve-off"),
  };
}

/**
 * Draws one frame on `canvas`: the bars with their peaks, or the line.
 *
 * @param {HTMLCanvasElement} canvas
 * @param {{kind: "spectrum" | "scope", bars?: number[], peaks?: number[], points?: number[][]}} frame
 * @param {{bar: string, peak: string, line: string}} colours
 */
export function drawFrame(canvas, frame, colours) {
  const context = canvas.getContext("2d");
  if (!context) return;
  const { width, height } = canvas;
  context.clearRect(0, 0, width, height);

  if (frame.kind === "scope") {
    context.strokeStyle = colours.line;
    context.lineWidth = Math.max(1, Math.round(height / 40));
    context.beginPath();
    (frame.points ?? []).forEach(([x, y], i) =>
      i === 0 ? context.moveTo(x, y) : context.lineTo(x, y),
    );
    context.stroke();
    return;
  }

  const bars = frame.bars ?? [];
  const slot = width / Math.max(1, bars.length);
  const barWidth = Math.max(1, Math.floor(slot) - 1);
  bars.forEach((bar, i) => {
    const x = Math.floor(i * slot);
    const barHeight = Math.round(bar * height);
    context.fillStyle = colours.bar;
    context.fillRect(x, height - barHeight, barWidth, barHeight);
    const peak = frame.peaks?.[i];
    if (peak !== undefined) {
      context.fillStyle = colours.peak;
      context.fillRect(x, height - Math.round(peak * height) - 2, barWidth, 2);
    }
  });
}

/**
 * The equaliser's curve for `bands` (decibels, ±12) across a `width`×`height`
 * box: a point over each band, joined by straight lines, the middle flat.
 */
export function curvePoints(bands, width, height) {
  const count = bands.length;
  if (count === 0) return [];
  return bands.map((gain, i) => [
    count === 1 ? width / 2 : (i / (count - 1)) * width,
    height / 2 - (Math.max(-12, Math.min(12, gain)) / 12) * (height / 2 - 1),
  ]);
}

/** Draws the equaliser's curve on `canvas`, dimmed while the equaliser is off. */
export function drawCurve(canvas, bands, colours, on = true) {
  const context = canvas.getContext("2d");
  if (!context) return;
  const { width, height } = canvas;
  context.clearRect(0, 0, width, height);
  context.strokeStyle = on ? colours.curve : colours.curveOff;
  context.lineWidth = Math.max(1, Math.round(height / 16));
  context.beginPath();
  curvePoints(bands, width, height).forEach(([x, y], i) =>
    i === 0 ? context.moveTo(x, y) : context.lineTo(x, y),
  );
  context.stroke();
}
