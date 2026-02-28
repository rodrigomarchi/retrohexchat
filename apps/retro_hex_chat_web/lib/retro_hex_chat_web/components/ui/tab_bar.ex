defmodule RetroHexChatWeb.Components.UI.TabBar do
  @moduledoc """
  Tab bar component for the showcase design system.

  Composed from irc_tabs primitives.
  Status + channel + PM tabs with close button, unread indicator,
  and active tab styling.

  ## Usage

      <.tab_bar
        tabs={[
          %{type: :status, label: "Status", active: true},
          %{type: :channel, label: "#lobby", unread: true},
          %{type: :pm, label: "alice"}
        ]}
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.IrcTabs

  @doc "Renders the tab bar."
  attr :id, :string, default: nil
  attr :tabs, :list, default: []
  attr :on_tab_click, :any, default: nil, doc: "Tab click callback"
  attr :on_tab_close, :any, default: nil, doc: "Tab close button callback"
  attr :class, :string, default: nil
  attr :rest, :global

  @spec tab_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def tab_bar(assigns) do
    ~H"""
    <.irc_tab_bar id={@id} class={@class} data-testid="tab-bar" {@rest}>
      <.irc_tab_item
        :for={tab <- @tabs}
        type={to_string(tab.type)}
        label={tab.label}
        active={Map.get(tab, :active, false)}
        unread={Map.get(tab, :unread, false)}
        closeable={Map.get(tab, :closeable, tab.type != :status)}
        on_click={@on_tab_click}
        on_close={@on_tab_close}
      />
    </.irc_tab_bar>
    """
  end
end
