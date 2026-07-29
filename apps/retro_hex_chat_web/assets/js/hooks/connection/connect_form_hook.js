/**
 * ConnectForm hook — submits the hidden session form when the server
 * pushes the "submit_connect" event after successful nickname validation
 * or password authentication.
 *
 * Also detects client metadata for the hidden session form and suggested
 * trusted-terminal label.
 */
import { getClientInfo } from "../../lib/connection/client_info";
import {
  deviceLabelMetadata,
  suggestDeviceLabel,
} from "../../lib/connection/device_label_suggestion";

const ConnectFormHook = {
  mounted() {
    this.populateClientFields();
    this.populateDeviceLabelSuggestion();
    this.bindRememberDeviceToggle();
    this.updateRememberDevicePanel();

    this.handleEvent("submit_connect", () => {
      this.populateClientFields();
      const form = document.getElementById("connect-session-form");
      if (form) form.requestSubmit();
    });
  },

  updated() {
    this.populateDeviceLabelSuggestion();
    this.bindRememberDeviceToggle();
    this.updateRememberDevicePanel();
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

    this.renderDeviceLabelSuggestion(suggestion);
    this.renderDeviceLabelMetadata(deviceLabelMetadata(info));
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

  renderDeviceLabelSuggestion(suggestion) {
    const badge = this.el.querySelector("[data-device-label-suggestion]");
    const value = this.el.querySelector("[data-device-label-suggestion-value]");
    if (!badge || !value) return;

    value.textContent = suggestion;
    badge.hidden = suggestion === "";
  },

  renderDeviceLabelMetadata(metadata) {
    const wrapper = this.el.querySelector("[data-device-label-metadata]");
    if (!wrapper) return;

    let hasVisibleMetadata = false;

    for (const [key, value] of Object.entries(metadata)) {
      const item = this.el.querySelector(`[data-device-meta-item="${key}"]`);
      const valueEl = this.el.querySelector(`[data-device-meta-value="${key}"]`);
      if (!item || !valueEl) continue;

      valueEl.textContent = value;
      item.hidden = value === "";
      hasVisibleMetadata = hasVisibleMetadata || value !== "";
    }

    wrapper.hidden = !hasVisibleMetadata;
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

export default ConnectFormHook;
