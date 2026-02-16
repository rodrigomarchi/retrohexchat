/**
 * ChannelListForm hook — submits the hidden session form when the server
 * pushes the "submit_channel_join" event after clicking Join or Close.
 */
const ChannelListFormHook = {
  mounted() {
    this.handleEvent("submit_channel_join", () => {
      const form = document.getElementById("channel-join-form");
      if (form) form.requestSubmit();
    });
  },
};

export default ChannelListFormHook;
