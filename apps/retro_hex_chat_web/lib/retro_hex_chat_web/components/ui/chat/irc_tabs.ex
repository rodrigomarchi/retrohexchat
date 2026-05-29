defmodule RetroHexChatWeb.Components.UI.IrcTabs do
  @moduledoc false
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders an IRC-style tab bar container."
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec irc_tab_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def irc_tab_bar(assigns) do
    ~H"""
    <div
      class={
        classes([
          "flex gap-0 px-1 pt-[2px] bg-surface border-b border-border items-end overflow-x-auto",
          @class
        ])
      }
      role="tablist"
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Renders an individual IRC tab item."
  attr :active, :boolean, default: false
  attr :unread, :boolean, default: false
  attr :type, :string, values: ~w(channel pm status), default: "channel"
  attr :label, :string, required: true
  attr :closeable, :boolean, default: true
  attr :nick_color, :string, default: nil, doc: "CSS class for nick coloring (PM tabs)"
  attr :on_click, :any, default: nil, doc: "Tab click callback"
  attr :on_close, :any, default: nil, doc: "Close button callback"
  attr :class, :any, default: nil
  attr :rest, :global

  @spec irc_tab_item(map()) :: Phoenix.LiveView.Rendered.t()
  def irc_tab_item(assigns) do
    ~H"""
    <div
      role="tab"
      aria-selected={to_string(@active)}
      data-unread={to_string(@unread)}
      phx-click={@on_click}
      phx-value-type={@type}
      phx-value-label={@label}
      class={
        classes([
          "inline-flex items-center gap-1 px-2 py-[2px] text-sm cursor-pointer select-none",
          "border border-border mr-[1px] relative top-[1px]",
          if(@active,
            do: "bg-surface border-b-surface font-bold",
            else: "bg-gray-300"
          ),
          @unread && !@active && "font-bold",
          @type == "pm" && "italic",
          @class
        ])
      }
      {@rest}
    >
      <span class="w-4 h-4 flex-shrink-0 inline-flex items-center justify-center">
        {type_icon(assigns)}
      </span>
      <span class={[
        "inline-block max-w-[16ch] overflow-hidden text-ellipsis whitespace-nowrap",
        !@active && @nick_color
      ]}>
        {@label}
      </span>
      <.button
        :if={@closeable}
        type="button"
        variant="ghost"
        size="icon"
        aria-label="Close tab"
        phx-click={@on_close}
        phx-value-type={@type}
        phx-value-label={@label}
        class={[
          "w-[14px] min-w-[14px] h-[14px] min-h-[14px]",
          "p-0 text-[10px] leading-none border border-gray-400 bg-gray-300",
          "ml-[2px] hover:bg-destructive hover:text-white hover:border-destructive"
        ]}
      >
        <:icon><Icons.icon_close class="w-3 h-3" /></:icon>
      </.button>
    </div>
    """
  end

  defp type_icon(%{type: "channel"} = assigns) do
    ~H'<Icons.icon_tab_channel class="w-[16px] h-[16px]" />'
  end

  defp type_icon(%{type: "pm"} = assigns) do
    ~H'<Icons.icon_tab_pm class="w-[16px] h-[16px]" />'
  end

  defp type_icon(%{type: "status"} = assigns) do
    ~H'<Icons.icon_tab_status class="w-[16px] h-[16px]" />'
  end
end
