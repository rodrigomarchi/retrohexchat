/**
 * LiveView binding for the space picker's memory of your last character.
 *
 * Reads on mount and tells the server, which is why the highlight can start on
 * the default and move: the server renders the picker before this browser has
 * said anything. Writes on every click, from the same delegated listener the
 * picker's own `phx-click` uses — see `lib/space/character_memory.js`.
 */
import { createCharacterMemory } from "../../lib/space/character_memory.js";

export function createSpaceCharacterMemoryHook({ factory = createCharacterMemory } = {}) {
  return {
    mounted() {
      this.memory = factory(this.el);

      const remembered = this.memory.read();
      if (remembered) this.pushEvent("space_remember_avatar", { avatar: remembered });

      this._onClick = (event) => {
        const button = event.target.closest("[phx-value-avatar]");
        if (button) this.memory.write(button.getAttribute("phx-value-avatar"));
      };

      this.el.addEventListener("click", this._onClick);
    },

    destroyed() {
      this.el.removeEventListener("click", this._onClick);
    },
  };
}

export default createSpaceCharacterMemoryHook();
