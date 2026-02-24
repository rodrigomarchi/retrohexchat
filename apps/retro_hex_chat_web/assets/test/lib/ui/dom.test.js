import { findClosestWithData } from "../../../js/lib/ui/dom.js";

describe("findClosestWithData", () => {
  it("returns data attribute from matching ancestor", () => {
    const ul = document.createElement("ul");
    const li = document.createElement("li");
    li.setAttribute("phx-value-nick", "Alice");
    ul.appendChild(li);
    const span = document.createElement("span");
    li.appendChild(span);

    expect(findClosestWithData(span, "li[phx-value-nick]", "phx-value-nick")).toBe("Alice");
  });

  it("returns dataset value when using dataset key", () => {
    const table = document.createElement("table");
    const tr = document.createElement("tr");
    tr.dataset.nickname = "Bob";
    table.appendChild(tr);
    const td = document.createElement("td");
    tr.appendChild(td);

    expect(findClosestWithData(td, "tr[data-nickname]", "nickname")).toBe("Bob");
  });

  it("returns null when no matching ancestor", () => {
    const div = document.createElement("div");
    expect(findClosestWithData(div, "li[phx-value-nick]", "phx-value-nick")).toBeNull();
  });

  it("returns null when target is null", () => {
    expect(findClosestWithData(null, "li", "data-id")).toBeNull();
  });

  it("returns null when target lacks closest method", () => {
    expect(findClosestWithData({}, "li", "data-id")).toBeNull();
  });

  it("matches the target element itself", () => {
    const li = document.createElement("li");
    li.dataset.channel = "#general";
    expect(findClosestWithData(li, "[data-channel]", "channel")).toBe("#general");
  });
});
