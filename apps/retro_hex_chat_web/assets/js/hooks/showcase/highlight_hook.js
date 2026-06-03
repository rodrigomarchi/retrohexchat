import hljs from "highlight.js/lib/core";
import elixir from "highlight.js/lib/languages/elixir";
import xml from "highlight.js/lib/languages/xml";

hljs.registerLanguage("elixir", elixir);
hljs.registerLanguage("xml", xml);
hljs.registerLanguage("heex", (hljsInstance) => {
  const elixirLang = elixir(hljsInstance);
  const xmlLang = xml(hljsInstance);
  return {
    name: "HEEx",
    subLanguage: ["xml", "elixir"],
    contains: [...xmlLang.contains, ...elixirLang.contains],
  };
});

const HighlightHook = {
  mounted() {
    this.highlightAll();
  },

  updated() {
    this.highlightAll();
  },

  highlightAll() {
    this.el.querySelectorAll("pre code").forEach((block) => {
      delete block.dataset.highlighted;
      hljs.highlightElement(block);
    });
  },
};

export default HighlightHook;
