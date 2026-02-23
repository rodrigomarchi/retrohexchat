const P2PSessionHook = {
  mounted() {
    this._beforeUnloadHandler = () => {
      this.pushEvent("p2p_leave", {});
    };
    window.addEventListener("beforeunload", this._beforeUnloadHandler);

    this.handleEvent("p2p_close_tab", () => {
      // Remove beforeunload so we don't double-fire p2p_leave
      window.removeEventListener("beforeunload", this._beforeUnloadHandler);
      window.close();
    });
  },

  destroyed() {
    if (this._beforeUnloadHandler) {
      window.removeEventListener("beforeunload", this._beforeUnloadHandler);
    }
  },
};

export default P2PSessionHook;
