defmodule RetroHexChatWeb.Components.UI.NicklistContextMenu do
  @moduledoc """
  v2 context menu for right-clicking a nickname in the nicklist sidebar.

  Composed from ContextMenu primitives. Supports:
  - PM, Whois, Add to Contacts, Set Nick Color, Ignore/Unignore
  - P2P actions: Audio Call, Video Call, Send File, Play Game (if identified)
  - Operator actions: Kick, Ban, Give Op, Give Voice
  - Custom nicklist menu items
  - Inline nick color picker sub-panel

  All actions are dispatched through a single `on_action` callback with
  `phx-value-action` identifying the specific action.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ContextMenu

  alias RetroHexChatWeb.Icons

  attr :visible, :boolean, default: false
  attr :x, :integer, default: 0
  attr :y, :integer, default: 0
  attr :target_nick, :string, default: nil
  attr :viewer_nick, :string, default: nil
  attr :viewer_is_op, :boolean, default: false
  attr :viewer_is_identified, :boolean, default: false
  attr :is_target_ignored, :boolean, default: false
  attr :is_target_self, :boolean, default: false
  attr :show_color_picker, :boolean, default: false
  attr :nick_color_fn, :any, default: nil
  attr :custom_items, :list, default: []
  attr :on_action, :any, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec nicklist_context_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def nicklist_context_menu(assigns) do
    ~H"""
    <.context_menu id="nicklist-context-menu" show={@visible} x={@x} y={@y} class={@class} {@rest}>
      <%!-- Core actions --%>
      <.context_menu_item
        on_click={unless(@is_target_self, do: @on_action)}
        action="pm"
        disabled={@is_target_self}
        phx-value-nick={@target_nick}
      >
        <:icon><Icons.icon_tab_pm class="w-[14px] h-[14px]" /></:icon>
        Query (PM)
      </.context_menu_item>
      <.context_menu_item on_click={@on_action} action="whois" phx-value-nick={@target_nick}>
        <:icon><Icons.icon_btn_search class="w-[14px] h-[14px]" /></:icon>
        Whois
      </.context_menu_item>

      <.context_menu_separator />

      <.context_menu_item on_click={@on_action} action="add_contact" phx-value-nick={@target_nick}>
        <:icon><Icons.icon_tab_contacts class="w-[14px] h-[14px]" /></:icon>
        Add to Contacts
      </.context_menu_item>
      <.context_menu_item on_click={@on_action} action="set_nick_color" phx-value-nick={@target_nick}>
        <:icon><Icons.icon_btn_settings class="w-[14px] h-[14px]" /></:icon>
        Set Nick Color
      </.context_menu_item>

      <%!-- Inline color picker --%>
      <li :if={@show_color_picker} class="px-retro-8 py-retro-4">
        <div class="flex flex-wrap gap-retro-2 max-w-[168px]">
          <button
            :for={i <- 0..11}
            type="button"
            class={[
              "w-[18px] h-[18px] shadow-retro-raised cursor-pointer",
              "nick-color-#{i}"
            ]}
            phx-click={@on_action}
            phx-value-action="pick_color"
            phx-value-color_index={to_string(i)}
            phx-value-nick={@target_nick}
            data-testid={"color-swatch-#{i}"}
          />
        </div>
      </li>

      <.context_menu_item
        :if={!@is_target_self}
        on_click={@on_action}
        action={if @is_target_ignored, do: "unignore", else: "ignore"}
        phx-value-nick={@target_nick}
      >
        <:icon><Icons.icon_btn_ignore class="w-[14px] h-[14px]" /></:icon>
        {if @is_target_ignored, do: "Unignore", else: "Ignore"}
      </.context_menu_item>

      <%!-- P2P actions (only if viewer is identified) --%>
      <.context_menu_separator :if={@viewer_is_identified && !@is_target_self} />
      <.context_menu_item
        :if={@viewer_is_identified && !@is_target_self}
        on_click={@on_action}
        action="p2p_session"
        phx-value-nick={@target_nick}
      >
        <:icon><Icons.icon_p2p class="w-[14px] h-[14px]" /></:icon>
        P2P Session
      </.context_menu_item>
      <.context_menu_item
        :if={@viewer_is_identified && !@is_target_self}
        on_click={@on_action}
        action="audio_call"
        phx-value-nick={@target_nick}
      >
        <:icon><Icons.icon_microphone class="w-[14px] h-[14px]" /></:icon>
        Audio Call
      </.context_menu_item>
      <.context_menu_item
        :if={@viewer_is_identified && !@is_target_self}
        on_click={@on_action}
        action="video_call"
        phx-value-nick={@target_nick}
      >
        <:icon><Icons.icon_camera class="w-[14px] h-[14px]" /></:icon>
        Video Call
      </.context_menu_item>
      <.context_menu_item
        :if={@viewer_is_identified && !@is_target_self}
        on_click={@on_action}
        action="send_file"
        phx-value-nick={@target_nick}
      >
        <:icon><Icons.icon_file_send class="w-[14px] h-[14px]" /></:icon>
        Send File
      </.context_menu_item>
      <.context_menu_item
        :if={@viewer_is_identified && !@is_target_self}
        on_click={@on_action}
        action="play_game"
        phx-value-nick={@target_nick}
      >
        <:icon><Icons.icon_star class="w-[14px] h-[14px]" /></:icon>
        Play Game
      </.context_menu_item>

      <%!-- Op actions (only if viewer is op and not targeting self) --%>
      <.context_menu_separator :if={@viewer_is_op && !@is_target_self} />
      <.context_menu_item
        :if={@viewer_is_op && !@is_target_self}
        on_click={@on_action}
        action="kick"
        phx-value-nick={@target_nick}
      >
        <:icon><Icons.icon_dialog_kick class="w-[14px] h-[14px]" /></:icon>
        Kick
      </.context_menu_item>
      <.context_menu_item
        :if={@viewer_is_op && !@is_target_self}
        on_click={@on_action}
        action="ban"
        phx-value-nick={@target_nick}
      >
        <:icon><Icons.icon_ban class="w-[14px] h-[14px]" /></:icon>
        Ban
      </.context_menu_item>
      <.context_menu_item
        :if={@viewer_is_op && !@is_target_self}
        on_click={@on_action}
        action="give_voice"
        phx-value-nick={@target_nick}
      >
        <:icon><Icons.icon_role_voiced class="w-[14px] h-[14px]" /></:icon>
        Give Voice (+v)
      </.context_menu_item>
      <.context_menu_item
        :if={@viewer_is_op && !@is_target_self}
        on_click={@on_action}
        action="give_op"
        phx-value-nick={@target_nick}
      >
        <:icon><Icons.icon_role_operator class="w-[14px] h-[14px]" /></:icon>
        Give Op (+o)
      </.context_menu_item>

      <%!-- Custom nicklist items --%>
      <.context_menu_separator :if={@custom_items != []} />
      <.context_menu_item
        :for={item <- @custom_items}
        on_click={@on_action}
        action={item[:label]}
        phx-value-nick={@target_nick}
        phx-value-command={item[:command]}
      >
        <:icon><Icons.icon_btn_star class="w-[14px] h-[14px]" /></:icon>
        {item[:label]}
      </.context_menu_item>
    </.context_menu>
    """
  end
end
