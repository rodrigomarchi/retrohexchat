defmodule RetroHexChatWeb.Components.UI.Nicklist do
  @moduledoc false
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChat.Channels.Modes
  alias RetroHexChatWeb.Icons

  @doc """
  Renders the nicklist sidebar chrome. `visible` means expanded; when false, the
  mounted sidebar is replaced by the 36px rail. `available`
  hides the entire sidebar in contexts that do not have a channel roster.
  """
  attr :available, :boolean, default: true
  attr :visible, :boolean, default: true
  attr :on_backdrop, :string, required: true
  attr :on_toggle, :string, required: true
  attr :rest, :global
  slot :rail, required: true
  slot :inner_block, required: true

  @spec nicklist_sidebar(map()) :: Phoenix.LiveView.Rendered.t()
  def nicklist_sidebar(assigns) do
    assigns = assign(assigns, :state, if(assigns.visible, do: "expanded", else: "collapsed"))

    ~H"""
    <div
      class={[
        "chat-sidebar-overlay chat-sidebar-shell chat-sidebar-shell--right fixed inset-y-0 left-0 right-0 z-40",
        "flex justify-end shrink-0 md:relative md:inset-auto md:z-auto md:h-full",
        @visible && "chat-sidebar-shell--expanded",
        !@visible && "chat-sidebar-shell--collapsed",
        !@available && "hidden"
      ]}
      data-state={@state}
      data-side="right"
      data-testid="nicklist-sidebar-shell"
    >
      <div
        :if={@visible}
        class="chat-sidebar-backdrop absolute inset-0 bg-black/30 md:hidden"
        phx-click={@on_backdrop}
      />
      <div class="chat-sidebar-frame relative z-10 flex h-full min-h-0 bg-surface shadow-retro-window md:shadow-none">
        <div class="chat-sidebar-panel min-w-0 flex-1">
          <.nicklist class="h-full" {@rest}>
            {render_slot(@inner_block)}
          </.nicklist>
        </div>
        <%= if !@visible do %>
          {render_slot(@rail)}
        <% end %>
      </div>
    </div>
    """
  end

  @doc "Renders the compact channel roster rail used by the collapsed state."
  attr :expanded, :boolean, default: true
  attr :channel_name, :string, default: nil
  attr :total, :integer, default: 0
  attr :online_count, :integer, default: 0
  attr :away_count, :integer, default: 0
  attr :muted_count, :integer, default: 0
  attr :sections, :list, default: []
  attr :on_toggle, :any, required: true

  @spec nicklist_rail(map()) :: Phoenix.LiveView.Rendered.t()
  def nicklist_rail(assigns) do
    assigns =
      assigns
      |> assign(:display_channel, assigns.channel_name || dgettext("chat", "Users"))
      |> assign(:visible_sections, Enum.take(assigns.sections || [], 4))

    ~H"""
    <nav
      class="chat-sidebar-rail chat-sidebar-rail--right"
      aria-label={dgettext("chat", "User list rail")}
      data-testid="nicklist-rail"
    >
      <button
        type="button"
        class="chat-sidebar-rail__button chat-sidebar-rail__button--toggle"
        phx-click={@on_toggle}
        title={
          if @expanded,
            do: dgettext("chat", "Collapse user list"),
            else: dgettext("chat", "Expand user list")
        }
        aria-label={
          if @expanded,
            do: dgettext("chat", "Collapse user list"),
            else: dgettext("chat", "Expand user list")
        }
        aria-expanded={to_string(@expanded)}
        data-testid="nicklist-rail-toggle"
      >
        <Icons.icon_chevron_right :if={@expanded} class="h-4 w-4" />
        <Icons.icon_chevron_left :if={!@expanded} class="h-4 w-4" />
      </button>

      <.nicklist_rail_item
        icon={:channel}
        label={@display_channel}
        count={@total}
        active
        expanded={@expanded}
        on_toggle={@on_toggle}
      />
      <.nicklist_rail_item
        icon={:online}
        label={dgettext("chat", "Online")}
        count={@online_count}
        expanded={@expanded}
        on_toggle={@on_toggle}
      />
      <.nicklist_rail_item
        :if={@away_count > 0}
        icon={:away}
        label={dgettext("chat", "Away")}
        count={@away_count}
        expanded={@expanded}
        on_toggle={@on_toggle}
      />
      <.nicklist_rail_item
        :if={@muted_count > 0}
        icon={:muted}
        label={dgettext("chat", "Muted")}
        count={@muted_count}
        expanded={@expanded}
        on_toggle={@on_toggle}
      />
      <.nicklist_rail_role
        :for={section <- @visible_sections}
        section={section}
        expanded={@expanded}
        on_toggle={@on_toggle}
      />
    </nav>
    """
  end

  attr :icon, :atom, required: true
  attr :label, :string, required: true
  attr :count, :integer, default: nil
  attr :active, :boolean, default: false
  attr :expanded, :boolean, default: true
  attr :on_toggle, :any, required: true

  defp nicklist_rail_item(assigns) do
    assigns = assign(assigns, :title, rail_item_title(assigns.label, assigns.count))

    ~H"""
    <button
      type="button"
      class={[
        "chat-sidebar-rail__button",
        @active && "chat-sidebar-rail__button--active"
      ]}
      phx-click={if @expanded, do: nil, else: @on_toggle}
      title={@title}
      aria-label={@title}
    >
      <.nicklist_rail_icon icon={@icon} />
      <span :if={is_integer(@count)} class="chat-sidebar-rail__count">{@count}</span>
    </button>
    """
  end

  attr :section, :map, required: true
  attr :expanded, :boolean, default: true
  attr :on_toggle, :any, required: true

  defp nicklist_rail_role(assigns) do
    assigns =
      assign(assigns, :title, rail_item_title(assigns.section.label, assigns.section.count))

    ~H"""
    <button
      type="button"
      class={[
        "chat-sidebar-rail__button",
        "chat-sidebar-rail__button--role-#{role_class(@section.key)}"
      ]}
      phx-click={if @expanded, do: nil, else: @on_toggle}
      title={@title}
      aria-label={@title}
    >
      <span class="chat-sidebar-rail__role-icon">
        {role_icon(%{role: @section.key})}
      </span>
      <span class="chat-sidebar-rail__count">{@section.count}</span>
    </button>
    """
  end

  attr :icon, :atom, required: true

  defp nicklist_rail_icon(%{icon: :channel} = assigns) do
    ~H"""
    <Icons.icon_tab_nicklist class="h-4 w-4" />
    """
  end

  defp nicklist_rail_icon(%{icon: :online} = assigns) do
    ~H"""
    <Icons.icon_status_user class="h-4 w-4" />
    """
  end

  defp nicklist_rail_icon(%{icon: :away} = assigns) do
    ~H"""
    <Icons.icon_btn_away class="h-4 w-4" />
    """
  end

  defp nicklist_rail_icon(%{icon: :muted} = assigns) do
    ~H"""
    <Icons.icon_mute class="h-4 w-4" />
    """
  end

  @doc "Renders a Win98-style user list container."
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec nicklist(map()) :: Phoenix.LiveView.Rendered.t()
  def nicklist(assigns) do
    ~H"""
    <div
      class={classes(["chat-nicklist shadow-retro-field bg-white", @class])}
      data-testid="nicklist"
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Renders the channel identity and mode summary for the nicklist."
  attr :channel_name, :string, default: nil
  attr :total, :integer, default: 0
  attr :modes, :any, default: nil
  attr :on_close, :any, default: nil
  attr :class, :any, default: nil
  attr :rest, :global

  @spec nicklist_header(map()) :: Phoenix.LiveView.Rendered.t()
  def nicklist_header(assigns) do
    assigns =
      assigns
      |> assign(:display_channel, assigns.channel_name || dgettext("chat", "Users"))
      |> assign(:mode_badges, mode_badges(assigns.modes))

    ~H"""
    <div class={classes(["chat-nicklist-header", @class])} data-testid="nicklist-header" {@rest}>
      <div class="chat-nicklist-header__main">
        <span class="chat-nicklist-header__icon" aria-hidden="true">
          <Icons.icon_tab_nicklist class="h-4 w-4" />
        </span>
        <span class="chat-nicklist-header__channel">{@display_channel}</span>
        <span class="chat-nicklist-header__count">{@total}</span>
        <.button
          :if={@on_close}
          type="button"
          variant="outline"
          size="icon"
          class="chat-sidebar-collapse-button"
          phx-click={@on_close}
          title={dgettext("chat", "Collapse user list")}
          aria-label={dgettext("chat", "Collapse user list")}
          data-testid="nicklist-collapse-toggle"
        >
          <:icon><Icons.icon_chevron_right class="h-4 w-4" /></:icon>
          <span class="sr-only">{dgettext("chat", "Collapse user list")}</span>
        </.button>
      </div>
      <div :if={@mode_badges != []} class="chat-nicklist-header__modes">
        <span :for={mode <- @mode_badges} class="chat-nicklist-mode">{mode}</span>
      </div>
    </div>
    """
  end

  @doc "Renders compact live counters for the channel roster."
  attr :online_count, :integer, default: 0
  attr :away_count, :integer, default: 0
  attr :muted_count, :integer, default: 0
  attr :class, :any, default: nil
  attr :rest, :global

  @spec nicklist_status_strip(map()) :: Phoenix.LiveView.Rendered.t()
  def nicklist_status_strip(assigns) do
    ~H"""
    <div class={classes(["chat-nicklist-status-strip", @class])} {@rest}>
      <.nicklist_stat
        label={dgettext("chat", "Online")}
        count={@online_count}
        icon={:online}
        variant={:online}
        testid="nicklist-online-count"
      />
      <.nicklist_stat
        label={dgettext("chat", "Away")}
        count={@away_count}
        icon={:away}
        variant={:away}
        testid="nicklist-away-count"
      />
      <.nicklist_stat
        label={dgettext("chat", "Muted")}
        count={@muted_count}
        icon={:muted}
        variant={:muted}
        testid="nicklist-muted-count"
      />
    </div>
    """
  end

  attr :label, :string, required: true
  attr :count, :integer, required: true
  attr :icon, :atom, required: true
  attr :variant, :atom, required: true
  attr :testid, :string, required: true

  defp nicklist_stat(assigns) do
    ~H"""
    <div class={["chat-nicklist-stat", "chat-nicklist-stat--#{@variant}"]} title={@label}>
      <.nicklist_stat_icon icon={@icon} />
      <span class="chat-nicklist-stat__value" data-testid={@testid}>{@count}</span>
      <span class="chat-nicklist-stat__label">{@label}</span>
    </div>
    """
  end

  attr :icon, :atom, required: true

  defp nicklist_stat_icon(%{icon: :online} = assigns) do
    ~H"""
    <Icons.icon_status_user class="h-3 w-3" />
    """
  end

  defp nicklist_stat_icon(%{icon: :away} = assigns) do
    ~H"""
    <Icons.icon_btn_away class="h-3 w-3" />
    """
  end

  defp nicklist_stat_icon(%{icon: :muted} = assigns) do
    ~H"""
    <Icons.icon_mute class="h-3 w-3" />
    """
  end

  @doc "Scroll container for grouped nicklist sections."
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec nicklist_body(map()) :: Phoenix.LiveView.Rendered.t()
  def nicklist_body(assigns) do
    ~H"""
    <div class={classes(["chat-nicklist-body", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Renders one IRC role group inside the nicklist."
  attr :role, :atom,
    values: [:owner, :operator, :half_operator, :voiced, :regular, :bot],
    required: true

  attr :label, :string, required: true
  attr :count, :integer, default: 0
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec nicklist_section(map()) :: Phoenix.LiveView.Rendered.t()
  def nicklist_section(assigns) do
    assigns =
      assigns
      |> assign(:role_class, role_class(assigns.role))
      |> assign(:role_name, role_name(assigns.role))

    ~H"""
    <section
      :if={@count > 0}
      class={classes(["chat-nicklist-section", "chat-nicklist-section--#{@role_class}", @class])}
      data-testid={"nicklist-section-#{@role_class}"}
      data-role={@role_name}
      {@rest}
    >
      <div class="chat-nicklist-section__header">
        <span class="chat-nicklist-section__icon" aria-hidden="true">
          {role_icon(assigns)}
        </span>
        <span class="chat-nicklist-section__label">{@label}</span>
        <span class="chat-nicklist-section__count">{@count}</span>
      </div>
      <div class="chat-nicklist-section__rows">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  @doc "Renders a user item in the nicklist."
  attr :nick, :string, required: true
  attr :status, :string, values: ~w(online offline away), default: "online"

  attr :role, :any, default: :regular

  attr :nick_color, :string, default: nil
  attr :muted, :boolean, default: false
  attr :current, :boolean, default: false
  attr :class, :any, default: nil
  attr :rest, :global

  @spec nicklist_item(map()) :: Phoenix.LiveView.Rendered.t()
  def nicklist_item(assigns) do
    assigns =
      assigns
      |> assign(:role, role_key(assigns.role))
      |> assign(:role_class, role_class(assigns.role))
      |> assign(:role_name, role_name(assigns.role))

    ~H"""
    <div
      class={
        classes([
          "chat-nicklist-row",
          "chat-nicklist-row--#{@role_class}",
          @class
        ])
      }
      data-testid={"nicklist-item-#{@nick}"}
      data-role={@role_name}
      data-status={@status}
      data-muted={to_string(@muted)}
      data-current={to_string(@current)}
      {@rest}
    >
      <span
        class={[
          "chat-nicklist-row__signal",
          @status == "online" && "chat-nicklist-row__signal--online",
          @status == "away" && "chat-nicklist-row__signal--away",
          @status == "offline" && "chat-nicklist-row__signal--offline"
        ]}
        aria-hidden="true"
      />
      <span class="chat-nicklist-row__role" aria-hidden="true">
        {role_icon(assigns)}
      </span>
      <span class={["chat-nicklist-row__nick", @nick_color || "text-text"]}>
        {@nick}
      </span>
      <span
        :if={@status == "away"}
        class="chat-nicklist-row__badge chat-nicklist-row__badge--away"
        title={dgettext("chat", "Away")}
        aria-hidden="true"
      >
        <Icons.icon_btn_dnd_active class="h-3 w-3" />
      </span>
      <span
        :if={@muted}
        class="chat-nicklist-row__badge chat-nicklist-row__badge--muted"
        title={dgettext("chat", "Muted")}
        aria-hidden="true"
      >
        <Icons.icon_mute class="h-3 w-3" />
      </span>
    </div>
    """
  end

  defp mode_badges(%Modes{} = modes), do: modes |> Modes.to_string() |> mode_badges()
  defp mode_badges(modes) when modes in [nil, ""], do: []
  defp mode_badges(modes) when is_binary(modes), do: [modes]
  defp mode_badges(modes) when is_list(modes), do: modes
  defp mode_badges(_modes), do: []

  defp role_key(:normal), do: :regular
  defp role_key(:owner), do: :owner
  defp role_key(:operator), do: :operator
  defp role_key(:half_operator), do: :half_operator
  defp role_key(:voiced), do: :voiced
  defp role_key(:bot), do: :bot
  defp role_key(:regular), do: :regular
  defp role_key("owner"), do: :owner
  defp role_key("op"), do: :operator
  defp role_key("operator"), do: :operator
  defp role_key("half_operator"), do: :half_operator
  defp role_key("half-op"), do: :half_operator
  defp role_key("voice"), do: :voiced
  defp role_key("voiced"), do: :voiced
  defp role_key("bot"), do: :bot
  defp role_key(_), do: :regular

  defp role_class(:half_operator), do: "half-operator"
  defp role_class(role), do: role |> role_key() |> Atom.to_string() |> String.replace("_", "-")

  defp role_name(role), do: role |> role_key() |> Atom.to_string()

  defp role_icon(%{role: :owner} = assigns) do
    ~H'<Icons.icon_role_owner class="h-4 w-4" />'
  end

  defp role_icon(%{role: :operator} = assigns) do
    ~H'<Icons.icon_role_operator class="w-[16px] h-[16px]" />'
  end

  defp role_icon(%{role: :half_operator} = assigns) do
    ~H'<Icons.icon_role_halfop class="w-[16px] h-[16px]" />'
  end

  defp role_icon(%{role: :voiced} = assigns) do
    ~H'<Icons.icon_role_voiced class="w-[16px] h-[16px]" />'
  end

  defp role_icon(%{role: :bot} = assigns) do
    ~H'<Icons.icon_robot class="w-[16px] h-[16px]" />'
  end

  defp role_icon(assigns) do
    ~H'<Icons.icon_role_regular class="w-[16px] h-[16px]" />'
  end

  defp rail_item_title(label, count) when is_integer(count), do: "#{label}: #{count}"
  defp rail_item_title(label, _count), do: label
end
