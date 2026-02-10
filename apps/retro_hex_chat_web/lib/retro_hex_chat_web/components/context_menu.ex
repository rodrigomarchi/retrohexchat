defmodule RetroHexChatWeb.Components.ContextMenu do
  @moduledoc """
  Right-click context menu for nicknames in the nicklist.
  Shows PM/Whois for all users, op actions for operators.
  """
  use Phoenix.Component

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
          <li phx-click="context_query" phx-value-nick={@target_nick}>Query (PM)</li>
          <li phx-click="context_whois" phx-value-nick={@target_nick}>Whois</li>
          <li
            :if={@viewer_is_op}
            class="separator"
            style="border-top: 1px solid #666; margin: 2px 0;"
          >
          </li>
          <li :if={@viewer_is_op} phx-click="context_kick" phx-value-nick={@target_nick}>
            Kick
          </li>
          <li :if={@viewer_is_op} phx-click="context_ban" phx-value-nick={@target_nick}>
            Ban
          </li>
          <li :if={@viewer_is_op} phx-click="context_op" phx-value-nick={@target_nick}>
            Give Op
          </li>
          <li :if={@viewer_is_op} phx-click="context_voice" phx-value-nick={@target_nick}>
            Give Voice
          </li>
        </ul>
      </div>
    </div>
    """
  end
end
