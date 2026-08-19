import { dropdownMaxHeight, MIN_DROPDOWN_HEIGHT } from "../../../js/lib/chat/dropdown_position.js";

describe("dropdownMaxHeight", () => {
  it("leaves a panel fully below the top edge unchanged", () => {
    expect(dropdownMaxHeight({ top: 40, bottom: 300 })).toBe(null);
  });

  it("caps a panel overflowing the top edge to the height still visible", () => {
    expect(dropdownMaxHeight({ top: -120, bottom: 240 })).toBe(240);
  });

  it("leaves an overflowing panel alone when too little remains visible", () => {
    expect(dropdownMaxHeight({ top: -500, bottom: MIN_DROPDOWN_HEIGHT })).toBe(null);
    expect(dropdownMaxHeight({ top: -500, bottom: MIN_DROPDOWN_HEIGHT - 1 })).toBe(null);
  });

  it("caps just above the floor", () => {
    expect(dropdownMaxHeight({ top: -1, bottom: MIN_DROPDOWN_HEIGHT + 1 })).toBe(
      MIN_DROPDOWN_HEIGHT + 1,
    );
  });
});
