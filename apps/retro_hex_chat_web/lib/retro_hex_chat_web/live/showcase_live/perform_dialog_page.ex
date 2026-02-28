defmodule RetroHexChatWeb.ShowcaseLive.PerformDialogPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.PerformDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Perform Dialog",
       active_page: :perform_dialog,
       perform_selected: nil,
       autojoin_selected: nil,
       active_tab: "commands",
       perform_enabled: true
     )}
  end

  @impl true
  def handle_event("select-perform", %{"position" => pos}, socket) do
    {:noreply, assign(socket, perform_selected: String.to_integer(pos))}
  end

  def handle_event("select-autojoin", %{"channel" => channel}, socket) do
    {:noreply, assign(socket, autojoin_selected: channel)}
  end

  def handle_event("toggle-perform-enabled", _params, socket) do
    {:noreply, assign(socket, perform_enabled: !socket.assigns.perform_enabled)}
  end

  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        sample_commands: sample_commands(),
        sample_autojoin: sample_autojoin()
      )

    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Perform Dialog</h2>

      <.showcase_card
        title="Perform Dialog"
        description="Win98-style dialog for managing auto-execute commands and auto-join channels on connect."
      >
        <.button phx-click={show_modal("perform-demo")}>
          <:icon><Icons.icon_btn_perform /></:icon>
          Open Perform
        </.button>

        <.perform_dialog
          id="perform-demo"
          show={false}
          active_tab={@active_tab}
          perform_entries={@sample_commands}
          perform_selected={@perform_selected}
          perform_enabled={@perform_enabled}
          autojoin_entries={@sample_autojoin}
          autojoin_selected={@autojoin_selected}
          on_select="select-perform"
          on_toggle_enabled="toggle-perform-enabled"
        />

        <.code_example>
          &lt;.perform_dialog
          id="perform"
          show=&#123;true&#125;
          perform_entries=&#123;@commands&#125;
          perform_selected=&#123;@selected&#125;
          perform_enabled=&#123;@enabled&#125;
          autojoin_entries=&#123;@autojoin&#125;
          autojoin_selected=&#123;@autojoin_selected&#125;
          on_select="select"
          on_add="add"
          on_edit="edit"
          on_remove="remove"
          on_move_up="move-up"
          on_move_down="move-down"
          on_toggle_enabled="toggle-enabled"
          on_ok="save"
          on_cancel="cancel"
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Password Masking"
        description="NickServ IDENTIFY passwords are automatically masked in the commands list for security."
      >
        <div class="shadow-retro-field bg-white p-2">
          <p class="text-xs mb-1">
            <span class="font-bold">Input:</span>
            <code class="font-mono">/msg NickServ IDENTIFY mySecretPass</code>
          </p>
          <p class="text-xs">
            <span class="font-bold">Display:</span>
            <code class="font-mono">/msg NickServ IDENTIFY ***</code>
          </p>
        </div>
      </.showcase_card>

      <.showcase_card
        title="Component Attributes"
        description="Full list of supported attributes for the perform_dialog component."
      >
        <div class="overflow-x-auto">
          <table class="w-full text-xs">
            <thead>
              <tr class="border-b">
                <th class="text-left px-2 py-1">Attribute</th>
                <th class="text-left px-2 py-1">Type</th>
                <th class="text-left px-2 py-1">Default</th>
                <th class="text-left px-2 py-1">Description</th>
              </tr>
            </thead>
            <tbody>
              <tr class="border-b">
                <td class="px-2 py-1 font-mono">id</td>
                <td class="px-2 py-1">string</td>
                <td class="px-2 py-1">required</td>
                <td class="px-2 py-1">Dialog element ID</td>
              </tr>
              <tr class="border-b">
                <td class="px-2 py-1 font-mono">perform_entries</td>
                <td class="px-2 py-1">list</td>
                <td class="px-2 py-1">[]</td>
                <td class="px-2 py-1">List of %&#123;position, command&#125; maps</td>
              </tr>
              <tr class="border-b">
                <td class="px-2 py-1 font-mono">autojoin_entries</td>
                <td class="px-2 py-1">list</td>
                <td class="px-2 py-1">[]</td>
                <td class="px-2 py-1">List of %&#123;channel_name, channel_key&#125; maps</td>
              </tr>
              <tr class="border-b">
                <td class="px-2 py-1 font-mono">perform_enabled</td>
                <td class="px-2 py-1">boolean</td>
                <td class="px-2 py-1">true</td>
                <td class="px-2 py-1">Enable perform on connect</td>
              </tr>
              <tr>
                <td class="px-2 py-1 font-mono">on_*</td>
                <td class="px-2 py-1">any</td>
                <td class="px-2 py-1">nil</td>
                <td class="px-2 py-1">Event callbacks (tab, select, add, edit, remove, etc.)</td>
              </tr>
            </tbody>
          </table>
        </div>
      </.showcase_card>
    </.showcase_layout>
    """
  end

  # ── Sample Data ───────────────────────────────────────

  defp sample_commands do
    [
      %{position: 1, command: "/msg NickServ IDENTIFY mySecretPassword"},
      %{position: 2, command: "/join #lobby"},
      %{position: 3, command: "/mode +x"},
      %{position: 4, command: "/join #dev"},
      %{position: 5, command: "/ns identify anotherPass"}
    ]
  end

  defp sample_autojoin do
    [
      %{channel_name: "#lobby", channel_key: nil},
      %{channel_name: "#secret", channel_key: "key123"},
      %{channel_name: "#dev", channel_key: nil},
      %{channel_name: "#vip", channel_key: "s3cret"}
    ]
  end
end
