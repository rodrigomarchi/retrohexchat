defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.IgnoreListPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.IgnoreListDialog
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Ignore List"),
       active_page: "ignore-list",
       selected: nil,
       entries: [
         %{nickname: "spammer", ignore_type: :all, expires_at: nil},
         %{
           nickname: "troll",
           ignore_type: :pms,
           expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
         }
       ]
     )}
  end

  @impl true
  def handle_event("control_select", %{"nickname" => nick}, socket) do
    {:noreply, assign(socket, selected: nick)}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Ignore List")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Ignore List")}
        description="Ignored nicknames with scope and expiry — the panel composes into a desktop window in the chat."
      >
        <div class="h-[360px] shadow-retro-field overflow-hidden p-2">
          <.ignore_list_panel
            id="ignore-list-demo"
            entries={@entries}
            selected={@selected}
            on_select="control_select"
          />
        </div>
        <.code_example>
          &lt;.ignore_list_panel
          id="ignore-list"
          entries=&#123;@entries&#125;
          selected=&#123;@selected&#125;
          on_select="control_select"
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
