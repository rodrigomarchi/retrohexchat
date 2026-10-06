/**
 * LiveView hook binding the composer's microphone to the upload that carries a
 * recording.
 *
 * A recording is a message of its own: the moment one exists it goes up the
 * same presigned path a chosen file does, on an upload of its own, and the
 * server sends it the moment it lands. The only thing this side has to say
 * first is how long it runs — the server stores that beside the file so a
 * message can read "0:07" without anybody downloading a byte. A take that
 * fails is reported by name; the composer words it.
 *
 * Everything else is in `lib/uploads/voice_recorder_panel.js` and the recorder
 * it drives; `navigator.mediaDevices` may not appear inside a hook, and this is
 * the reason the rule exists rather than an exception to it.
 */
import { createVoiceRecorderPanel } from "../../lib/uploads/voice_recorder_panel.js";

export function createVoiceRecorderHook(deps = {}) {
  const build = deps.createVoiceRecorderPanel ?? createVoiceRecorderPanel;

  return {
    mounted() {
      // `phx-target` is where this element already says which component owns it;
      // a second attribute saying the same thing is a second thing to keep true.
      const target = this.el.getAttribute("phx-target");
      const upload = this.el.dataset.voiceUpload;

      this.panel = build(this.el, {
        onRecorded: ({ file, durationMs, contentType }) => {
          this.pushEventTo(target, "voice_recorded", {
            filename: file.name,
            duration_ms: durationMs,
            content_type: contentType,
          });

          this.uploadTo(target, upload, [file]);
        },
        onError: (reason) => {
          this.pushEventTo(target, "voice_error", { reason });
        },
      });

      this.panel.mount();
    },

    destroyed() {
      this.panel?.destroy();
    },
  };
}

export default createVoiceRecorderHook();
