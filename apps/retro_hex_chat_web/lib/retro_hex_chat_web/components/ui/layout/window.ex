defmodule RetroHexChatWeb.Components.UI.Window do
  @moduledoc false
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  @doc "Renders a Win98-style window frame."
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec window(map()) :: Phoenix.LiveView.Rendered.t()
  def window(assigns) do
    ~H"""
    <div class={classes(["shadow-retro-window bg-surface p-[3px] flex flex-col", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Renders a Win98-style title bar with gradient and control buttons."
  attr :title, :string, required: true
  attr :inactive, :boolean, default: false
  attr :controls, :list, default: [:minimize, :maximize, :close]
  attr :on_close, :any, default: nil, doc: "Close button callback (wired to :close control)"
  attr :close_target, :string, default: nil, doc: "CSS selector for static close behavior"
  attr :class, :any, default: nil
  attr :rest, :global

  slot :icon, required: true, doc: "16×16 title bar icon — mandatory for Win98 consistency"

  @spec window_title_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def window_title_bar(assigns) do
    assigns = assign(assigns, :controls, ensure_close(assigns.controls))

    ~H"""
    <div
      class={
        classes([
          "flex justify-between items-center px-[3px] py-[3px]",
          if(@inactive,
            do: "bg-gradient-to-r from-gray-500 to-gray-350",
            else: "bg-gradient-to-r from-primary to-highlight-light"
          ),
          @class
        ])
      }
      {@rest}
    >
      <div class="flex items-center gap-1 min-w-0">
        <span class="flex-shrink-0 w-[16px] h-[16px] inline-flex items-center justify-center">
          {render_slot(@icon)}
        </span>
        <span class="font-bold text-white text-xs truncate mr-6">{@title}</span>
      </div>
      <div class="flex flex-shrink-0">
        <button
          :for={control <- @controls}
          type="button"
          disabled={@inactive && is_nil(@on_close)}
          aria-label={control_label(control)}
          class={[
            "inline-flex items-center justify-center w-[16px] h-[14px] p-0 shadow-retro-raised bg-surface",
            "active:shadow-retro-sunken focus:outline-none",
            control == :close && "ml-[2px]"
          ]}
          phx-click={control == :close && @on_close}
          data-hide-target={control == :close && @close_target}
        >
          <.control_icon control={control} />
        </button>
      </div>
    </div>
    """
  end

  @doc "Renders a window body content area."
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec window_body(map()) :: Phoenix.LiveView.Rendered.t()
  def window_body(assigns) do
    ~H"""
    <div class={classes(["p-2 flex-1", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Renders a Win98-style status bar."
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec window_status_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def window_status_bar(assigns) do
    ~H"""
    <div class={classes(["flex gap-[1px] mx-[1px]", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Renders a single field within a status bar."
  attr :class, :any, default: nil
  attr :grow, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  @spec window_status_bar_field(map()) :: Phoenix.LiveView.Rendered.t()
  def window_status_bar_field(assigns) do
    ~H"""
    <div
      class={
        classes([
          "shadow-retro-status px-[3px] py-[2px] text-sm truncate",
          @grow && "flex-grow",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp control_label(:minimize), do: dgettext("ui", "Minimize")
  defp control_label(:maximize), do: dgettext("ui", "Maximize")
  defp control_label(:restore), do: dgettext("ui", "Restore")
  defp control_label(:close), do: dgettext("ui", "Close")
  defp control_label(:help), do: dgettext("ui", "Help")
  defp control_label(other), do: to_string(other)

  attr :control, :atom, required: true

  defp control_icon(%{control: :minimize} = assigns) do
    ~H"""
    <Icons.icon_win_minimize class="w-[6px] h-[2px]" />
    """
  end

  defp control_icon(%{control: :maximize} = assigns) do
    ~H"""
    <Icons.icon_win_maximize class="w-[9px] h-[9px]" />
    """
  end

  defp control_icon(%{control: :restore} = assigns) do
    ~H"""
    <Icons.icon_win_restore class="w-[8px] h-[9px]" />
    """
  end

  defp control_icon(%{control: :close} = assigns) do
    ~H"""
    <Icons.icon_close_pixel class="w-[8px] h-[7px]" />
    """
  end

  defp control_icon(%{control: :help} = assigns) do
    ~H"""
    <Icons.icon_win_help class="w-[6px] h-[9px]" />
    """
  end

  defp control_icon(assigns) do
    ~H"""
    """
  end

  defp ensure_close(controls) do
    if :close in controls, do: controls, else: controls ++ [:close]
  end
end
