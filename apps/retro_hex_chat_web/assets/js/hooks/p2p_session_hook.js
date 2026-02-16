const P2PSessionHook = {
  mounted() {
    this._beforeUnloadHandler = () => {
      this.pushEvent("p2p_leave", {});
    };
    window.addEventListener("beforeunload", this._beforeUnloadHandler);
  },

  destroyed() {
    if (this._beforeUnloadHandler) {
      window.removeEventListener("beforeunload", this._beforeUnloadHandler);
    }
  },
};

export default P2PSessionHook;
