defmodule RetroHexChatWeb.Components.UI.ToolbarApp do
  @moduledoc false
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  import RetroHexChatWeb.Components.UI.ContextMenu
  import RetroHexChatWeb.Components.UI.Toolbar

  @doc """
  Renders a full application toolbar with connection, options dropdown, and help groups.

  Based on the platform toolbar with 3 button groups: Connection, Options (dropdown),
  and Help. All button actions go through a single `on_action` callback with
  `phx-value-action` identifying the action.
  """
  attr :connected, :boolean, default: false
  attr :is_admin, :boolean, default: false
  attr :on_action, :any, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec toolbar_app(map()) :: Phoenix.LiveView.Rendered.t()
  def toolbar_app(assigns) do
    ~H"""
    <.toolbar class={classes(["hidden md:flex", @class])} {@rest}>
      <%!-- Group 1: Connection --%>
      <.toolbar_button
        :if={!@connected}
        label="Connect"
        phx-click={@on_action}
        phx-value-action="restore_session"
      >
        <Icons.icon_btn_connect_lightning class="w-[16px] h-[16px]" />
      </.toolbar_button>
      <.toolbar_button
        :if={@connected}
        label="Disconnect"
        phx-click={@on_action}
        phx-value-action="disconnect"
      >
        <Icons.icon_btn_disconnect class="w-[16px] h-[16px]" />
      </.toolbar_button>

      <.toolbar_separator />

      <%!-- Group 2: Options (dropdown) --%>
      <div class="toolbar-group relative">
        <.toolbar_button label="Options" class="toolbar-group-toggle" data-toolbar-group="options">
          <Icons.icon_group_tools class="w-[32px] h-[32px]" />
        </.toolbar_button>
        <div class="toolbar-group-dropdown u-hidden absolute left-0 top-full z-50 shadow-retro-raised bg-surface p-1 min-w-[200px]">
          <%!-- View items --%>
          <.dropdown_item
            icon_fn={:icon_btn_channel_list}
            label="Channel List"
            action="toggle_channel_list"
            on_action={@on_action}
          />
          <.dropdown_item
            icon_fn={:icon_btn_toggle_conversations}
            label="Toggle Conversations"
            action="toggle_conversations"
            on_action={@on_action}
          />
          <.dropdown_item
            icon_fn={:icon_btn_toggle_nicklist}
            label="Toggle Nicklist"
            action="toggle_nicklist"
            on_action={@on_action}
          />
          <.dropdown_item
            icon_fn={:icon_btn_find}
            label="Find"
            action="toggle_search"
            on_action={@on_action}
          />

          <hr class="my-1 border-t border-gray-400" />

          <%!-- Tool items --%>
          <.dropdown_item
            icon_fn={:icon_btn_address_book}
            label="Address Book"
            action="toggle_address_book"
            on_action={@on_action}
          />
          <.dropdown_item
            icon_fn={:icon_btn_highlight_words}
            label="Highlight Words"
            action="open_highlight_dialog"
            on_action={@on_action}
          />
          <.dropdown_item
            icon_fn={:icon_btn_url_catcher}
            label="URL Catcher"
            action="toggle_url_catcher"
            on_action={@on_action}
          />
          <.dropdown_item
            icon_fn={:icon_btn_channel_central}
            label="Channel Central"
            action="open_channel_central"
            on_action={@on_action}
          />
          <.dropdown_item
            icon_fn={:icon_btn_perform}
            label="Perform"
            action="open_perform_dialog"
            on_action={@on_action}
          />
          <.dropdown_item
            icon_fn={:icon_btn_sounds}
            label="Sounds"
            action="open_sound_settings_dialog"
            on_action={@on_action}
          />
          <.dropdown_item
            icon_fn={:icon_btn_ctcp}
            label="CTCP"
            action="open_ctcp_settings_dialog"
            on_action={@on_action}
          />
          <.dropdown_item
            icon_fn={:icon_btn_flood_protection}
            label="Flood Protection"
            action="open_flood_protection_dialog"
            on_action={@on_action}
          />
          <.dropdown_item
            icon_fn={:icon_btn_alias_editor}
            label="Alias Editor"
            action="open_alias_dialog"
            on_action={@on_action}
          />
          <.dropdown_item
            icon_fn={:icon_btn_custom_menus}
            label="Custom Menus"
            action="open_custom_menus_dialog"
            on_action={@on_action}
          />
          <.dropdown_item
            icon_fn={:icon_btn_auto_respond}
            label="Auto Respond"
            action="open_autorespond_dialog"
            on_action={@on_action}
          />
          <%!-- Admin (conditional) --%>
          <.dropdown_item
            :if={@is_admin}
            icon_fn={:icon_dialog_admin_console}
            label="Admin Console"
            action="open_admin_console"
            on_action={@on_action}
          />
        </div>
      </div>

      <.toolbar_separator />

      <%!-- Group 3: Help --%>
      <.toolbar_button
        label="Help Topics"
        phx-click={@on_action}
        phx-value-action="help_topics"
      >
        <Icons.icon_group_help class="w-[32px] h-[32px]" />
      </.toolbar_button>
    </.toolbar>
    """
  end

  # ── Private helpers ──────────────────────────────────────

  attr :icon_fn, :atom, required: true
  attr :label, :string, required: true
  attr :action, :string, required: true
  attr :on_action, :any, default: nil

  defp dropdown_item(assigns) do
    ~H"""
    <.context_menu_item on_click={@on_action} action={@action}>
      <:icon>{apply(Icons, @icon_fn, [%{class: "w-[14px] h-[14px]"}])}</:icon>
      {@label}
    </.context_menu_item>
    """
  end
end
