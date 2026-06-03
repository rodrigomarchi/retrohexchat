const P2PChatFormHook = {
  mounted() {
    this.handleEvent("p2p_lobby_message_sent", ({ form_id }) => {
      if (!form_id || form_id === this.el.id) {
        this.el.reset();
      }
    });
  },
};

export default P2PChatFormHook;
