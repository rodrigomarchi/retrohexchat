/**
 * Reactions on the conference connection: sending one to the room, and
 * floating the room's reactions over the participant's tile for a moment.
 * Mixed into the controller by `createConferenceConnection`; the methods
 * share its `this`.
 */
import { t } from "../i18n.js";
import { stringOrNull } from "./payload.js";
import {
  buildReactionBubble,
  ensureReactionStack,
  REACTION_TTL_MS,
  reactionEmoji,
  reactionIconNode,
} from "./reactions.js";

export function reactionMethods(el, _ports) {
  return {
    _sendReaction(reaction) {
      if (!reaction || !this.channel) {
        this._notifyWarning(
          t("Join the conference before sending reactions."),
          "reaction_not_ready",
        );
        return;
      }

      this.channel
        .push("group_call_reaction", { reaction })
        ?.receive?.("error", (reply) => {
          this._notifyWarning(
            reply?.message || t("Could not send your reaction."),
            "reaction_failed",
          );
        })
        ?.receive?.("timeout", () => {
          this._notifyWarning(
            t("Your reaction did not reach the call in time."),
            "reaction_timeout",
          );
        });
    },

    _applyReaction(payload = {}) {
      const participantId = stringOrNull(payload.participant_id ?? payload.participantId);
      if (!participantId) return;

      const reactionId = stringOrNull(payload.id) || `reaction-${Date.now()}`;
      const reaction = payload.reaction || "heart";
      const tiles = this._reactionTiles(participantId);

      for (const tile of tiles) {
        const stack = ensureReactionStack(tile);
        const bubble = buildReactionBubble({
          reaction,
          reactionId,
          iconNode: reactionIconNode(el, reaction),
          emoji: reactionEmoji(reaction),
        });
        stack.appendChild(bubble);

        const key = `${reactionId}:${tile.dataset.streamId || "local"}`;
        const timer = setTimeout(() => {
          bubble.remove();
          this.reactionTimers.delete(key);
        }, REACTION_TTL_MS);

        this.reactionTimers.set(key, timer);
      }
    },

    _reactionTiles(participantId) {
      const tiles = this.tileView.tilesForParticipant(participantId);
      return tiles.length > 0 ? tiles : this._claimUnassignedRemoteTile(participantId);
    },
  };
}
