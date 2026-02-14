defmodule RetroHexChatWeb.Components.HoverCard do
  @moduledoc """
  Nick hover card component with 98.css window styling.

  Shows user info (nickname, hostname, online duration, channels, away status)
  in a compact floating card positioned near the hovered nick element.
  """
  use Phoenix.Component

  attr :hover_card, :map, required: true

  @spec nick_hover_card(map()) :: Phoenix.LiveView.Rendered.t()
  def nick_hover_card(assigns) do
    ~H"""
    <div
      :if={@hover_card.visible}
      class={"nick-hover-card window#{if @hover_card.loading, do: " nick-hover-card--loading", else: ""}"}
      style={"position: fixed; left: #{@hover_card.x}px; top: #{@hover_card.y}px; z-index: var(--z-tooltip, 9999);"}
      data-testid="nick-hover-card"
    >
      <div class="title-bar">
        <div class="title-bar-text">
          {hover_card_title(@hover_card)}
        </div>
      </div>
      <div class="window-body">
        <%= if @hover_card.loading do %>
          <p class="nick-hover-card-loading">Loading...</p>
        <% else %>
          <.hover_card_content data={@hover_card.data} />
        <% end %>
      </div>
    </div>
    """
  end

  defp hover_card_content(%{data: nil} = assigns) do
    ~H"""
    <p class="nick-hover-card-loading">No data available</p>
    """
  end

  defp hover_card_content(assigns) do
    ~H"""
    <div class="nick-hover-card-fields">
      <div class="nick-hover-card-field">
        <span class="nick-hover-card-label">Nick:</span>
        <span class="nick-hover-card-value">{@data.nickname}</span>
        <span :if={@data.away} class="nick-hover-card-away" data-testid="away-badge">
          (away{if @data.away_message, do: ": #{@data.away_message}", else: ""})
        </span>
        <span :if={@data.registered} class="nick-hover-card-registered" title="Registered">✓</span>
      </div>
      <div :if={@data.hostname} class="nick-hover-card-field">
        <span class="nick-hover-card-label">Host:</span>
        <span class="nick-hover-card-value">{@data.hostname}</span>
      </div>
      <div class="nick-hover-card-field">
        <span class="nick-hover-card-label">Online:</span>
        <span class="nick-hover-card-value">{@data.online_for}</span>
      </div>
      <div :if={@data.channels != []} class="nick-hover-card-field">
        <span class="nick-hover-card-label">Channels:</span>
        <span class="nick-hover-card-channels">{Enum.join(@data.channels, ", ")}</span>
      </div>
    </div>
    <p class="nick-hover-card-hints">
      Click: insert nick | Double-click: PM | Right-click: menu
    </p>
    """
  end

  @spec hover_card_title(map()) :: String.t()
  defp hover_card_title(%{nick: nick}) when is_binary(nick), do: nick
  defp hover_card_title(_), do: "User Info"
end
