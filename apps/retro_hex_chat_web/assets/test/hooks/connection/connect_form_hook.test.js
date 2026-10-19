import { afterEach, describe, expect, it, vi } from "vitest";

import ConnectFormHook from "../../../js/hooks/connection/connect_form_hook.js";
import { getClientInfo } from "../../../js/lib/connection/client_info.js";
import { suggestDeviceLabel } from "../../../js/lib/connection/device_label_suggestion.js";
import { cleanupDOM, mountHook, simulateEvent } from "../../helpers/hook_helper.js";

function mountConnectHook() {
  return mountHook(ConnectFormHook, {
    attrs: { id: "connect-root" },
    html: `
      <form>
        <input type="checkbox" data-device-remember-toggle />
        <div hidden data-device-remember-panel>
          <input id="device-label" name="device_label" data-device-label-input value="" />
        </div>
      </form>
      <form id="connect-session-form">
        <input type="hidden" id="connect-device-label-input" name="device_label" value="" />
        <input type="hidden" id="connect-timezone-input" name="timezone" value="" />
        <input type="hidden" id="connect-client-info-input" name="client_info" value="{}" />
      </form>
    `,
  });
}

describe("ConnectFormHook", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    cleanupDOM();
  });

  it("fills an empty trusted terminal label with the metadata suggestion", () => {
    mountConnectHook();

    const info = getClientInfo();
    const expectedLabel = suggestDeviceLabel(info);
    const input = document.getElementById("device-label");

    expect(input.value).toBe(expectedLabel);
    expect(input.placeholder).toBe(expectedLabel);
    expect(document.getElementById("connect-device-label-input").value).toBe(expectedLabel);
  });

  it("shows the label only after remember terminal is checked", () => {
    mountConnectHook();

    const checkbox = document.querySelector("[data-device-remember-toggle]");
    const panel = document.querySelector("[data-device-remember-panel]");

    expect(panel.hidden).toBe(true);

    checkbox.checked = true;
    checkbox.dispatchEvent(new Event("change", { bubbles: true }));

    expect(panel.hidden).toBe(false);

    checkbox.checked = false;
    checkbox.dispatchEvent(new Event("change", { bubbles: true }));

    expect(panel.hidden).toBe(true);
  });

  it("does not overwrite a label after the user edits it", () => {
    const hook = mountConnectHook();
    const input = document.getElementById("device-label");

    input.value = "";
    input.dispatchEvent(new InputEvent("input", { bubbles: true }));
    hook.updated();

    expect(input.value).toBe("");
    expect(document.getElementById("connect-device-label-input").value).toBe("");
  });

  it("submits the hidden session form when the server confirms connect", () => {
    const hook = mountConnectHook();
    const form = document.getElementById("connect-session-form");
    form.requestSubmit = vi.fn();

    simulateEvent(hook, "submit_connect", {});

    expect(form.requestSubmit).toHaveBeenCalledTimes(1);
    expect(document.getElementById("connect-client-info-input").value).toBe(
      JSON.stringify(getClientInfo()),
    );
  });
});
