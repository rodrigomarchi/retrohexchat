/**
 * The panels a Construct piece opens when somebody next to it presses E: a
 * sign's line (with a field to rewrite it, for whoever may), a board's topic
 * and pinned lines, a screen's newest picture, an arcade cabinet's games.
 *
 * The frame is the server-rendered `template[data-space-panel-template]`, and
 * every sentence comes from its `data-` attributes, already translated; the
 * panel's data (the `space_modal` payload) carries only facts. Building the
 * DOM is all this does: saving a sign and closing the panel go through the
 * injected ports.
 * @module space/construct/panels
 */

const PANELS = new Set(["sign", "board", "screen", "arcade"]);

/**
 * Draw a panel into the modal host.
 * @param {HTMLElement} root - the space shell holding the template
 * @param {HTMLElement} host - the `[data-space-modal]` element
 * @param {object} modal - the `space_modal` payload
 * @param {{save: (text: string, done: {ok: Function, error: (reason: string) => void}) => void, close: () => void, refusal: (reason: string) => string}} ports
 * @returns {boolean} whether the modal was a panel this module draws
 */
export function renderPanel(root, host, modal, { save, close, refusal }) {
  const template = root.querySelector("template[data-space-panel-template]");
  if (!template || !PANELS.has(modal?.kind)) return false;

  const say = (key, name) =>
    (template.getAttribute(`data-${key}`) ?? "").replace("%{name}", name ?? "");
  const content = template.content.cloneNode(true);
  const body = content.querySelector("[data-space-panel-body]");

  const title = content.querySelector("[data-space-panel-title]");
  if (title) title.textContent = say(`title-${modal.kind}`);
  content.querySelector("[data-space-panel-close]")?.addEventListener("click", () => close());

  const parts = BODIES[modal.kind](modal, say);
  body?.replaceChildren(...(parts.length > 0 ? parts : [line(say(`empty-${modal.kind}`), "note")]));

  if (modal.kind === "sign" && modal.can_edit === true) {
    signForm(content, modal, { save, close, refusal });
  }

  host.replaceChildren(...content.childNodes);
  host.querySelector("[data-space-panel-input]")?.focus();
  return true;
}

const BODIES = {
  sign: (modal) => (modal.text ? [line(modal.text, "sign")] : []),

  board: (modal, say) => {
    const parts = [];
    if (modal.topic) parts.push(line(say("topic"), "label"), line(modal.topic, "item"));
    const pins = Array.isArray(modal.pins) ? modal.pins : [];
    if (pins.length > 0) {
      parts.push(line(say("pinned"), "label"));
      for (const pin of pins) parts.push(line(`${pin.author}: ${pin.text}`, "item"));
    }
    return parts;
  },

  screen: (modal, say) => {
    const image = modal.image;
    if (!image?.url) return [];
    const img = document.createElement("img");
    img.src = image.url;
    img.alt = image.name ?? "";
    img.className = "space-panel-image";
    img.dataset.testid = "space-panel-image";
    return [img, line(say("posted-by", image.author), "note")];
  },

  arcade: (modal, say) => {
    const games = Array.isArray(modal.games) ? modal.games : [];
    if (games.length === 0) return [];
    const list = document.createElement("ul");
    list.className = "space-panel-games";
    for (const game of games) {
      const link = document.createElement("a");
      link.href = game.url;
      link.target = "_blank";
      link.rel = "noopener";
      link.className = "space-panel-game";
      link.dataset.testid = `space-panel-game-${game.id}`;
      link.append(line(game.name, "game-name"), line(game.tagline ?? "", "note"));
      const item = document.createElement("li");
      item.appendChild(link);
      list.appendChild(item);
    }
    return [list, line(say("opens-in-tab"), "note")];
  },
};

// The field that rewrites a sign. Its keys stay in it: Enter saves the line
// rather than reaching the say bar below the map, which also binds Enter.
function signForm(content, modal, { save, close, refusal }) {
  const form = content.querySelector("[data-space-panel-sign]");
  const input = content.querySelector("[data-space-panel-input]");
  const status = content.querySelector("[data-space-panel-status]");
  if (!form || !input) return;

  form.hidden = false;
  input.value = modal.text ?? "";
  input.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") event.stopPropagation();
  });
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    save(input.value, {
      ok: () => close(),
      error: (reason) => {
        if (status) status.textContent = refusal(reason);
      },
    });
  });
}

function line(text, kind) {
  const el = document.createElement("p");
  el.className = `space-panel-${kind}`;
  el.textContent = text;
  return el;
}
