/**
 * LiveView hook for the formatting toolbar.
 *
 * Uses mousedown (not click) with preventDefault() to avoid stealing focus
 * from the chat input. Handles B/I/U buttons, color dropdown toggle,
 * and color swatch selection.
 */
const FormatToolbarHook = {
  mounted() {
    const FORMAT_CODES = {
      bold: "\x02",
      italic: "\x1D",
      underline: "\x1F",
      color: "\x03",
    };

    const dropdown = this.el.querySelector(".format-color-dropdown");

    // Handle format button clicks via mousedown to prevent input blur
    this.el.addEventListener("mousedown", (e) => {
      const btn = e.target.closest(".format-btn");
      if (!btn) return;

      e.preventDefault();

      const formatCode = btn.dataset.formatCode;
      if (!formatCode) return;

      if (formatCode === "color") {
        // Toggle color dropdown
        const isHidden =
          dropdown.style.display === "none" || !dropdown.style.display;
        dropdown.style.display = isHidden ? "grid" : "none";
        return;
      }

      const code = FORMAT_CODES[formatCode];
      if (code) {
        this.insertAtCursor(code);
      }
    });

    // Handle color swatch selection
    this.el.addEventListener("mousedown", (e) => {
      const swatch = e.target.closest(".color-swatch");
      if (!swatch) return;

      e.preventDefault();

      const colorCode = swatch.dataset.colorCode;
      if (colorCode !== undefined) {
        this.insertAtCursor("\x03" + colorCode);
        dropdown.style.display = "none";
      }
    });

    // Close dropdown on outside click
    document.addEventListener("mousedown", (e) => {
      if (!this.el.contains(e.target)) {
        dropdown.style.display = "none";
      }
    });

    // Close dropdown on Escape
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        dropdown.style.display = "none";
      }
    });
  },

  insertAtCursor(text) {
    const input = document.getElementById("chat-input");
    if (!input) return;

    const start = input.selectionStart;
    const end = input.selectionEnd;
    const value = input.value;
    input.value = value.slice(0, start) + text + value.slice(end);
    input.selectionStart = input.selectionEnd = start + text.length;
    input.dispatchEvent(new Event("input", { bubbles: true }));
    input.focus();
  },
};

export default FormatToolbarHook;
