const URLCatcherHook = {
  mounted() {
    this.el.addEventListener("dblclick", (e) => {
      const row = e.target.closest("tr[data-url]");
      if (row) {
        const url = row.dataset.url;
        window.open(url, "_blank", "noopener,noreferrer");
      }
    });
  }
};

export default URLCatcherHook;
