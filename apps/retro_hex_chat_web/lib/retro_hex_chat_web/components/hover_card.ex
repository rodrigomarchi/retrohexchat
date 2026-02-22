defmodule RetroHexChatWeb.Components.HoverCard do
  @moduledoc """
  Nick hover card component with 98.css window styling.

  Shows user info (nickname, hostname, online duration, channels, away status,
  role, contact/ignore badges) in a compact floating card positioned near the
  hovered nick element.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

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
          <Icons.icon_status_user class="hover-card-title-icon" />
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
        <Icons.icon_tab_contacts class="hover-card-icon" />
        <span class="nick-hover-card-label">Nick:</span>
        <span class="nick-hover-card-value">{@data.nickname}</span>
        <span :if={@data.registered} class="nick-hover-card-registered" title="Registered">
          ✓
        </span>
        <.role_badge role={@data[:role]} />
      </div>
      <div :if={@data.away} class="nick-hover-card-field">
        <Icons.icon_warning class="hover-card-icon" />
        <span class="nick-hover-card-away" data-testid="away-badge">
          Away{if @data.away_message, do: ": #{@data.away_message}", else: ""}
        </span>
      </div>
      <div :if={@data.hostname} class="nick-hover-card-field">
        <Icons.icon_server class="hover-card-icon" />
        <span class="nick-hover-card-label">Host:</span>
        <span class="nick-hover-card-value">{@data.hostname}</span>
      </div>
      <div class="nick-hover-card-field">
        <Icons.icon_clock class="hover-card-icon" />
        <span class="nick-hover-card-label">Online:</span>
        <span class="nick-hover-card-value">{@data.online_for}</span>
      </div>
      <div :if={@data.channels != []} class="nick-hover-card-field">
        <Icons.icon_channels class="hover-card-icon" />
        <span class="nick-hover-card-label">Channels:</span>
        <span class="nick-hover-card-channels">{Enum.join(@data.channels, ", ")}</span>
      </div>
      <div class="nick-hover-card-badges">
        <span class={contact_badge_class(@data[:is_contact])}>
          <Icons.icon_tab_contacts class="hover-card-badge-icon" />
          {if @data[:is_contact], do: "Contact", else: "Not a contact"}
        </span>
        <span class={ignore_badge_class(@data[:is_ignored])}>
          <Icons.icon_btn_ignore class="hover-card-badge-icon" />
          {if @data[:is_ignored], do: "Ignored", else: "Not ignored"}
        </span>
      </div>
    </div>
    <p class="nick-hover-card-hints">
      Click: insert nick | Double-click: PM | Right-click: menu
    </p>
    """
  end

  @spec contact_badge_class(boolean() | nil) :: String.t()
  defp contact_badge_class(true), do: "hover-card-badge hover-card-badge--contact"
  defp contact_badge_class(_), do: "hover-card-badge hover-card-badge--inactive"

  @spec ignore_badge_class(boolean() | nil) :: String.t()
  defp ignore_badge_class(true), do: "hover-card-badge hover-card-badge--ignored"
  defp ignore_badge_class(_), do: "hover-card-badge hover-card-badge--inactive"

  defp role_badge(%{role: nil} = assigns), do: ~H""
  defp role_badge(%{role: :regular} = assigns), do: ~H""

  defp role_badge(assigns) do
    ~H"""
    <span class={"hover-card-role hover-card-role--#{@role}"} title={role_label(@role)}>
      <.role_icon role={@role} />
      {role_label(@role)}
    </span>
    """
  end

  defp role_icon(%{role: :owner} = assigns),
    do: ~H|<Icons.icon_role_owner class="hover-card-role-icon" />|

  defp role_icon(%{role: :operator} = assigns),
    do: ~H|<Icons.icon_role_operator class="hover-card-role-icon" />|

  defp role_icon(%{role: :half_operator} = assigns),
    do: ~H|<Icons.icon_role_halfop class="hover-card-role-icon" />|

  defp role_icon(%{role: :voiced} = assigns),
    do: ~H|<Icons.icon_role_voiced class="hover-card-role-icon" />|

  defp role_icon(assigns), do: ~H""

  @spec role_label(atom()) :: String.t()
  defp role_label(:owner), do: "Owner"
  defp role_label(:operator), do: "Operator"
  defp role_label(:half_operator), do: "Half-Op"
  defp role_label(:voiced), do: "Voiced"
  defp role_label(_), do: ""

  @spec hover_card_title(map()) :: String.t()
  defp hover_card_title(%{nick: nick}) when is_binary(nick), do: nick
  defp hover_card_title(_), do: "User Info"
end
