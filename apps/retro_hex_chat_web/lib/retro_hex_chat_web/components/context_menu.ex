defmodule RetroHexChatWeb.Components.ContextMenu do
  @moduledoc """
  Right-click context menu for nicknames in the nicklist.
  Shows PM/Whois for all users, op actions for operators.
  """
  use Phoenix.Component

  alias RetroHexChat.Chat.KeyBindings
  alias RetroHexChatWeb.Icons

  attr :custom_nicklist_items, :list, default: []
  attr :is_ignored, :boolean, default: false
  attr :is_target_registered, :boolean, default: false
  attr :is_target_self, :boolean, default: false
  attr :key_bindings, :map, default: %{}
  attr :nick_color_fn, :any, default: nil
  attr :show_color_picker, :boolean, default: false
  attr :target_nick, :string, default: nil
  attr :viewer_is_identified, :boolean, default: false
  attr :viewer_is_op, :boolean, default: false
  attr :visible, :boolean, default: false
  attr :x, :integer, default: 0
  attr :y, :integer, default: 0

  @spec context_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def context_menu(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="context-menu"
      style={"left: #{@x}px; top: #{@y}px;"}
    >
      <div class="window u-p-2">
        <ul class="tree-view">
          <li data-testid="ctx-query" phx-click="context_query" phx-value-nick={@target_nick}>
            <Icons.icon_tab_pm class="ctx-icon" /> Query (PM)
            <.shortcut_hint bindings={@key_bindings} action={:open_pm} />
          </li>
          <li data-testid="ctx-whois" phx-click="context_whois" phx-value-nick={@target_nick}>
            <Icons.icon_btn_search class="ctx-icon" /> Whois
          </li>
          <li class="separator"></li>
          <li
            data-testid="ctx-add-contact"
            phx-click="context_add_contact"
            phx-value-nick={@target_nick}
          >
            <Icons.icon_tab_contacts class="ctx-icon" /> Add to Contacts
          </li>
          <li
            data-testid="ctx-set-nick-color"
            phx-click="context_set_nick_color"
            phx-value-nick={@target_nick}
          >
            <Icons.icon_palette class="ctx-icon" /> Set Nick Color
          </li>
          <li
            :if={!@is_ignored}
            data-testid="ctx-ignore"
            phx-click="context_ignore"
            phx-value-nick={@target_nick}
          >
            <Icons.icon_btn_ignore class="ctx-icon" /> Ignore
          </li>
          <li
            :if={@is_ignored}
            data-testid="ctx-unignore"
            phx-click="context_unignore"
            phx-value-nick={@target_nick}
          >
            <Icons.icon_btn_ignore class="ctx-icon" /> Unignore
          </li>
          <li :if={@viewer_is_identified} class="separator"></li>
          <li
            :if={@viewer_is_identified}
            class={if !@is_target_registered || @is_target_self, do: "disabled"}
            title={if !@is_target_registered && !@is_target_self, do: "User not registered"}
            data-testid="context-p2p"
            phx-click={if @is_target_registered && !@is_target_self, do: "context_p2p"}
            phx-value-nick={@target_nick}
          >
            <Icons.icon_p2p class="ctx-icon" /> P2P Session
          </li>
          <li
            :if={@viewer_is_identified}
            class={if !@is_target_registered || @is_target_self, do: "disabled"}
            title={if !@is_target_registered && !@is_target_self, do: "User not registered"}
            data-testid="context-call"
            phx-click={if @is_target_registered && !@is_target_self, do: "context_call"}
            phx-value-nick={@target_nick}
          >
            <Icons.icon_microphone class="ctx-icon" /> Audio Call
          </li>
          <li
            :if={@viewer_is_identified}
            class={if !@is_target_registered || @is_target_self, do: "disabled"}
            title={if !@is_target_registered && !@is_target_self, do: "User not registered"}
            data-testid="context-video-call"
            phx-click={if @is_target_registered && !@is_target_self, do: "context_video_call"}
            phx-value-nick={@target_nick}
          >
            <Icons.icon_camera class="ctx-icon" /> Video Call
          </li>
          <li
            :if={@viewer_is_identified}
            class={if !@is_target_registered || @is_target_self, do: "disabled"}
            title={if !@is_target_registered && !@is_target_self, do: "User not registered"}
            data-testid="context-sendfile"
            phx-click={if @is_target_registered && !@is_target_self, do: "context_sendfile"}
            phx-value-nick={@target_nick}
          >
            <Icons.icon_file_send class="ctx-icon" /> Send File
          </li>
          <li
            :if={@viewer_is_identified}
            class={if !@is_target_registered || @is_target_self, do: "disabled"}
            title={if !@is_target_registered && !@is_target_self, do: "User not registered"}
            data-testid="context-game"
            phx-click={if @is_target_registered && !@is_target_self, do: "context_game"}
            phx-value-nick={@target_nick}
          >
            <Icons.icon_star class="ctx-icon" /> Play Game
          </li>
          <li
            :if={@viewer_is_op}
            class="separator"
          >
          </li>
          <li
            :if={@viewer_is_op}
            data-testid="ctx-kick"
            phx-click="context_kick"
            phx-value-nick={@target_nick}
          >
            <Icons.icon_dialog_kick class="ctx-icon" /> Kick
          </li>
          <li
            :if={@viewer_is_op}
            data-testid="ctx-ban"
            phx-click="context_ban"
            phx-value-nick={@target_nick}
          >
            <Icons.icon_ban class="ctx-icon" /> Ban
          </li>
          <li
            :if={@viewer_is_op}
            data-testid="ctx-op"
            phx-click="context_op"
            phx-value-nick={@target_nick}
          >
            <Icons.icon_role_operator class="ctx-icon" /> Give Op
          </li>
          <li
            :if={@viewer_is_op}
            data-testid="ctx-voice"
            phx-click="context_voice"
            phx-value-nick={@target_nick}
          >
            <Icons.icon_role_voiced class="ctx-icon" /> Give Voice
          </li>
          <li
            :if={@custom_nicklist_items != []}
            class="separator"
          >
          </li>
          <li
            :for={item <- @custom_nicklist_items}
            data-testid={"ctx-custom-#{item.label}"}
            phx-click="custom_menu_execute"
            phx-value-command={item.command}
            phx-value-target={@target_nick}
          >
            {item.label}
          </li>
        </ul>
      </div>
    </div>
    <div
      :if={@show_color_picker}
      class="context-color-picker"
      data-testid="ctx-color-picker"
      style={"left: #{@x}px; top: #{@y + 30}px;"}
    >
      <div class="window u-p-4">
        <div class="u-text-sm u-mb-4 u-text-bold">
          Pick color for {@target_nick}
        </div>
        <div class="ab-color-grid">
          <button
            :for={idx <- 0..15}
            type="button"
            phx-click="context_pick_color"
            phx-value-color_index={idx}
            data-testid={"ctx-color-swatch-#{idx}"}
            class={"nick-palette-swatch irc-bg-#{idx}"}
          >
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp shortcut_hint(%{bindings: bindings, action: action} = assigns) do
    binding = Map.get(bindings, action)
    assigns = assign(assigns, :display, binding && KeyBindings.to_display_string(binding))

    ~H"""
    <span :if={@display} class="shortcut-hint">{@display}</span>
    """
  end
end
