defmodule RetroHexChatWeb.Components.UI.Nicklist do
  @moduledoc false
  use RetroHexChatWeb.Component

  alias RetroHexChat.Channels.Modes
  alias RetroHexChatWeb.Icons

  @doc """
  Renders the nicklist sidebar: responsive layout + mobile backdrop wrapping a
  full-height user-list container. `visible` toggles the `hidden` class without
  unmounting, so a streamed list inside is never torn down. Globals (e.g. `id`,
  `phx-hook`, `phx-update`) are forwarded to the list container, and the inner
  block holds the user rows.
  """
  attr :visible, :boolean, default: true
  attr :on_backdrop, :string, required: true
  attr :rest, :global
  slot :inner_block, required: true

  @spec nicklist_sidebar(map()) :: Phoenix.LiveView.Rendered.t()
  def nicklist_sidebar(assigns) do
    ~H"""
    <div class={[
      "chat-sidebar-overlay fixed inset-x-0 bottom-0 top-0 z-40 md:relative md:inset-auto md:z-auto",
      "flex justify-end md:h-full md:justify-stretch md:w-[260px] md:min-w-[220px] md:shrink-0",
      !@visible && "hidden"
    ]}>
      <div class="absolute inset-0 bg-black/30 md:hidden" phx-click={@on_backdrop} />
      <div class="relative z-10 w-[300px] max-w-[calc(100vw-48px)] md:w-full md:max-w-none h-full bg-surface shadow-retro-window md:shadow-none">
        <.nicklist class="h-full" {@rest}>
          {render_slot(@inner_block)}
        </.nicklist>
      </div>
    </div>
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
end
