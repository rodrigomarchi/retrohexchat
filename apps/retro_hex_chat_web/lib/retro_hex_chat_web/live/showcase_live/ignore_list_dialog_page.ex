defmodule RetroHexChatWeb.ShowcaseLive.IgnoreListDialogPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.IgnoreListDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers

  alias RetroHexChatWeb.Icons

  @sample_entries [
    %{nickname: "BadUser99", reason: "Spam", expires_at: nil},
    %{nickname: "FloodBot", reason: "Message flood", expires_at: "2026-03-01"},
    %{nickname: "TrollFace", reason: "Harassment", expires_at: nil},
    %{nickname: "SpammerX", reason: "Advertisement spam", expires_at: "2026-04-15"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Ignore List Dialog",
       active_page: "ignore-list-dialog",
       entries: @sample_entries
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Ignore List Dialog</h2>

      <.showcase_card
        title="With Entries"
        description="Ignore list showing sample entries. No row selected — Remove button is disabled."
      >
        <.button variant="outline" phx-click={show_modal("ignore-list-default")}>
          <:icon><Icons.icon_dialog_ignore class="w-4 h-4" /></:icon>
          Open Ignore List
        </.button>
        <.ignore_list_dialog id="ignore-list-default" entries={@entries} />
        <.code_example>
          &lt;.ignore_list_dialog
          id="ignore-list"
          entries=&#123;@entries&#125;
          on_add="ignore_add"
          on_remove="ignore_remove"
          on_close="close_ignore_dialog"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Row Selected"
        description="A row is selected (highlighted). Remove button becomes active."
      >
        <.button variant="outline" phx-click={show_modal("ignore-list-selected")}>
          <:icon><Icons.icon_dialog_ignore class="w-4 h-4" /></:icon>
          Open (Row Selected)
        </.button>
        <.ignore_list_dialog
          id="ignore-list-selected"
          entries={@entries}
          selected="FloodBot"
        />
      </.showcase_card>

      <.showcase_card
        title="Empty List"
        description="No ignored users — table shows empty state message."
      >
        <.button variant="outline" phx-click={show_modal("ignore-list-empty")}>
          <:icon><Icons.icon_dialog_ignore class="w-4 h-4" /></:icon>
          Open (Empty)
        </.button>
        <.ignore_list_dialog id="ignore-list-empty" entries={[]} />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
