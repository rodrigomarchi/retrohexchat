defmodule RetroHexChatWeb.ShowcaseLive.MenuPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  alias RetroHexChatWeb.Icons

  import RetroHexChatWeb.Components.UI.Menu
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Menu", active_page: "menu")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Menu</h2>

      <.showcase_card title="Basic Menu" description="A simple context menu with items and icons.">
        <div class="inline-block">
          <.menu>
            <.menu_item>
              <:icon><Icons.icon_btn_channel_list /></:icon>
              Channel List
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_toggle_conversations /></:icon>
              Toggle Conversations
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_toggle_nicklist /></:icon>
              Toggle Nicklist
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_find /></:icon>
              Find
            </.menu_item>
          </.menu>
        </div>
        <.code_example>
          &lt;.menu&gt;
          &lt;.menu_item&gt;
          &lt;:icon&gt;&lt;Icons.icon_btn_channel_list /&gt;&lt;/:icon&gt;
          Channel List
          &lt;/.menu_item&gt;
          &lt;/.menu&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="With Separators" description="Menu items grouped by separators.">
        <div class="inline-block">
          <.menu>
            <.menu_item>
              <:icon><Icons.icon_btn_channel_list /></:icon>
              Channel List
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_toggle_conversations /></:icon>
              Toggle Conversations
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_toggle_nicklist /></:icon>
              Toggle Nicklist
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_find /></:icon>
              Find
            </.menu_item>
            <.menu_separator />
            <.menu_item>
              <:icon><Icons.icon_btn_address_book /></:icon>
              Address Book
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_highlight_words /></:icon>
              Highlight Words
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_ignore_list /></:icon>
              Ignore List
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_url_catcher /></:icon>
              URL Catcher
            </.menu_item>
            <.menu_separator />
            <.menu_item>
              <:icon><Icons.icon_btn_settings /></:icon>
              Settings
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_bot_management /></:icon>
              Bot Management
            </.menu_item>
          </.menu>
        </div>
        <.code_example>
          &lt;.menu_item&gt;
          &lt;:icon&gt;&lt;Icons.icon_btn_find /&gt;&lt;/:icon&gt;
          Find
          &lt;/.menu_item&gt;
          &lt;.menu_separator /&gt;
          &lt;.menu_item&gt;
          &lt;:icon&gt;&lt;Icons.icon_btn_address_book /&gt;&lt;/:icon&gt;
          Address Book
          &lt;/.menu_item&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="With Shortcuts" description="Menu items with keyboard shortcut hints.">
        <div class="inline-block">
          <.menu>
            <.menu_item>
              <:icon><Icons.icon_btn_edit /></:icon>
              Cut
              <:shortcut>Ctrl+X</:shortcut>
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_copy /></:icon>
              Copy
              <:shortcut>Ctrl+C</:shortcut>
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_dialog_paste /></:icon>
              Paste
              <:shortcut>Ctrl+V</:shortcut>
            </.menu_item>
            <.menu_separator />
            <.menu_item>
              <:icon><Icons.icon_btn_search /></:icon>
              Select All
              <:shortcut>Ctrl+A</:shortcut>
            </.menu_item>
          </.menu>
        </div>
        <.code_example>
          &lt;.menu_item&gt;
          &lt;:icon&gt;&lt;Icons.icon_copy /&gt;&lt;/:icon&gt;
          Copy
          &lt;:shortcut&gt;Ctrl+C&lt;/:shortcut&gt;
          &lt;/.menu_item&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="Disabled Items" description="Some menu items can be disabled.">
        <div class="inline-block">
          <.menu>
            <.menu_item>
              <:icon><Icons.icon_folder /></:icon>
              Open
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_save /></:icon>
              Save
            </.menu_item>
            <.menu_item disabled>
              <:icon><Icons.icon_btn_save /></:icon>
              Save As...
            </.menu_item>
            <.menu_separator />
            <.menu_item disabled>
              <:icon><Icons.icon_notepad /></:icon>
              Print
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_close /></:icon>
              Exit
            </.menu_item>
          </.menu>
        </div>
        <.code_example>
          &lt;.menu_item disabled&gt;
          &lt;:icon&gt;&lt;Icons.icon_btn_save /&gt;&lt;/:icon&gt;
          Save As...
          &lt;/.menu_item&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Platform-Style Tools Menu"
        description="Replicating the platform's Tools dropdown menu with icons."
      >
        <div class="inline-block">
          <.menu class="min-w-[200px]">
            <.menu_item>
              <:icon><Icons.icon_btn_channel_list /></:icon>
              Channel List
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_toggle_conversations /></:icon>
              Toggle Conversations
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_toggle_nicklist /></:icon>
              Toggle Nicklist
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_find /></:icon>
              Find
            </.menu_item>
            <.menu_separator />
            <.menu_item>
              <:icon><Icons.icon_btn_address_book /></:icon>
              Address Book
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_highlight_words /></:icon>
              Highlight Words
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_ignore_list /></:icon>
              Ignore List
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_url_catcher /></:icon>
              URL Catcher
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_channel_central /></:icon>
              Channel Central
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_perform /></:icon>
              Perform
            </.menu_item>
            <.menu_separator />
            <.menu_item>
              <:icon><Icons.icon_btn_sounds /></:icon>
              Sounds
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_ctcp /></:icon>
              CTCP Settings
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_flood_protection /></:icon>
              Flood Protection
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_alias_editor /></:icon>
              Alias Editor
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_custom_menus /></:icon>
              Custom Menus
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_auto_respond /></:icon>
              Auto-Respond
            </.menu_item>
            <.menu_separator />
            <.menu_item>
              <:icon><Icons.icon_btn_settings /></:icon>
              Settings
            </.menu_item>
            <.menu_item>
              <:icon><Icons.icon_btn_bot_management /></:icon>
              Bot Management
            </.menu_item>
          </.menu>
        </div>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
