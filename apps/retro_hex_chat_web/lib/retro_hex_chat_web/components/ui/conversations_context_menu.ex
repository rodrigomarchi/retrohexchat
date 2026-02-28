defmodule RetroHexChatWeb.Components.UI.ConversationsContextMenu do
  @moduledoc """
  Context menu for the conversations sidebar.

  Renders a positioned context menu with standard channel actions
  (mark as read, mute/unmute, copy name, leave, settings) plus
  optional custom items.

  ## Usage

      <.conversations_context_menu
        visible={true}
        x={120}
        y={80}
        channel="#lobby"
        has_unread={true}
        on_action="handle_ctx_action"
      />
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  @doc "Renders the conversations context menu."
  attr :visible, :boolean, default: false
  attr :x, :integer, default: 0
  attr :y, :integer, default: 0
  attr :channel, :string, default: nil
  attr :is_muted, :boolean, default: false
  attr :has_unread, :boolean, default: false
  attr :custom_items, :list, default: []
  attr :on_action, :any, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec conversations_context_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def conversations_context_menu(assigns) do
    ~H"""
    <div
      :if={@visible}
      class={[
        "absolute z-50 shadow-retro-window bg-surface min-w-[160px] text-xs",
        @class
      ]}
      style={position_style(@x, @y)}
      data-testid="conversations-context-menu"
      {@rest}
    >
      <ul class="list-none m-0 p-0">
        <%!-- Mark as Read --%>
        <li>
          <button
            type="button"
            class={[
              "flex items-center gap-retro-4 w-full px-retro-8 py-retro-4 text-left",
              if(@has_unread,
                do: "hover:bg-primary hover:text-white active:bg-primary",
                else: "opacity-50 cursor-default pointer-events-none"
              )
            ]}
            phx-click={@has_unread && @on_action}
            phx-value-action="mark_read"
            phx-value-channel={@channel}
            disabled={!@has_unread}
            data-testid="ctx-mark-read"
          >
            <Icons.icon_checkmark class="w-3 h-3 shrink-0" /> Mark as Read
          </button>
        </li>

        <%!-- Mute / Unmute --%>
        <li>
          <button
            type="button"
            class="flex items-center gap-retro-4 w-full px-retro-8 py-retro-4 text-left hover:bg-primary hover:text-white active:bg-primary"
            phx-click={@on_action}
            phx-value-action={if @is_muted, do: "unmute", else: "mute"}
            phx-value-channel={@channel}
            data-testid="ctx-mute-toggle"
          >
            <Icons.icon_mute :if={@is_muted} class="w-3 h-3 shrink-0" />
            <Icons.icon_dialog_sound :if={!@is_muted} class="w-3 h-3 shrink-0" />
            {if @is_muted, do: "Unmute Channel", else: "Mute Channel"}
          </button>
        </li>

        <%!-- Separator --%>
        <li class="border-t border-border my-[1px]" role="separator" />

        <%!-- Copy Channel Name --%>
        <li>
          <button
            type="button"
            class="flex items-center gap-retro-4 w-full px-retro-8 py-retro-4 text-left hover:bg-primary hover:text-white active:bg-primary"
            phx-click={@on_action}
            phx-value-action="copy_name"
            phx-value-channel={@channel}
            data-testid="ctx-copy-name"
          >
            <Icons.icon_copy class="w-3 h-3 shrink-0" /> Copy Channel Name
          </button>
        </li>

        <%!-- Channel Settings --%>
        <li>
          <button
            type="button"
            class="flex items-center gap-retro-4 w-full px-retro-8 py-retro-4 text-left hover:bg-primary hover:text-white active:bg-primary"
            phx-click={@on_action}
            phx-value-action="channel_settings"
            phx-value-channel={@channel}
            data-testid="ctx-channel-settings"
          >
            <Icons.icon_btn_settings class="w-3 h-3 shrink-0" /> Channel Settings
          </button>
        </li>

        <%!-- Separator --%>
        <li class="border-t border-border my-[1px]" role="separator" />

        <%!-- Leave Channel --%>
        <li>
          <button
            type="button"
            class="flex items-center gap-retro-4 w-full px-retro-8 py-retro-4 text-left hover:bg-error hover:text-white active:bg-error"
            phx-click={@on_action}
            phx-value-action="leave"
            phx-value-channel={@channel}
            data-testid="ctx-leave"
          >
            <Icons.icon_btn_disconnect class="w-3 h-3 shrink-0" /> Leave Channel
          </button>
        </li>

        <%!-- Custom items --%>
        <li :if={@custom_items != []} class="border-t border-border my-[1px]" role="separator" />
        <li :for={item <- @custom_items}>
          <button
            type="button"
            class="flex items-center gap-retro-4 w-full px-retro-8 py-retro-4 text-left hover:bg-primary hover:text-white active:bg-primary"
            phx-click={@on_action}
            phx-value-action={item[:action]}
            phx-value-channel={@channel}
          >
            {item[:label]}
          </button>
        </li>
      </ul>
    </div>
    """
  end

  # ── Private helpers ───────────────────────────────────

  @spec position_style(integer(), integer()) :: String.t()
  defp position_style(x, y), do: "left: #{x}px; top: #{y}px;"
end
