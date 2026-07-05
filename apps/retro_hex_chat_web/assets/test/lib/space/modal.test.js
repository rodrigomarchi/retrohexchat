import { describe, it, expect, vi, afterEach } from "vitest";

import { ModalController } from "../../../js/lib/space/modal.js";

describe("ModalController", () => {
  let controller;

  afterEach(() => {
    controller?.detach();
  });

  it("opens and closes with the current payload", () => {
    const changes = [];
    controller = new ModalController({ onChange: (m) => changes.push(m) });

    expect(controller.isOpen()).toBe(false);

    controller.open({ title: "Menu", asset: "board_menu_v1", kind: "image" });
    expect(controller.isOpen()).toBe(true);
    expect(controller.current().title).toBe("Menu");

    controller.close();
    expect(controller.isOpen()).toBe(false);
    expect(controller.current()).toBe(null);
    expect(changes).toHaveLength(2);
  });

  it("closes on Escape once attached", () => {
    controller = new ModalController({});
    controller.attach();
    controller.open({ title: "X", asset: "a", kind: "image" });

    window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
    expect(controller.isOpen()).toBe(false);
  });

  it("ignores Escape when nothing is open", () => {
    const onChange = vi.fn();
    controller = new ModalController({ onChange });
    controller.attach();

    window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
    expect(onChange).not.toHaveBeenCalled();
  });
});
