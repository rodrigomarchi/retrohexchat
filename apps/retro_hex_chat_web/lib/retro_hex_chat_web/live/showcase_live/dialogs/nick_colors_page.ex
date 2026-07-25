defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.NickColorsPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.NickColorsDialog
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: dgettext("showcase", "Nick Colors"),
       active_page: "nick-colors",
       selected: nil,
       nick_colors: [
         %{target_nickname: "alice", color_index: 4},
         %{target_nickname: "bob", color_index: 2},
         %{target_nickname: "carol", color_index: 9}
       ]
     )}
  end

  @impl true
  def handle_event("nick_color_select", %{"nickname" => nick}, socket) do
    {:noreply, assign(socket, selected: nick)}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Nick Colors")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Nick Colors")}
        description="Per-nickname color overrides — the panel composes into a desktop window in the chat."
      >
        <div class="h-[360px] shadow-retro-field overflow-hidden p-2">
          <.nick_colors_panel
            id="nick-colors-demo"
            nick_colors={@nick_colors}
            selected={@selected}
            on_select="nick_color_select"
          />
        </div>
        <.code_example>
          &lt;.nick_colors_panel
          id="nick-colors"
          nick_colors=&#123;@entries&#125;
          selected=&#123;@selected&#125;
          on_select="nick_color_select"
          /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
