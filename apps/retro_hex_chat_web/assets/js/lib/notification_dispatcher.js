/**
 * Central notification dispatcher.
 *
 * Receives a notification event from the server and fans out to
 * enabled output channels based on user preferences and context.
 *
 * @param {Object} deps - Dependencies (toast, sound, titleFlash, browserNotif, faviconBadge)
 * @returns {Object} Dispatcher with dispatch() and dispatchBatch() methods
 */
export function createDispatcher(deps) {
  const { toast, sound, titleFlash, browserNotif, faviconBadge } = deps;

  /**
   * Dispatch a single notification event.
   *
   * @param {Object} event - Notification event payload from server
   * @param {Object} prefs - Current notification preferences
   * @param {Object} context - { activeChannel, tabVisible }
   */
  function dispatch(event, prefs, context) {
    const { activeChannel, tabVisible } = context;

    // Active channel suppression (PMs always pass through)
    if (event.type !== "pm" && event.channel === activeChannel) {
      return;
    }

    // Update favicon badge (always, even in DND)
    if (faviconBadge) {
      faviconBadge.show();
    }

    // DND mode — badges update but no audible/visual notifications
    if (prefs.dnd_enabled) {
      return;
    }

    // Muted channel — no notifications
    const channelLevel = getChannelLevel(prefs, event.channel);
    if (channelLevel === "mute") {
      return;
    }

    // Mentions only — skip non-highlighted messages
    if (channelLevel === "mentions_only" && !event.highlighted && event.type !== "pm") {
      return;
    }

    // Check trigger rules
    if (!isTriggerEnabled(event.type, prefs)) {
      return;
    }

    // Build display content (privacy mode masking)
    const displayContent = buildDisplayContent(event, prefs);

    // Fan out to enabled channels
    if (toast) {
      toast.show({
        id: event.id,
        title: displayContent.title,
        body: displayContent.body,
        channel: event.channel,
        type: event.type,
      });
    }

    if (sound && prefs.sounds_enabled) {
      sound.play(event.type);
    }

    if (titleFlash && prefs.title_flash_enabled) {
      titleFlash.start("* New activity");
    }

    if (browserNotif && prefs.browser_notifications && !tabVisible) {
      browserNotif.show(displayContent.title, displayContent.body, () => {
        // Click callback — focus tab
        window.focus();
      });
    }
  }

  /**
   * Dispatch a batch notification (reconnect scenario).
   *
   * @param {Object} batch - { count, channels, channel_count }
   * @param {Object} prefs - Current notification preferences
   */
  function dispatchBatch(batch, prefs) {
    if (faviconBadge) {
      faviconBadge.show();
    }

    if (prefs.dnd_enabled) {
      return;
    }

    if (toast) {
      const body = `${batch.count} new messages in ${batch.channel_count} channels`;
      toast.show({
        id: "batch_" + Date.now(),
        title: "New Activity",
        body,
        channel: null,
        type: "batch",
      });
    }
  }

  return { dispatch, dispatchBatch };
}

/**
 * Get channel notification level from preferences.
 * @param {Object} prefs
 * @param {string|null} channel
 * @returns {string} "normal" | "mentions_only" | "mute"
 */
function getChannelLevel(prefs, channel) {
  if (!channel) return "normal";
  return (prefs.channel_levels && prefs.channel_levels[channel]) || "normal";
}

/**
 * Check if trigger is enabled for event type.
 * @param {string} type
 * @param {Object} prefs
 * @returns {boolean}
 */
function isTriggerEnabled(type, prefs) {
  switch (type) {
    case "mention":
      return prefs.trigger_mentions;
    case "pm":
      return prefs.trigger_pms;
    case "channel_message":
      return prefs.trigger_channel_messages;
    case "join":
    case "leave":
      return prefs.trigger_joins_leaves;
    default:
      return false;
  }
}

/**
 * Build display content, applying privacy mode masking if enabled.
 * @param {Object} event
 * @param {Object} prefs
 * @returns {{ title: string, body: string }}
 */
function buildDisplayContent(event, prefs) {
  if (prefs.privacy_mode) {
    if (event.type === "pm") {
      return { title: "New private message", body: "You have a new private message" };
    }
    return {
      title: `New message in ${event.channel}`,
      body: `New activity in ${event.channel}`,
    };
  }

  const sender = event.sender || "Unknown";
  if (event.type === "pm") {
    return { title: `PM from ${sender}`, body: event.content || "" };
  }
  return {
    title: `${sender} in ${event.channel}`,
    body: event.content || "",
  };
}
