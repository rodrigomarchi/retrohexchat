/**
 * LiveView hook for nicklist double-click → open PM query.
 * Listens for dblclick on nick <li> elements and pushes nicklist_dblclick event.
 */
const NicklistHook = {
  mounted() {
    this.el.addEventListener("dblclick", (e) => {
      const li = e.target.closest("li[phx-value-nick]");
      if (li) {
        const nick = li.getAttribute("phx-value-nick");
        if (nick) {
          this.pushEvent("nicklist_dblclick", { nick });
        }
      }
    });
  },
};

export default NicklistHook;
