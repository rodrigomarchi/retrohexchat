defmodule RetroHexChatWeb.Components.UI.AppHeader do
  @moduledoc """
  Application header bar component for the showcase design system.

  Renders a Win98-style application header with a hex stone logo icon
  and toolbar buttons (disconnect, menu, help) grouped to the left.
  Height is 42px. Icon-only — no text branding.

  ## Usage

      <.app_header logo_href="/showcase" />
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  @doc "Renders the application header bar."
  attr :logo_href, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  slot :panels, doc: "Optional extra toolbar content"

  @spec app_header(map()) :: Phoenix.LiveView.Rendered.t()
  def app_header(assigns) do
    ~H"""
    <header
      class={
        classes([
          "bg-surface shadow-retro-window flex items-center h-[64px] px-[4px]",
          @class
        ])
      }
      data-testid="app-header"
      {@rest}
    >
      <%!-- Logo --%>
      <.logo_link href={@logo_href} />

      <%!-- Toolbar buttons (left) --%>
      <div class="flex items-center ml-[4px]">
        <.header_button label="Disconnect" disabled>
          <Icons.icon_btn_disconnect class="w-[32px] h-[32px]" />
        </.header_button>
        <.header_separator />
        <.header_button label="Menu" disabled>
          <Icons.icon_btn_menu class="w-[32px] h-[32px]" />
        </.header_button>
      </div>

      <%!-- Optional panels --%>
      <div :if={@panels != []} class="flex items-center ml-[4px]">
        {render_slot(@panels)}
      </div>

      <%!-- Spacer --%>
      <div class="flex-1" />

      <%!-- Help (right) --%>
      <a href="/chat/help" title="Help" target="_blank" rel="noopener" class="no-underline">
        <.header_button label="Help">
          <Icons.icon_btn_help_topics class="w-[32px] h-[32px]" />
        </.header_button>
      </a>
    </header>
    """
  end

  # ── Private helpers ───────────────────────────────────

  attr :href, :string, default: nil

  defp logo_link(%{href: nil} = assigns) do
    ~H"""
    <div class="flex items-center px-[2px]">
      <Icons.icon_hex_stone class="w-[48px] h-[48px] shrink-0" />
    </div>
    """
  end

  defp logo_link(assigns) do
    ~H"""
    <a href={@href} class="flex items-center px-[2px] no-underline hover:opacity-80">
      <Icons.icon_hex_stone class="w-[48px] h-[48px] shrink-0" />
    </a>
    """
  end

  attr :label, :string, required: true
  attr :disabled, :boolean, default: false
  slot :inner_block, required: true

  defp header_button(assigns) do
    ~H"""
    <button
      type="button"
      title={@label}
      disabled={@disabled}
      class={[
        "inline-flex items-center justify-center p-0",
        "w-[32px] min-w-[32px] h-[32px] min-h-[32px]",
        "border border-transparent focus:outline-none bg-surface",
        if(@disabled,
          do: "opacity-50 cursor-not-allowed",
          else: "cursor-pointer hover:shadow-retro-raised active:shadow-retro-sunken"
        )
      ]}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp header_separator(assigns) do
    assigns = assign(assigns, :dummy, nil)

    ~H"""
    <div class="mx-[1px] w-[1px] h-[24px] bg-gray-500" />
    """
  end
end
