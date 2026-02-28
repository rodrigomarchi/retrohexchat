defmodule RetroHexChatWeb.ShowcaseLive.Layout.ContextMenuPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ContextMenu
  import RetroHexChatWeb.ShowcaseHelpers

  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Context Menu", active_page: "context-menu")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Context Menu</h2>

      <.showcase_card
        title="Basic"
        description="Right-click context menu with icons and separator."
      >
        <div class="relative h-[200px]">
          <.context_menu id="demo-basic" position="absolute" x={16} y={16}>
            <.context_menu_item>
              <:icon><Icons.icon_tab_pm class="w-[14px] h-[14px]" /></:icon>
              Query (PM)
            </.context_menu_item>
            <.context_menu_item>
              <:icon><Icons.icon_btn_search class="w-[14px] h-[14px]" /></:icon>
              Whois
            </.context_menu_item>
            <.context_menu_separator />
            <.context_menu_item>
              <:icon><Icons.icon_tab_contacts class="w-[14px] h-[14px]" /></:icon>
              Add to Contacts
            </.context_menu_item>
            <.context_menu_item>
              <:icon><Icons.icon_palette class="w-[14px] h-[14px]" /></:icon>
              Set Nick Color
            </.context_menu_item>
            <.context_menu_item>
              <:icon><Icons.icon_btn_ignore class="w-[14px] h-[14px]" /></:icon>
              Ignore
            </.context_menu_item>
          </.context_menu>
        </div>
        <.code_example>
          &lt;.context_menu id="my-menu" x={100} y={200}&gt;
          &lt;.context_menu_item&gt;
          &lt;:icon&gt;&lt;Icons.icon_tab_pm class="w-[14px] h-[14px]" /&gt;&lt;/:icon&gt;
          Query (PM)
          &lt;/.context_menu_item&gt;
          &lt;.context_menu_separator /&gt;
          &lt;.context_menu_item&gt;Add to Contacts&lt;/.context_menu_item&gt;
          &lt;/.context_menu&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Disabled Items"
        description="Items can be disabled to prevent interaction."
      >
        <div class="relative h-[180px]">
          <.context_menu id="demo-disabled" position="absolute" x={16} y={16}>
            <.context_menu_item>
              <:icon><Icons.icon_p2p class="w-[14px] h-[14px]" /></:icon>
              P2P Session
            </.context_menu_item>
            <.context_menu_item disabled>
              <:icon><Icons.icon_microphone class="w-[14px] h-[14px]" /></:icon>
              Audio Call
            </.context_menu_item>
            <.context_menu_item disabled>
              <:icon><Icons.icon_camera class="w-[14px] h-[14px]" /></:icon>
              Video Call
            </.context_menu_item>
            <.context_menu_item disabled>
              <:icon><Icons.icon_file_send class="w-[14px] h-[14px]" /></:icon>
              Send File
            </.context_menu_item>
          </.context_menu>
        </div>
        <.code_example>
          &lt;.context_menu_item disabled&gt;
          &lt;:icon&gt;&lt;Icons.icon_camera class="w-[14px] h-[14px]" /&gt;&lt;/:icon&gt;
          Video Call
          &lt;/.context_menu_item&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="With Shortcuts"
        description="Items can display keyboard shortcut hints on the right side."
      >
        <div class="relative h-[160px]">
          <.context_menu id="demo-shortcuts" position="absolute" x={16} y={16}>
            <.context_menu_item>
              <:icon><Icons.icon_tab_pm class="w-[14px] h-[14px]" /></:icon>
              <:shortcut>Ctrl+Q</:shortcut>
              Query (PM)
            </.context_menu_item>
            <.context_menu_item>
              <:icon><Icons.icon_btn_search class="w-[14px] h-[14px]" /></:icon>
              <:shortcut>Ctrl+W</:shortcut>
              Whois
            </.context_menu_item>
            <.context_menu_separator />
            <.context_menu_item>
              <:icon><Icons.icon_btn_find class="w-[14px] h-[14px]" /></:icon>
              <:shortcut>Ctrl+F</:shortcut>
              Find
            </.context_menu_item>
          </.context_menu>
        </div>
        <.code_example>
          &lt;.context_menu_item&gt;
          &lt;:icon&gt;&lt;Icons.icon_tab_pm class="w-[14px] h-[14px]" /&gt;&lt;/:icon&gt;
          &lt;:shortcut&gt;Ctrl+Q&lt;/:shortcut&gt;
          Query (PM)
          &lt;/.context_menu_item&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Group Labels"
        description="Non-interactive labels for grouping related items."
      >
        <div class="relative h-[240px]">
          <.context_menu id="demo-labels" position="absolute" x={16} y={16}>
            <.context_menu_label>User Actions</.context_menu_label>
            <.context_menu_item>
              <:icon><Icons.icon_tab_pm class="w-[14px] h-[14px]" /></:icon>
              Query (PM)
            </.context_menu_item>
            <.context_menu_item>
              <:icon><Icons.icon_btn_search class="w-[14px] h-[14px]" /></:icon>
              Whois
            </.context_menu_item>
            <.context_menu_separator />
            <.context_menu_label>Operator</.context_menu_label>
            <.context_menu_item>
              <:icon><Icons.icon_dialog_kick class="w-[14px] h-[14px]" /></:icon>
              Kick
            </.context_menu_item>
            <.context_menu_item>
              <:icon><Icons.icon_ban class="w-[14px] h-[14px]" /></:icon>
              Ban
            </.context_menu_item>
          </.context_menu>
        </div>
        <.code_example>
          &lt;.context_menu_label&gt;User Actions&lt;/.context_menu_label&gt;
          &lt;.context_menu_item&gt;Query (PM)&lt;/.context_menu_item&gt;
          &lt;.context_menu_separator /&gt;
          &lt;.context_menu_label&gt;Operator&lt;/.context_menu_label&gt;
          &lt;.context_menu_item&gt;Kick&lt;/.context_menu_item&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
