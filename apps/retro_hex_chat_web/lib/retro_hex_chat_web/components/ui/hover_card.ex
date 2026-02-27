defmodule RetroHexChatWeb.Components.UI.HoverCard do
  @moduledoc """
  Hover card component for the showcase design system.

  Composed from window + badge + separator primitives.
  Displays nick info in a retro popup window with role badges.

  ## Usage

      <.hover_card nick="alice" host="user@host.com" online_since="2h ago">
        <:role_badges>
          <.badge variant="destructive">Owner</.badge>
        </:role_badges>
      </.hover_card>
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.Separator

  alias RetroHexChatWeb.Icons

  @doc "Renders a hover card popup with nick info fields."
  attr :nick, :string, required: true
  attr :away, :string, default: nil
  attr :host, :string, default: nil
  attr :online_since, :string, default: nil
  attr :client, :string, default: nil
  attr :channels, :list, default: []
  attr :is_contact, :boolean, default: false
  attr :is_ignored, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  slot :role_badges

  @spec hover_card(map()) :: Phoenix.LiveView.Rendered.t()
  def hover_card(assigns) do
    ~H"""
    <.window class={classes(["w-[260px]", @class])} {@rest}>
      <.window_title_bar title={@nick} controls={[:close]}>
        <:icon><Icons.icon_status_user class="w-4 h-4" /></:icon>
      </.window_title_bar>

      <.window_body class="p-retro-8 text-xs space-y-retro-4">
        <%!-- Role badges --%>
        <div :if={@role_badges != []} class="flex gap-retro-4 flex-wrap">
          {render_slot(@role_badges)}
        </div>

        <%!-- Info fields --%>
        <.info_field :if={@away} label="Away" value={@away} />
        <.info_field :if={@host} label="Host" value={@host} />
        <.info_field :if={@online_since} label="Online" value={@online_since} />
        <.info_field :if={@client} label="Client" value={@client} />

        <div :if={@channels != []} class="space-y-retro-2">
          <.separator />
          <div class="font-bold text-muted-foreground">Channels</div>
          <div class="flex flex-wrap gap-retro-4">
            <.badge :for={ch <- @channels} variant="outline">{ch}</.badge>
          </div>
        </div>

        <div :if={@is_contact || @is_ignored}>
          <.separator />
          <div class="flex gap-retro-8 mt-retro-4">
            <.badge :if={@is_contact} variant="default">Contact</.badge>
            <.badge :if={@is_ignored} variant="destructive">Ignored</.badge>
          </div>
        </div>
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
end
