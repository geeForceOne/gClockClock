// gClockClock card for Home Assistant dashboards (installed from the Marketplace, see docs/hacs.md):
//   type: custom:gclock-card
//   path: spin
//   hand: "#ff8800"
// Every clock setting is a config key with the same name and values as clock.html's URL options,
// plus `transparent` (the dashboard's card background instead of black). The clock itself is
// clock.js, which the Marketplace installs next to this file.

// Load clock.js from next to this file, with the same query (the installed version) so the two match.
if (!window.gClockClock) {
  const here = new URL(import.meta.url);
  await new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = new URL('clock.js' + here.search, here).href;
    script.onload = resolve;
    script.onerror = () => reject(new Error('gClockClock: clock.js is missing next to gClockClock.js'));
    document.head.append(script);
  });
}

const TIME_KEYS = ['path', 'easing', 'wave', 'magnet', 'faces', 'duration'];
const COLOR_KEYS = ['face', 'hand', 'rim'];
const LABELS = {
  path: 'Path', easing: 'Easing', wave: 'Wave', magnet: 'Magnet', faces: 'Faces', duration: 'Duration',
  face: 'Face color', clear: 'No face color', hand: 'Hand color', rim: 'Rim color', fade: 'Fade rims',
  gap: 'Spacing', transparent: 'Transparent background', crazy: 'How often', show: 'Show',
};
// The visual editor's color picker stores [r, g, b]; YAML may also say "#ff8800".
const toHex = v => Array.isArray(v) ? '#' + v.map(n => Math.round(n).toString(16).padStart(2, '0')).join('') : v;
const toRgb = hex => [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16));

class GClockCard extends HTMLElement {
  setConfig(config) {
    if (!config || typeof config !== 'object') throw new Error('gClockClock: invalid configuration');
    const old = this.config;
    this.config = config;
    if (this.clock) this.apply(old);
    else this.start();
  }

  set hass(hass) {} // the clock needs no entities

  connectedCallback() {
    clearTimeout(this.stopTimer);
    if (!this.clock) this.start();
  }

  // Home Assistant detaches cards while another view shows; stop only if the card stays away.
  disconnectedCallback() {
    this.stopTimer = setTimeout(() => {
      this.clock?.stop();
      this.clock = null;
    }, 60000);
  }

  values() {
    const values = {};
    for (const [key, value] of Object.entries(this.config)) values[key] = COLOR_KEYS.includes(key) ? toHex(value) : value;
    return values;
  }

  start() {
    if (!this.config || !this.isConnected) return;
    if (!this.shadowRoot) {
      this.attachShadow({ mode: 'open' }).innerHTML = `<style>
        :host { display: block; }
        ha-card { overflow: hidden; }
        /* the clock's 8:3 shape; a smaller edge than the full-window page */
        .stage.gclock { aspect-ratio: 8 / 3; --pad: 8px; }
      </style><ha-card></ha-card>`;
    }
    const stage = document.createElement('div');
    stage.className = 'stage';
    this.shadowRoot.querySelector('ha-card').replaceChildren(stage);
    this.clock = window.gClockClock(stage, { settings: this.values(), transparent: !!this.config.transparent });
    this.stage = stage;
  }

  // A changed config (the visual editor): like clock.html's options, a changed show plays it and a
  // changed time-change setting previews it.
  apply(old) {
    const { clock } = this;
    clock.set({ ...clock.defaults, ...this.values() });
    this.stage.classList.toggle('transparent', !!this.config.transparent);
    const changed = key => JSON.stringify(old?.[key]) !== JSON.stringify(this.config[key]);
    if (changed('show') || (changed('crazy') && clock.settings.crazy !== 'off')) clock.goCrazy();
    else if (TIME_KEYS.some(changed)) clock.preview();
    else if (changed('rim') || changed('fade')) clock.busy(2); // show the rims, then fade again
  }

  getCardSize() { return 4; }

  getGridOptions() { return { columns: 12, min_columns: 6, rows: 'auto' }; }

  static getStubConfig() { return {}; }

  // Home Assistant's built-in editor; the lists come from clock.js's option tables.
  static getConfigForm() {
    const choices = window.gClockClock.choices();
    const defaults = window.gClockClock.defaults();
    const field = (name, selector) => ({
      name, selector,
      default: COLOR_KEYS.includes(name) ? toRgb(defaults[name]) : defaults[name] ?? false,
    });
    const pick = name => field(name, { select: { mode: 'dropdown',
      options: choices[name].map(({ id, name }) => ({ value: id, label: name })) } });
    const slider = (name, min, max, step, unit) =>
      field(name, { number: { min, max, step, mode: 'slider', unit_of_measurement: unit } });
    const color = name => field(name, { color_rgb: {} });
    const check = name => field(name, { boolean: {} });
    return {
      schema: [
        { type: 'expandable', name: 'time', title: 'Time change', flatten: true,
          schema: [pick('path'), pick('easing'), pick('wave'), pick('magnet'), pick('faces'), slider('duration', 2, 16, 1, 's')] },
        { type: 'expandable', name: 'look', title: 'Look', flatten: true,
          schema: [color('face'), check('clear'), color('hand'), color('rim'), check('fade'),
            slider('gap', 0, 24, 2, 'px'), check('transparent')] },
        { type: 'expandable', name: 'shows', title: 'Crazy shows', flatten: true,
          schema: [pick('crazy'), pick('show')] },
      ],
      computeLabel: s => LABELS[s.name] ?? s.name,
    };
  }
}

if (!customElements.get('gclock-card')) {
  customElements.define('gclock-card', GClockCard);
  window.customCards = window.customCards || [];
  window.customCards.push({
    type: 'gclock-card',
    name: 'gClockClock',
    description: '24 small analog clocks whose hands turn together to form the time.',
    preview: true,
    documentationURL: 'https://github.com/geeForceOne/gClockClock#home-assistant-dashboard',
  });
}
