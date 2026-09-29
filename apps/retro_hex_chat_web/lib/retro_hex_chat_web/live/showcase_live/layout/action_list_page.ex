defmodule RetroHexChatWeb.ShowcaseLive.Layout.ActionListPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ActionList
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers

  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: dgettext("showcase", "Action List"), active_page: "action-list")
     |> assign(current: "#tech")}
  end

  # A showcase page renders the component and nothing behind it, so the
  # controls it draws have nowhere to go. Answering them is what keeps a
  # click from taking the page down with an unmatched event.
  @impl true
  def handle_event("showcase_action_list_current", %{"entry" => entry}, socket) do
    {:noreply, assign(socket, current: entry)}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Action List")}</h2>

      <p class="text-xs text-muted-foreground mb-4">
        {dgettext(
          "showcase",
          "Pressing a row does what the row is about. Anything else the row can do is a button on the row itself. A button under the list acting on 'the selected item' is the shape this replaces."
        )}
      </p>

      <.showcase_card
        title={dgettext("showcase", "A door")}
        description="One action, and the whole row is it. The list of rooms, the list of saved links: press it and you are there."
      >
        <div class="shadow-retro-field bg-white p-2">
          <.action_list id="showcase-door" label={dgettext("showcase", "Rooms")}>
            <.action_row
              :for={room <- rooms()}
              id={"showcase-door-#{room.name}"}
              on_activate="showcase_noop"
              value={%{"channel" => room.name}}
            >
              <:icon><Icons.icon_channels class="w-4 h-4" /></:icon>
              <:title>{room.name}</:title>
              <:meta>{room.topic}</:meta>
              <:trailing>
                <.action_figure label={dgettext("showcase", "Users")} value={room.users} />
              </:trailing>
              <:cta label={dgettext("showcase", "Join")}>
                <Icons.icon_btn_add class="w-4 h-4" />
              </:cta>
            </.action_row>
          </.action_list>
        </div>
        <.code_example>
          &lt;.action_row on_activate=&#123;@on_join&#125; value=&#123;%&#123;"channel" =&gt; name&#125;&#125;&gt;
          &lt;:title&gt;&#123;name&#125;&lt;/:title&gt; &lt;:cta label="Join"&gt;&lt;Icons.icon_btn_add
          /&gt;&lt;/:cta&gt; &lt;/.action_row&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "An editor")}
        description="The press opens the row in the panel beside the list, and `current` says which one is open. Remove belongs to the row; Add belongs to the panel, because it has no row to belong to."
      >
        <div class="shadow-retro-field bg-white p-2 space-y-retro-8">
          <.action_list id="showcase-editor" label={dgettext("showcase", "Aliases")}>
            <.action_row
              :for={entry <- aliases()}
              id={"showcase-editor-#{entry.name}"}
              on_activate="showcase_action_list_current"
              value={%{"entry" => entry.name}}
              current={@current == entry.name}
            >
              <:title>{entry.name}</:title>
              <:meta>{entry.command}</:meta>
              <:action
                event="showcase_noop"
                value={%{"entry" => entry.name}}
                label={dgettext("showcase", "Remove %{name}", name: entry.name)}
                variant="destructive"
              >
                <Icons.icon_btn_remove class="w-4 h-4" />
              </:action>
            </.action_row>
          </.action_list>

          <div class="flex justify-start">
            <.button size="sm" variant="outline" phx-click="showcase_noop">
              <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
              {dgettext("showcase", "Add")}
            </.button>
          </div>
        </div>
        <.code_example>
          &lt;.action_row current=&#123;@editing == name&#125; …&gt; &lt;:action event=&#123;@on_remove&#125;
          label="Remove"&gt;&lt;Icons.icon_btn_remove /&gt;&lt;/:action&gt; &lt;/.action_row&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "More than one action")}
        description="Reordering is the case the old shape charged the most for: select, cross the dialog, press Up, cross back. On the row it is one press per step. A button that cannot apply is disabled in place, so the controls do not shift between rows."
      >
        <div class="shadow-retro-field bg-white p-2">
          <.action_list id="showcase-many" label={dgettext("showcase", "Perform commands")}>
            <.action_row
              :for={{command, index} <- Enum.with_index(commands())}
              id={"showcase-many-#{index}"}
              on_activate="showcase_noop"
              value={%{"position" => index}}
            >
              <:title>{command}</:title>
              <:action
                event="showcase_noop"
                label={dgettext("showcase", "Move up")}
                disabled={index == 0}
              >
                <Icons.icon_btn_up class="w-4 h-4" />
              </:action>
              <:action
                event="showcase_noop"
                label={dgettext("showcase", "Move down")}
                disabled={index == length(commands()) - 1}
              >
                <Icons.icon_btn_down class="w-4 h-4" />
              </:action>
              <:action
                event="showcase_noop"
                label={dgettext("showcase", "Remove")}
                variant="destructive"
              >
                <Icons.icon_btn_remove class="w-4 h-4" />
              </:action>
            </.action_row>
          </.action_list>
        </div>
        <.code_example>
          &lt;:action event=&#123;@on_move_up&#125; label="Move up" disabled=&#123;first?&#125;&gt;
          &lt;Icons.icon_btn_up /&gt; &lt;/:action&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end

  defp rooms do
    [
      %{name: "#tech", topic: dgettext("showcase", "No topic set"), users: "4"},
      %{name: "#brasil", topic: dgettext("showcase", "Bom dia"), users: "3"},
      %{name: "#arcade", topic: dgettext("showcase", "High scores"), users: "3"}
    ]
  end

  defp aliases do
    [
      %{name: "/j", command: "/join $1"},
      %{name: "/w", command: "/whois $1"},
      %{name: "#tech", command: "/join #tech"}
    ]
  end

  defp commands do
    ["/join #tech", "/mode $me +i", "/away Back in 10"]
  end
end
