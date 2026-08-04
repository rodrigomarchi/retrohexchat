defmodule RetroHexChatWeb.Components.UI.AppHeader do
  @moduledoc """
  Compact application header bar for the App interface.

  Renders a single-line header (28px) with a small hex stone logo (16px)
  and slots for panels (menu bar, status bar) and mobile action buttons.

  ## Usage

      <.app_header on_logo_click={show_modal("about-dialog")}>
        <:panels>
          <.menu_bar_app connected={true} on_action="toolbar_action" />
          <.status_bar_app class="ml-auto" ... />
        </:panels>
      </.app_header>
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  @doc """
  Renders the application header bar.

  The logo opens About on every shell — pass `on_logo_click` where a LiveSocket
  runs, or `logo_window` where About is a desktop window and the window manager
  has to open it (the landing pages ship no LiveSocket, so a `phx-click` there
  would never fire). `logo_href` remains for a logo that is plain navigation.
  """
  attr :logo_href, :string, default: nil
  attr :logo_window, :string, default: nil, doc: "window id the logo opens (data-window-open)"
  attr :on_logo_click, :any, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  slot :panels, doc: "Optional extra toolbar content"
  slot :mobile_actions, doc: "Buttons visible only on mobile (md:hidden)"

  @spec app_header(map()) :: Phoenix.LiveView.Rendered.t()
  def app_header(assigns) do
    ~H"""
    <header
      class={
        classes([
          "bg-surface shadow-retro-window flex items-center h-7 shrink-0 px-1",
          @class
        ])
      }
      data-testid="app-header"
      {@rest}
    >
      <%!-- Logo --%>
      <.logo_element href={@logo_href} window={@logo_window} on_click={@on_logo_click} />

      <%!-- Mobile action buttons --%>
      <div :if={@mobile_actions != []} class="flex items-center gap-1 ml-1 md:hidden">
        {render_slot(@mobile_actions)}
      </div>

      <%!-- Optional panels --%>
      <div :if={@panels != []} class="flex items-center ml-1 flex-1">
        {render_slot(@panels)}
      </div>

      <%!-- Spacer (only if no panels) --%>
      <div :if={@panels == []} class="flex-1" />
    </header>
    """
  end

  # ── Private helpers ───────────────────────────────────

  attr :href, :string, default: nil
  attr :window, :string, default: nil
  attr :on_click, :any, default: nil

  defp logo_element(%{window: window} = assigns) when not is_nil(window) do
    ~H"""
    <button
      type="button"
      class="flex items-center px-[2px] cursor-pointer border-none bg-transparent hover:opacity-80"
      data-window-open={@window}
      onmousedown="event.preventDefault()"
      aria-label={dgettext("ui", "About RetroHexChat")}
      data-testid="app-logo"
    >
      <Icons.icon_hex_stone class="w-4 h-4 shrink-0" />
    </button>
    """
  end

  defp logo_element(%{on_click: on_click} = assigns) when not is_nil(on_click) do
    ~H"""
    <button
      type="button"
      class="flex items-center px-[2px] cursor-pointer border-none bg-transparent hover:opacity-80"
      phx-click={@on_click}
      onmousedown="event.preventDefault()"
      aria-label={dgettext("ui", "About RetroHexChat")}
      data-testid="app-logo"
    >
      <Icons.icon_hex_stone class="w-4 h-4 shrink-0" />
    </button>
    """
  end

  defp logo_element(%{href: nil} = assigns) do
    ~H"""
    <div class="flex items-center px-[2px]">
      <Icons.icon_hex_stone class="w-4 h-4 shrink-0" />
    </div>
    """
  end

  defp logo_element(assigns) do
    ~H"""
    <a href={@href} class="flex items-center px-[2px] no-underline hover:opacity-80">
      <Icons.icon_hex_stone class="w-4 h-4 shrink-0" />
    </a>
    """
  end
end
