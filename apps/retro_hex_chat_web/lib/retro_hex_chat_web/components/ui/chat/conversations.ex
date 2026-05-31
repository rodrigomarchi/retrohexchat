defmodule RetroHexChatWeb.Components.UI.Conversations do
  @moduledoc """
  Conversations sidebar component for the showcase design system.

  Composed from tree_view + badge + empty_state primitives.
  Displays channels, private messages, and popular channels in
  collapsible sections with 6 visual states.

  Hook-compatible with ConversationsHook: uses `phx-hook="ConversationsHook"`
  and `data-channel` / `data-nick` attributes on items.

  ## Usage

      <.conversations
        channels={@channels}
        active_channel="#lobby"
        pm_conversations={@pms}
        channel_user_counts={%{"#lobby" => 12}}
        on_channel_click="switch_channel"
        on_close="toggle_conversations"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.EmptyState
  import RetroHexChatWeb.Components.UI.TreeView

  alias RetroHexChatWeb.Icons

  # ── Main Component ─────────────────────────────────────

  @doc "Renders the conversations sidebar with channel/PM/popular sections."
  attr :id, :string, default: "conversations"
  attr :channels, :list, default: []
  attr :active_channel, :string, default: nil
  attr :unread_channels, :list, default: []
  attr :unread_counts, :map, default: %{}, doc: "Map of channel/pm name to unread count"
  attr :highlight_channels, :list, default: []
  attr :flash_channels, :list, default: [], doc: "Channels with recent activity flash"
  attr :muted_channels, :list, default: []
  attr :disconnected_channels, :list, default: [], doc: "Channels marked disconnected"
  attr :pm_conversations, :list, default: []
  attr :active_pm, :string, default: nil
  attr :unread_pms, :list, default: []

  attr :nick_color_fn, :any, default: nil, doc: "Function(nick) -> CSS class for nick coloring"
  attr :channel_user_counts, :map, default: %{}, doc: "Map of channel name to user count"
  attr :popular_channels, :list, default: [], doc: "List of maps with :name and :user_count"
  attr :collapsed_sections, :list, default: [], doc: "List of collapsed section keys"
  attr :on_channel_click, :any, default: nil, doc: "Channel click callback"
  attr :on_channel_dblclick, :any, default: nil, doc: "Channel double-click callback"
  attr :on_pm_click, :any, default: nil, doc: "PM click callback"
  attr :on_toggle_section, :any, default: nil, doc: "Section toggle callback"
  attr :on_close, :any, default: nil, doc: "Close/hide sidebar callback"
  attr :on_browse_channels, :any, default: nil, doc: "Browse channels callback"
  attr :on_join_popular, :any, default: nil, doc: "Join popular channel callback"
  attr :class, :string, default: nil
  attr :rest, :global

  @spec conversations(map()) :: Phoenix.LiveView.Rendered.t()
  def conversations(assigns) do
    ~H"""
    <div
      class={classes(["flex flex-col", @class])}
      id={@id}
      phx-hook="ConversationsHook"
      data-testid="conversations"
      {@rest}
    >
      <%!-- Header tab --%>
      <div class="flex items-center bg-surface shadow-retro-raised px-retro-4 py-retro-2">
        <Icons.icon_tab_conversations class="w-4 h-4 mr-retro-4" />
        <span class="text-xs font-bold flex-1">{gettext("Conversations")}</span>
        <.button
          :if={@on_close}
          type="button"
          variant="ghost"
          size="icon"
          class="w-5 h-5 min-h-0 text-xs"
          phx-click={@on_close}
          title={gettext("Hide channel list")}
          aria-label={gettext("Hide channel list")}
          data-testid="conversations-close"
        >
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
        </.button>
      </div>

      <%!-- Tree content --%>
      <.tree_view class="flex-1 retro-scrollbar">
        <%= if @channels == [] and @pm_conversations == [] do %>
          <.empty_state>
            <:icon><Icons.icon_channels class="w-6 h-6" /></:icon>
            <:title>{gettext("No channels")}</:title>
            <:description>{gettext("/join #channel to get started")}</:description>
            <:action>
              <.button
                :if={@on_browse_channels}
                variant="outline"
                size="sm"
                phx-click={@on_browse_channels}
                data-testid="conversations-browse-channels"
              >
                <:icon><Icons.icon_btn_channel_list class="w-4 h-4" /></:icon>
                {gettext("Browse channels")}
              </.button>
            </:action>
          </.empty_state>
        <% else %>
          <%!-- My Channels --%>
          <.tree_view_group
            label={gettext("MY CHANNELS")}
            open={"channels" not in @collapsed_sections}
            phx-click={@on_toggle_section}
            phx-value-section="channels"
            data-testid="conversations-section-channels"
          >
            <.channel_item
              :for={ch <- @channels}
              name={ch}
              active={ch == @active_channel}
              unread={ch in @unread_channels}
              unread_count={Map.get(@unread_counts, ch, 0)}
              highlight={ch in @highlight_channels or ch in @flash_channels}
              flash={ch in @flash_channels}
              muted={ch in @muted_channels}
              disconnected={ch in @disconnected_channels}
              user_count={Map.get(@channel_user_counts, ch)}
              on_click={@on_channel_click}
              on_dblclick={@on_channel_dblclick}
            />
          </.tree_view_group>

          <%!-- Private Messages --%>
          <.tree_view_group
            :if={@pm_conversations != []}
            label={gettext("PRIVATE MESSAGES")}
            open={"pms" not in @collapsed_sections}
            phx-click={@on_toggle_section}
            phx-value-section="pms"
            data-testid="conversations-section-pms"
          >
            <.pm_item
              :for={pm <- @pm_conversations}
              nick={pm}
              active={pm == @active_pm}
              unread={pm in @unread_pms}
              unread_count={Map.get(@unread_counts, "pm:#{pm}", 0)}
              flash={"pm:#{pm}" in @flash_channels}
              muted={"pm:#{pm}" in @muted_channels}
              nick_color={@nick_color_fn && @nick_color_fn.(pm)}
              on_click={@on_pm_click}
            />
          </.tree_view_group>

          <%!-- Popular Channels --%>
          <.tree_view_group
            label={gettext("POPULAR CHANNELS")}
            open={"popular" not in @collapsed_sections}
            phx-click={@on_toggle_section}
            phx-value-section="popular"
            data-testid="conversations-section-popular"
          >
            <.popular_item
              :for={ch <- @popular_channels}
              channel={ch}
              on_join={@on_join_popular}
            />
            <div class="px-retro-4 py-retro-2">
              <.button
                :if={@on_browse_channels}
                variant="link"
                size="sm"
                class="gap-retro-4 p-0 h-auto"
                phx-click={@on_browse_channels}
                data-testid="conversations-browse-all"
              >
                <:icon><Icons.icon_dialog_channel_list class="w-3 h-3" /></:icon>
                {gettext("Browse All Channels...")}
              </.button>
            </div>
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
  attr :unread_count, :integer, default: 0
  attr :highlight, :boolean, default: false
  attr :flash, :boolean, default: false
  attr :muted, :boolean, default: false
  attr :disconnected, :boolean, default: false
  attr :user_count, :integer, default: nil
  attr :on_click, :any, default: nil
  attr :on_dblclick, :any, default: nil

  defp channel_item(assigns) do
    ~H"""
    <.tree_view_item
      active={@active}
      class={[
        @unread && !@active && "font-bold",
        @highlight && !@active && "text-error",
        @flash && "animate-pulse",
        @muted && "opacity-50"
      ]}
      phx-click={@on_click}
      phx-value-channel={@name}
      phx-dblclick={@on_dblclick}
      data-channel={@name}
      data-muted={to_string(@muted)}
      data-unread={to_string(@unread)}
      data-testid={"channel-#{@name}"}
    >
      <:icon>
        <span :if={@disconnected} class="text-warning-alt text-[10px]" title={gettext("Disconnected")}>
          ⚡
        </span>
        <Icons.icon_tab_channel :if={!@disconnected} class="w-3 h-3" />
      </:icon>
      <span class="flex-1 truncate">{@name}</span>
      <span
        :if={@user_count}
        class="text-[10px] text-muted-foreground shrink-0"
      >
        ({@user_count})
      </span>
      <span
        :if={@unread && !@active && @unread_count > 0}
        class={[
          "text-[10px] font-bold rounded-full px-1 min-w-[16px] text-center shrink-0",
          if(@highlight, do: "bg-error text-white", else: "bg-link text-white")
        ]}
        data-testid={"channel-unread-badge-#{@name}"}
      >
        {if @unread_count > 99, do: "99+", else: @unread_count}
      </span>
      <span
        :if={@unread && !@active && @unread_count == 0}
        class="w-2 h-2 rounded-full bg-link shrink-0"
        data-testid={"channel-unread-dot-#{@name}"}
      />
    </.tree_view_item>
    """
  end

  # ── PM Item ────────────────────────────────────────────

  attr :nick, :string, required: true
  attr :active, :boolean, default: false
  attr :unread, :boolean, default: false
  attr :unread_count, :integer, default: 0
  attr :flash, :boolean, default: false
  attr :muted, :boolean, default: false
  attr :nick_color, :string, default: nil
  attr :on_click, :any, default: nil

  defp pm_item(assigns) do
    ~H"""
    <.tree_view_item
      active={@active}
      class={[
        @unread && !@active && "font-bold italic",
        @flash && "animate-pulse",
        @muted && "opacity-50"
      ]}
      phx-click={@on_click}
      phx-value-nickname={@nick}
      data-nick={@nick}
      data-muted={to_string(@muted)}
      data-unread={to_string(@unread)}
      data-testid={"pm-#{@nick}"}
    >
      <:icon><Icons.icon_tab_pm class="w-3 h-3" /></:icon>
      <span class={["truncate", !@active && @nick_color]}>{@nick}</span>
      <span
        :if={@unread && !@active && @unread_count > 0}
        class="text-[10px] font-bold bg-link text-white rounded-full px-1 min-w-[16px] text-center shrink-0"
        data-testid={"pm-unread-badge-#{@nick}"}
      >
        {if @unread_count > 99, do: "99+", else: @unread_count}
      </span>
      <span
        :if={@unread && !@active && @unread_count == 0}
        class="w-2 h-2 rounded-full bg-link shrink-0"
        data-testid={"pm-unread-dot-#{@nick}"}
      />
    </.tree_view_item>
    """
  end

  # ── Popular Item ───────────────────────────────────────

  attr :channel, :map, required: true, doc: "Map with :name and :user_count"
  attr :on_join, :any, default: nil

  defp popular_item(assigns) do
    ~H"""
    <.tree_view_item data-testid={"popular-#{@channel.name}"}>
      <:icon><Icons.icon_tab_channel class="w-3 h-3" /></:icon>
      <span class="flex-1 truncate">{@channel.name}</span>
      <span class="text-[10px] text-muted-foreground">({@channel.user_count})</span>
      <.button
        :if={@on_join}
        type="button"
        variant="ghost"
        size="icon"
        class="ml-1 shrink-0 w-4 h-4 min-h-0"
        phx-click={@on_join}
        phx-value-channel={@channel.name}
        title={gettext("Join %{channel}", channel: @channel.name)}
        data-testid={"join-#{@channel.name}"}
      >
        <:icon><Icons.icon_btn_add class="w-3 h-3" /></:icon>
      </.button>
    </.tree_view_item>
    """
  end
end
