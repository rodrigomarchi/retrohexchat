/**
 * The character this browser picked last time it walked into a space.
 *
 * The picker is mounted afresh on every visit and there is nothing on the
 * server that outlives one, so the memory lives where the person does. It is a
 * convenience and never load-bearing: a private window, blocked site data or a
 * different browser all mean "no memory", which is the state a first visit is
 * in anyway.
 *
 * @module space/character_memory
 */
import { log } from "../logger.js";

const PREFIX = "rhc:";

/**
 * @param {HTMLElement} el the picker element carrying `data-remember-key`
 * @param {() => Storage} [storage] resolves the store; injected for tests.
 *   Resolved inside the guard on every use, because a browser that blocks
 *   site data throws on reading `window.localStorage` itself, not only on
 *   using it — and the picker still has to open.
 */
export function createCharacterMemory(el, storage = () => window.localStorage) {
  return {
    /** @returns {string|null} the remembered character id, if there is one */
    read() {
      const key = this._key();
      if (!key) return null;

      try {
        return storage().getItem(key);
      } catch (error) {
        log.debug("[space-character] could not read the remembered character", error);
        return null;
      }
    },

    /** @param {string} avatar the character id to remember */
    write(avatar) {
      const key = this._key();
      if (!key || !avatar) return;

      try {
        storage().setItem(key, avatar);
      } catch (error) {
        log.debug("[space-character] could not remember the character", error);
      }
    },

    _key() {
      const scope = el.dataset.rememberKey;
      return scope ? `${PREFIX}${scope}` : null;
    },
  };
}
