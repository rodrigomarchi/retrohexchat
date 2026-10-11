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

  describe("a confirm", () => {
    const gate = { kind: "confirm", action: "enter_construct", title: "Construct" };

    it("Yes closes it and acts on its action", () => {
      const onConfirm = vi.fn();
      controller = new ModalController({ onConfirm });
      controller.open(gate);
      controller.confirm();
      expect(controller.isOpen()).toBe(false);
      expect(onConfirm).toHaveBeenCalledWith("enter_construct");
    });

    it("answers Enter and y with Yes, and keeps the key from the line below", () => {
      for (const key of ["Enter", "y"]) {
        const onConfirm = vi.fn();
        const below = vi.fn();
        controller?.detach();
        controller = new ModalController({ onConfirm });
        controller.attach();
        window.addEventListener("keydown", below);
        controller.open(gate);

        window.dispatchEvent(new KeyboardEvent("keydown", { key }));

        expect(onConfirm).toHaveBeenCalledOnce();
        expect(below).not.toHaveBeenCalled();
        window.removeEventListener("keydown", below);
      }
    });

    it("answers Escape and n with No", () => {
      for (const key of ["Escape", "n"]) {
        const onConfirm = vi.fn();
        controller?.detach();
        controller = new ModalController({ onConfirm });
        controller.attach();
        controller.open(gate);

        window.dispatchEvent(new KeyboardEvent("keydown", { key }));

        expect(controller.isOpen()).toBe(false);
        expect(onConfirm).not.toHaveBeenCalled();
      }
    });

    it("a board never confirms anything", () => {
      const onConfirm = vi.fn();
      controller = new ModalController({ onConfirm });
      controller.attach();
      controller.open({ kind: "image", title: "Menu", asset: "board_menu_v1" });
      window.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter" }));
      controller.confirm();
      expect(onConfirm).not.toHaveBeenCalled();
    });
  });
});
