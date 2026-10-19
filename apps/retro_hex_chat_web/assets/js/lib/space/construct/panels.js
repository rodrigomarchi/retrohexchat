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
  // The title's icon is the one the template drew for this kind of piece.
  for (const icon of content.querySelectorAll("[data-space-panel-icon]")) {
    icon.hidden = icon.dataset.spacePanelIcon !== modal.kind;
  }
  host.dataset.kind = modal.kind;
  content.querySelector("[data-space-panel-close]")?.addEventListener("click", () => close());

  // Where a character's portrait is drawn from: the template names the address
  // up to the recipe, which changes whenever the art does.
  const portrait = (avatar) => portraitOf(template.getAttribute("data-portrait-base"), avatar);
  const parts = BODIES[modal.kind](modal, say, portrait);
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

  board: (modal, say, portrait) => {
    const parts = [];
    if (modal.topic) parts.push(line(say("topic"), "label"), line(modal.topic, "item"));
    const pins = Array.isArray(modal.pins) ? modal.pins : [];
    if (pins.length > 0) {
      parts.push(line(say("pinned"), "label"));
      for (const pin of pins) parts.push(byline(pin.author, portrait(pin.avatar), pin.text));
    }
    return parts;
  },

  screen: (modal, say, portrait) => {
    const image = modal.image;
    if (!image?.url) return [];
    const img = document.createElement("img");
    img.src = image.url;
    img.alt = image.name ?? "";
    img.className = "space-panel-image";
    img.dataset.testid = "space-panel-image";
    return [img, byline(say("posted-by", image.author), portrait(image.avatar))];
  },

  arcade: (modal, say) => {
    const games = Array.isArray(modal.games) ? modal.games : [];
    const parts = modal.featured ? featuredGame(modal.featured) : [];
    if (games.length === 0) return parts;
    if (modal.featured) parts.push(line(modal.featured.others_label, "label"));
    const list = document.createElement("ul");
    list.className = "space-panel-games";
    for (const game of games) {
      const link = document.createElement("a");
      link.href = game.url;
      link.target = "_blank";
      link.rel = "noopener";
      link.className = "space-panel-game";
      link.dataset.testid = `space-panel-game-${game.id}`;
      link.append(cover(game), line(game.name, "game-name"), line(game.tagline ?? "", "note"));
      // Said by the server in the reader's language, and only when somebody is.
      if (game.activity) link.append(line(game.activity, "note"));
      const item = document.createElement("li");
      item.appendChild(link);
      list.appendChild(item);
    }
    return [...parts, list, line(say("opens-in-tab"), "note")];
  },
};

// The game a cabinet the room came with plays: its label and the two ways on
// — playing it, and its channel — and beside it, who is at it now and the
// matches of it anybody may watch. Every word in it is the server's, already
// in the reader's language.
function featuredGame(game) {
  const block = document.createElement("div");
  block.className = "space-panel-featured";
  block.dataset.testid = `space-panel-featured-${game.id}`;

  const card = document.createElement("div");
  card.className = "space-panel-featured-game";
  card.append(cover(game), line(game.name, "game-name"), line(game.tagline ?? "", "note"));
  const actions = document.createElement("div");
  actions.className = "space-panel-featured-actions";
  actions.append(
    tabLink(game.url, game.play_label, "space-panel-featured-play"),
    tabLink(game.channel_url, game.channel, "space-panel-featured-channel"),
  );
  card.appendChild(actions);

  block.append(card, featuredSide(game));
  return [block];
}

function featuredSide(game) {
  const side = document.createElement("div");
  side.className = "space-panel-featured-side";
  side.dataset.testid = "space-panel-featured-side";
  const live = game.live ?? [];
  if (!game.playing && live.length === 0) side.append(line(game.nobody ?? "", "note"));
  if (game.playing) side.append(line(game.playing, "note"));
  if (live.length > 0) {
    side.append(line(game.live_label, "label"));
    for (const match of live) {
      side.append(tabLink(match.url, match.label, `space-panel-watch-${match.token}`));
    }
  }
  return side;
}

function tabLink(href, text, testid) {
  const link = document.createElement("a");
  link.href = href;
  link.target = "_blank";
  link.rel = "noopener";
  link.className = "space-panel-link";
  link.dataset.testid = testid;
  link.textContent = text;
  return link;
}

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

// A game's cartridge label: its screenshot, or — for a game with none — its
// initial on parchment. The picture is decorative; the name is under it.
function cover(game) {
  if (!game.cover) return blankCover(game);
  const img = document.createElement("img");
  // A cover that does not load leaves the cartridge its initial, not a broken image.
  img.addEventListener("error", () => img.replaceWith(blankCover(game)), { once: true });
  img.src = game.cover;
  img.alt = "";
  img.setAttribute("loading", "lazy");
  img.setAttribute("decoding", "async");
  img.width = 160;
  img.height = 120;
  img.className = "space-panel-cover";
  return img;
}

function blankCover(game) {
  const blank = document.createElement("span");
  blank.className = "space-panel-cover space-panel-cover--blank";
  blank.textContent = (game.name ?? "?").trim().charAt(0);
  blank.setAttribute("aria-hidden", "true");
  return blank;
}

// The portrait of a character recipe, or null for anything that is not one:
// the recipe goes into a URL, so only its own alphabet is let through.
function portraitOf(base, avatar) {
  if (!base || typeof avatar !== "string" || !/^c1(\.[a-z0-9-]+){6}$/.test(avatar)) return null;
  const img = document.createElement("img");
  img.src = base + avatar;
  img.alt = "";
  img.width = 24;
  img.height = 24;
  img.className = "rh-portrait";
  img.setAttribute("aria-hidden", "true");
  img.dataset.testid = "nick-portrait";
  img.dataset.avatar = avatar;
  return img;
}

// A line by somebody, with their character's portrait when they made one.
function byline(author, portrait, text) {
  const row = document.createElement("p");
  row.className = "space-panel-byline";
  if (portrait) row.appendChild(portrait);
  const words = document.createElement("span");
  if (text === undefined) {
    words.textContent = author;
  } else {
    const who = document.createElement("strong");
    who.textContent = author;
    words.append(who, `: ${text}`);
  }
  row.appendChild(words);
  return row;
}

function line(text, kind) {
  const el = document.createElement("p");
  el.className = `space-panel-${kind}`;
  el.textContent = text;
  return el;
}
