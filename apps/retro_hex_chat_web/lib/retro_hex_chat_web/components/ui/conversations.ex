defmodule RetroHexChatWeb.Components.UI.Conversations do
  @moduledoc """
  Conversations sidebar component for the showcase design system.

  Composed from tree_view + badge + empty_state primitives.
  Displays channels, private messages, and popular channels in
  collapsible sections with 6 visual states.

  ## Usage

      <.conversations
        channels={@channels}
        active_channel="#lobby"
        pm_conversations={@pms}
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.TreeView
  import RetroHexChatWeb.Components.UI.EmptyState

  alias RetroHexChatWeb.Icons

  # ── Main Component ─────────────────────────────────────

  @doc "Renders the conversations sidebar with channel/PM/popular sections."
  attr :channels, :list, default: []
  attr :active_channel, :string, default: nil
  attr :unread_channels, :list, default: []
  attr :highlight_channels, :list, default: []
  attr :muted_channels, :list, default: []
  attr :pm_conversations, :list, default: []
  attr :active_pm, :string, default: nil
  attr :unread_pms, :list, default: []
  attr :channel_users, :list, default: []
  attr :popular_channels, :list, default: []
  attr :class, :string, default: nil
  attr :rest, :global

  @spec conversations(map()) :: Phoenix.LiveView.Rendered.t()
  def conversations(assigns) do
    ~H"""
    <div class={classes(["flex flex-col", @class])} {@rest}>
      <%!-- Header tab --%>
      <div class="flex items-center bg-surface shadow-retro-raised px-retro-4 py-retro-2">
        <Icons.icon_tab_conversations class="w-4 h-4 mr-retro-4" />
        <span class="text-xs font-bold flex-1">Conversations</span>
      </div>

      <%!-- Tree content --%>
      <.tree_view class="flex-1 retro-scrollbar">
        <%= if @channels == [] and @pm_conversations == [] do %>
          <.empty_state>
            <:icon><Icons.icon_channels class="w-6 h-6" /></:icon>
            <:title>No channels</:title>
            <:description>/join #channel to get started</:description>
          </.empty_state>
        <% else %>
          <%!-- My Channels --%>
          <.tree_view_group label="MY CHANNELS">
            <.channel_item
              :for={ch <- @channels}
              name={ch}
              active={ch == @active_channel}
              unread={ch in @unread_channels}
              highlight={ch in @highlight_channels}
              muted={ch in @muted_channels}
            />
            <%!-- Users under active channel --%>
            <div :if={@channel_users != []} class="ml-2 mt-retro-2">
              <.user_item :for={user <- @channel_users} user={user} />
            </div>
          </.tree_view_group>

          <%!-- Private Messages --%>
          <.tree_view_group :if={@pm_conversations != []} label="PRIVATE MESSAGES">
            <.pm_item
              :for={pm <- @pm_conversations}
              nick={pm}
              active={pm == @active_pm}
              unread={pm in @unread_pms}
            />
          </.tree_view_group>

          <%!-- Popular Channels --%>
          <.tree_view_group :if={@popular_channels != []} label="POPULAR CHANNELS" open={false}>
            <.tree_view_item :for={ch <- @popular_channels}>
              <:icon><Icons.icon_channels class="w-3 h-3" /></:icon>
              {ch}
            </.tree_view_item>
          </.tree_view_group>
        <% end %>
      </.tree_view>
    </div>
    """
  end

  # ── Channel Item ───────────────────────────────────────

  attr :name, :string, required: true
  attr :active, :boolean, default: false
  attr :unread, :boolean, default: false
  attr :highlight, :boolean, default: false
  attr :muted, :boolean, default: false

  defp channel_item(assigns) do
    ~H"""
    <.tree_view_item
      active={@active}
      class={[
        @unread && !@active && "font-bold",
        @highlight && !@active && "text-error",
        @muted && "opacity-50"
      ]}
    >
      <:icon><Icons.icon_tab_channel class="w-3 h-3" /></:icon>
      <span class="flex-1 truncate">{@name}</span>
      <span :if={@unread && !@active} class="w-2 h-2 rounded-full bg-link shrink-0" />
    </.tree_view_item>
    """
  end

  # ── PM Item ────────────────────────────────────────────

  attr :nick, :string, required: true
  attr :active, :boolean, default: false
  attr :unread, :boolean, default: false

  defp pm_item(assigns) do
    ~H"""
    <.tree_view_item
      active={@active}
      class={[@unread && !@active && "font-bold italic"]}
    >
      <:icon><Icons.icon_tab_pm class="w-3 h-3" /></:icon>
      <span class="truncate">{@nick}</span>
      <span :if={@unread && !@active} class="w-2 h-2 rounded-full bg-link shrink-0" />
    </.tree_view_item>
    """
  end

  # ── User Item ──────────────────────────────────────────

  attr :user, :map, required: true

  defp user_item(assigns) do
    ~H"""
    <.tree_view_item>
      <:icon>
        <span class={["w-3 h-3 inline-flex items-center justify-center", role_color(@user[:role])]}>
          {role_prefix(@user[:role])}
        </span>
      </:icon>
      <span class="truncate">{@user[:nick] || @user[:name]}</span>
    </.tree_view_item>
    """
  end

  defp role_prefix(:owner), do: "~"
  defp role_prefix(:operator), do: "@"
  defp role_prefix(:half_operator), do: "%"
  defp role_prefix(:voiced), do: "+"
  defp role_prefix(_), do: ""

  defp role_color(:owner), do: "text-error"
  defp role_color(:operator), do: "text-success"
  defp role_color(:half_operator), do: "text-warning-alt"
  defp role_color(:voiced), do: "text-link"
  defp role_color(_), do: "text-muted-foreground"
end
