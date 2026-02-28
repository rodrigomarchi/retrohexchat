defmodule RetroHexChatWeb.Components.UI.AppHeader do
  @moduledoc """
  Application header bar component for the showcase design system.

  Renders a Win98-style application header with a logo area and
  a panels slot for toolbar/navigation content.

  ## Usage

      <.app_header logo_variant={:hex}>
        <:panels>
          <button>File</button>
          <button>Edit</button>
        </:panels>
      </.app_header>
  """
  use RetroHexChatWeb.Component

  @doc "Renders the application header bar."
  attr :logo_href, :string, default: nil
  attr :logo_variant, :atom, default: :hex, values: [:hex, :full]
  attr :class, :string, default: nil
  attr :rest, :global

  slot :panels, doc: "Toolbar or navigation content rendered beside the logo"

  @spec app_header(map()) :: Phoenix.LiveView.Rendered.t()
  def app_header(assigns) do
    ~H"""
    <header
      class={classes(["bg-surface shadow-retro-window flex flex-col", @class])}
      data-testid="app-header"
      {@rest}
    >
      <%!-- Title bar row --%>
      <div class="bg-gradient-to-r from-primary to-highlight-light px-retro-4 py-[3px] flex items-center gap-retro-4">
        <%!-- Logo area --%>
        <.logo_link href={@logo_href} variant={@logo_variant} />

        <%!-- Spacer --%>
        <div class="flex-1" />
      </div>

      <%!-- Panels / toolbar row --%>
      <div :if={@panels != []} class="flex items-center gap-[1px] px-[2px] py-[2px]">
        {render_slot(@panels)}
      </div>
    </header>
    """
  end

  # ── Private helpers ───────────────────────────────────

  attr :href, :string, default: nil
  attr :variant, :atom, required: true

  defp logo_link(%{href: nil} = assigns) do
    ~H"""
    <div class="flex items-center">
      <.logo_text variant={@variant} />
    </div>
    """
  end

  defp logo_link(assigns) do
    ~H"""
    <a href={@href} class="flex items-center hover:opacity-80">
      <.logo_text variant={@variant} />
    </a>
    """
  end

  attr :variant, :atom, required: true

  defp logo_text(%{variant: :hex} = assigns) do
    ~H"""
    <span class="font-bold text-white text-xs tracking-widest select-none">HEX</span>
    """
  end

  defp logo_text(%{variant: :full} = assigns) do
    ~H"""
    <span class="font-bold text-white text-xs select-none">RetroHexChat</span>
    """
  end
end
