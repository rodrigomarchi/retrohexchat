defmodule RetroHexChatWeb.Components.UI.HoverCard do
  @moduledoc """
  Hover card component for the showcase design system.

  Composed from window + badge + separator + loading_spinner primitives.
  Displays nick info in a retro popup window with role badges,
  absolute positioning, and loading state.

  ## Usage

      <.hover_card
        nick="alice"
        host="user@host.com"
        visible={true}
        x={200}
        y={100}
      >
        <:role_badges>
          <.badge variant="destructive">Owner</.badge>
        </:role_badges>
      </.hover_card>
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.Separator
  import RetroHexChatWeb.Components.UI.LoadingSpinner

  alias RetroHexChatWeb.Icons

  @doc "Renders a hover card popup with nick info fields."
  attr :nick, :string, required: true
  attr :visible, :boolean, default: true, doc: "Show/hide the hover card"
  attr :loading, :boolean, default: false, doc: "Show loading spinner instead of content"
  attr :x, :integer, default: nil, doc: "Absolute X position in pixels"
  attr :y, :integer, default: nil, doc: "Absolute Y position in pixels"
  attr :away, :string, default: nil, doc: "Away message"
  attr :host, :string, default: nil, doc: "User@host mask"
  attr :real_name, :string, default: nil, doc: "Real name (GECOS)"
  attr :registered, :boolean, default: false, doc: "Whether nick is registered"
  attr :online_since, :string, default: nil, doc: "Online duration"
  attr :online_for, :string, default: nil, doc: "Connected for duration"
  attr :idle, :string, default: nil, doc: "Idle duration"
  attr :client, :string, default: nil, doc: "Client info string"
  attr :server, :string, default: nil, doc: "Connected server"
  attr :channels, :list, default: [], doc: "List of channel names"
  attr :browser, :string, default: nil, doc: "Browser name"
  attr :os, :string, default: nil, doc: "Operating system"
  attr :screen_resolution, :string, default: nil, doc: "Screen resolution"
  attr :language, :string, default: nil, doc: "Browser language"
  attr :timezone_info, :string, default: nil, doc: "Timezone string"
  attr :color_depth, :string, default: nil, doc: "Color depth"
  attr :on_close, :any, default: nil, doc: "Close button callback"
  attr :role, :atom, default: nil, values: [nil, :owner, :operator, :half_operator, :voiced, :bot]
  attr :is_contact, :boolean, default: false
  attr :contact_note, :string, default: nil
  attr :is_ignored, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  slot :role_badges

  @spec hover_card(map()) :: Phoenix.LiveView.Rendered.t()
  def hover_card(assigns) do
    assigns =
      assigns
      |> assign(:positioned?, not is_nil(assigns.x) and not is_nil(assigns.y))
      |> assign(:card_x, assigns.x || 0)
      |> assign(:card_y, assigns.y || 0)

    ~H"""
    <.window
      :if={@visible}
      class={
        classes([
          "w-[260px] max-w-[calc(100vw-1rem)]",
          @positioned? && "absolute left-[var(--hover-card-x)] top-[var(--hover-card-y)] z-50",
          @class
        ])
      }
      style={"--hover-card-x: #{@card_x}px; --hover-card-y: #{@card_y}px;"}
      data-testid={"hover-card-#{@nick}"}
      {@rest}
    >
      <.window_title_bar title={@nick} controls={[:close]} on_close={@on_close}>
        <:icon><Icons.icon_status_user class="w-4 h-4" /></:icon>
      </.window_title_bar>

      <.window_body class="p-retro-8 text-xs space-y-retro-4">
        <%= if @loading do %>
          <.loading_spinner size="sm" text={dgettext("chat", "Looking up %{nick}...", nick: @nick)} />
        <% else %>
          <%!-- Role badge (from role attr) --%>
          <div :if={@role} class="flex gap-retro-4 flex-wrap">
            <.role_badge role={@role} />
          </div>

          <%!-- Role badges (from slot) --%>
          <div :if={@role_badges != []} class="flex gap-retro-4 flex-wrap">
            {render_slot(@role_badges)}
          </div>

          <%!-- Info fields --%>
          <.info_field :if={@real_name} label={dgettext("chat", "Name")} value={@real_name} />
          <.info_field :if={@away} label={dgettext("chat", "Away")} value={@away} />
          <.info_field :if={@host} label={dgettext("chat", "Host")} value={@host} />
          <.info_field :if={@server} label={dgettext("chat", "Server")} value={@server} />
          <.info_field :if={@online_since} label={dgettext("chat", "Online")} value={@online_since} />
          <.info_field :if={@online_for} label={dgettext("chat", "For")} value={@online_for} />
          <.info_field :if={@idle} label={dgettext("chat", "Idle")} value={@idle} />
          <.info_field :if={@client} label={dgettext("chat", "Client")} value={@client} />
          <.info_field :if={@browser} label={dgettext("chat", "Browser")} value={@browser} />
          <.info_field :if={@os} label={dgettext("chat", "OS")} value={@os} />
          <.info_field
            :if={@screen_resolution}
            label={dgettext("chat", "Screen")}
            value={@screen_resolution}
          />
          <.info_field :if={@language} label={dgettext("chat", "Lang")} value={@language} />
          <.info_field :if={@timezone_info} label={dgettext("chat", "TZ")} value={@timezone_info} />
          <.info_field :if={@color_depth} label={dgettext("chat", "Colors")} value={@color_depth} />
          <.info_field :if={@contact_note} label={dgettext("chat", "Note")} value={@contact_note} />

          <%!-- Registration status --%>
          <div :if={@registered} class="flex items-center gap-retro-4">
            <Icons.icon_checkmark class="w-3 h-3 text-success" />
            <span class="text-muted-foreground">{dgettext("chat", "Registered")}</span>
          </div>

          <div :if={@channels != []} class="space-y-retro-2">
            <.separator />
            <div class="font-bold text-muted-foreground">{dgettext("chat", "Channels")}</div>
            <div class="flex flex-wrap gap-retro-4">
              <.badge :for={ch <- @channels} variant="outline">{ch}</.badge>
            </div>
          </div>

          <div :if={@is_contact || @is_ignored}>
            <.separator />
            <div class="flex gap-retro-8 mt-retro-4">
              <.badge :if={@is_contact} variant="default">{dgettext("chat", "Contact")}</.badge>
              <.badge :if={@is_ignored} variant="destructive">{dgettext("chat", "Ignored")}</.badge>
            </div>
          </div>
        <% end %>
      </.window_body>
    </.window>
    """
  end

  # ── Private helpers ───────────────────────────────────

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp info_field(assigns) do
    ~H"""
    <div class="flex">
      <span class="font-bold text-muted-foreground w-[60px] shrink-0">{@label}</span>
      <span class="truncate">{@value}</span>
    </div>
    """
  end

  attr :role, :atom, required: true

  defp role_badge(%{role: :owner} = assigns) do
    ~H'<.badge variant="destructive">{dgettext("chat", "Owner")}</.badge>'
  end

  defp role_badge(%{role: :operator} = assigns) do
    ~H'<.badge variant="default">{dgettext("chat", "Operator")}</.badge>'
  end

  defp role_badge(%{role: :half_operator} = assigns) do
    ~H'<.badge variant="secondary">{dgettext("chat", "Half-Op")}</.badge>'
  end

  defp role_badge(%{role: :voiced} = assigns) do
    ~H'<.badge variant="outline">{dgettext("chat", "Voiced")}</.badge>'
  end

  defp role_badge(%{role: :bot} = assigns) do
    ~H'<.badge variant="secondary">{dgettext("chat", "Bot")}</.badge>'
  end

  defp role_badge(assigns) do
    ~H""
  end
end
