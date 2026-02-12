const TreebarHook = {
  mounted() {
    this.el.addEventListener("contextmenu", (e) => {
      const li = e.target.closest("[data-channel]");
      if (li) {
        e.preventDefault();
        this.pushEvent("channel_right_click", {
          channel: li.dataset.channel,
          x: e.clientX,
          y: e.clientY
        });
      }
    });
  }
};

export default TreebarHook;
