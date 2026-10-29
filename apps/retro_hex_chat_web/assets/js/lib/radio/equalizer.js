/**
 * Hex Radio's equaliser: ten peaking filters in a row, one per band, each
 * raised or lowered by up to twelve decibels. The bands are the server's
 * (`Components.UI.Radio.bands/0`), read from the sliders' order.
 *
 * Only a station that shares its sound with the page can pass through it:
 * the browser keeps the samples of any other stream out of the page.
 *
 * @module radio/equalizer
 */

/** The bands, in hertz, in the sliders' order. */
export const BANDS = [60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000];

/** How far a band moves, in decibels, either way. */
export const MAX_GAIN = 12;

/** A slider's value as a gain the filter accepts. */
export function gainFor(value) {
  const gain = Number(value);
  if (!Number.isFinite(gain)) return 0;
  return Math.max(-MAX_GAIN, Math.min(MAX_GAIN, Math.round(gain)));
}

/** A preamp slider's decibels as the gain a GainNode multiplies by. */
export function preampGain(decibels) {
  return 10 ** (gainFor(decibels) / 20);
}

/**
 * The filters, connected in order, for `context`.
 *
 * @param {BaseAudioContext} context
 * @returns {{input: AudioNode, output: AudioNode, set: (band: number, value: number) => void, flat: () => void}}
 */
export function createEqualizer(context) {
  const filters = BANDS.map((frequency, index) => {
    const filter = context.createBiquadFilter();
    // The ends shelve, as a player's outer bands do; the rest peak.
    filter.type = index === 0 ? "lowshelf" : index === BANDS.length - 1 ? "highshelf" : "peaking";
    filter.frequency.value = frequency;
    filter.Q.value = 1.1;
    filter.gain.value = 0;
    return filter;
  });
  filters.reduce((previous, next) => (previous.connect(next), next));

  return {
    input: filters[0],
    output: filters[filters.length - 1],
    set(band, value) {
      const filter = filters[band];
      if (filter) filter.gain.value = gainFor(value);
    },
    flat() {
      for (const filter of filters) filter.gain.value = 0;
    },
  };
}
