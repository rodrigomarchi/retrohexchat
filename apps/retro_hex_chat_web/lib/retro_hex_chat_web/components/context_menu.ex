defmodule RetroHexChatWeb.Components.ContextMenu do
  @moduledoc """
  Right-click context menu for nicknames in the nicklist.
  Shows PM/Whois for all users, op actions for operators.
  """
  use Phoenix.Component

  alias RetroHexChat.Chat.KeyBindings

  attr :custom_nicklist_items, :list, default: []
  attr :is_ignored, :boolean, default: false
  attr :key_bindings, :map, default: %{}
  attr :nick_color_fn, :any, default: nil
  attr :show_color_picker, :boolean, default: false
  attr :target_nick, :string, default: nil
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
      style={"position: fixed; left: #{@x}px; top: #{@y}px; z-index: 300;"}
    >
      <div class="window" style="padding: 2px;">
        <ul class="tree-view" style="margin: 0; padding: 2px;">
          <li data-testid="ctx-query" phx-click="context_query" phx-value-nick={@target_nick}>
            Query (PM) <.shortcut_hint bindings={@key_bindings} action={:open_pm} />
          </li>
          <li data-testid="ctx-whois" phx-click="context_whois" phx-value-nick={@target_nick}>
            Whois
          </li>
          <li class="separator" style="border-top: 1px solid #666; margin: 2px 0;"></li>
          <li
            data-testid="ctx-add-contact"
            phx-click="context_add_contact"
            phx-value-nick={@target_nick}
          >
            Add to Contacts
          </li>
          <li
            data-testid="ctx-set-nick-color"
            phx-click="context_set_nick_color"
            phx-value-nick={@target_nick}
          >
            Set Nick Color
          </li>
          <li
            :if={!@is_ignored}
            data-testid="ctx-ignore"
            phx-click="context_ignore"
            phx-value-nick={@target_nick}
          >
            Ignore
          </li>
          <li
            :if={@is_ignored}
            data-testid="ctx-unignore"
            phx-click="context_unignore"
            phx-value-nick={@target_nick}
          >
            Unignore
          </li>
          <li
            :if={@viewer_is_op}
            class="separator"
            style="border-top: 1px solid #666; margin: 2px 0;"
          >
          </li>
          <li
            :if={@viewer_is_op}
            data-testid="ctx-kick"
            phx-click="context_kick"
            phx-value-nick={@target_nick}
          >
            Kick
          </li>
          <li
            :if={@viewer_is_op}
            data-testid="ctx-ban"
            phx-click="context_ban"
            phx-value-nick={@target_nick}
          >
            Ban
          </li>
          <li
            :if={@viewer_is_op}
            data-testid="ctx-op"
            phx-click="context_op"
            phx-value-nick={@target_nick}
          >
            Give Op
          </li>
          <li
            :if={@viewer_is_op}
            data-testid="ctx-voice"
            phx-click="context_voice"
            phx-value-nick={@target_nick}
          >
            Give Voice
          </li>
          <li
            :if={@custom_nicklist_items != []}
            class="separator"
            style="border-top: 1px solid #666; margin: 2px 0;"
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
      style={"position: fixed; left: #{@x}px; top: #{@y + 30}px; z-index: 310;"}
    >
      <div class="window" style="padding: 4px;">
        <div style="font-size: 11px; margin-bottom: 4px; font-weight: bold;">
          Pick color for {@target_nick}
        </div>
        <div style="display: grid; grid-template-columns: repeat(8, 1fr); gap: 2px;">
          <button
            :for={{idx, hex} <- irc_color_list()}
            type="button"
            phx-click="context_pick_color"
            phx-value-color_index={idx}
            data-testid={"ctx-color-swatch-#{idx}"}
            style={"display: inline-block; width: 20px; height: 20px; border: 1px solid #808080; cursor: pointer; background: #{hex}; padding: 0;"}
          >
          </button>
        </div>
      </div>
    </div>
    """
  end

  @irc_colors %{
    0 => "#ffffff",
    1 => "#000000",
    2 => "#00007f",
    3 => "#009300",
    4 => "#ff0000",
    5 => "#7f0000",
    6 => "#9c009c",
    7 => "#fc7f00",
    8 => "#ffff00",
    9 => "#00fc00",
    10 => "#009393",
    11 => "#00ffff",
    12 => "#0000fc",
    13 => "#ff00ff",
    14 => "#7f7f7f",
    15 => "#d2d2d2"
  }

  @spec irc_color_list() :: [{non_neg_integer(), String.t()}]
  defp irc_color_list do
    for i <- 0..15, do: {i, Map.fetch!(@irc_colors, i)}
  end

  defp shortcut_hint(%{bindings: bindings, action: action} = assigns) do
    binding = Map.get(bindings, action)
    assigns = assign(assigns, :display, binding && KeyBindings.to_display_string(binding))

    ~H"""
    <span :if={@display} class="shortcut-hint">{@display}</span>
    """
  end
end
