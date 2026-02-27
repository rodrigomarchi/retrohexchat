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
  attr :tabs, :list, default: []
  attr :class, :string, default: nil
  attr :rest, :global

  @spec tab_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def tab_bar(assigns) do
    ~H"""
    <.irc_tab_bar class={@class} {@rest}>
      <.irc_tab_item
        :for={tab <- @tabs}
        type={to_string(tab.type)}
        label={tab.label}
        active={Map.get(tab, :active, false)}
        unread={Map.get(tab, :unread, false)}
        closeable={Map.get(tab, :closeable, tab.type != :status)}
      />
    </.irc_tab_bar>
    """
  end
end
