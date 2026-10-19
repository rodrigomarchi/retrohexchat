/**
 * The connect form's client-field and device-label controller — no LiveView.
 *
 * Fills the hidden session fields (timezone, client info, device label),
 * suggests a trusted-terminal label, and wires the remember-device panel. The hook binds this and calls `submit()` when the server clears the
 * connection to submit.
 *
 * @module connection/connect_form
 */
import { getClientInfo } from "./client_info";
import { suggestDeviceLabel } from "./device_label_suggestion";

export function createConnectForm(el) {
  const form = {
    el,
    _clientInfo: null,

    mount() {
      this.populateClientFields();
      this.populateDeviceLabelSuggestion();
      this.bindRememberDeviceToggle();
      this.updateRememberDevicePanel();
    },

    reconcile() {
      this.populateDeviceLabelSuggestion();
      this.bindRememberDeviceToggle();
      this.updateRememberDevicePanel();
    },

    submit() {
      this.populateClientFields();
      const sessionForm = document.getElementById("connect-session-form");
      if (sessionForm) sessionForm.requestSubmit();
    },

    clientInfo() {
      if (!this._clientInfo) this._clientInfo = getClientInfo();
      return this._clientInfo;
    },

    populateClientFields() {
      const tz = Intl.DateTimeFormat().resolvedOptions().timeZone || "Etc/UTC";
      const tzInput = document.getElementById("connect-timezone-input");
      if (tzInput) tzInput.value = tz;

      const clientInfoInput = document.getElementById("connect-client-info-input");
      if (clientInfoInput) clientInfoInput.value = JSON.stringify(this.clientInfo());

      this.populateHiddenDeviceLabel();
    },

    populateDeviceLabelSuggestion() {
      const info = this.clientInfo();
      const suggestion = suggestDeviceLabel(info);
      const input = this.el.querySelector("[data-device-label-input]");

      this.bindDeviceLabelInput(input);

      if (input) {
        input.dataset.deviceLabelSuggestion = suggestion;
        input.placeholder = suggestion;

        if (input.value.trim() === "" && input.dataset.deviceLabelUserEdited !== "true") {
          input.value = suggestion;
        }
      }

      this.populateHiddenDeviceLabel();
    },

    bindDeviceLabelInput(input) {
      if (!input || input.dataset.deviceLabelBound === "true") return;

      input.addEventListener("input", () => {
        input.dataset.deviceLabelUserEdited = "true";
        this.populateHiddenDeviceLabel();
      });

      input.dataset.deviceLabelBound = "true";
    },

    populateHiddenDeviceLabel() {
      const input = this.el.querySelector("[data-device-label-input]");
      const hiddenInput = document.getElementById("connect-device-label-input");

      if (input && hiddenInput) hiddenInput.value = input.value;
    },

    bindRememberDeviceToggle() {
      const checkbox = this.el.querySelector("[data-device-remember-toggle]");
      if (!checkbox || checkbox.dataset.deviceRememberBound === "true") return;

      checkbox.addEventListener("change", () => {
        this.updateRememberDevicePanel();
      });

      checkbox.dataset.deviceRememberBound = "true";
    },

    updateRememberDevicePanel() {
      const checkbox = this.el.querySelector("[data-device-remember-toggle]");
      const panel = this.el.querySelector("[data-device-remember-panel]");
      if (!panel) return;

      panel.hidden = !checkbox?.checked;
    },
  };

  return form;
}
