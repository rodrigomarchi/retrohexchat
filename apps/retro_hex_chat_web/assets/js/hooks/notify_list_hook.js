const NotifyListHook = {
  mounted() {
    this.el.addEventListener("dblclick", (e) => {
      const row = e.target.closest("tr[data-nickname]")
      if (row) {
        this.pushEvent("notify_dblclick", { nickname: row.dataset.nickname })
      }
    })
  }
}

export default NotifyListHook
