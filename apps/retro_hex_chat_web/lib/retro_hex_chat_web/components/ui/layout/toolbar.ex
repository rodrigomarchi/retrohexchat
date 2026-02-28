defmodule RetroHexChatWeb.Components.UI.Toolbar do
  @moduledoc false
  use RetroHexChatWeb.Component

  @doc "Renders a Win98-style toolbar container."
  attr :variant, :string, values: ~w(default compact), default: "default"
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec toolbar(map()) :: Phoenix.LiveView.Rendered.t()
  def toolbar(assigns) do
    ~H"""
    <div
      class={classes(["flex items-center bg-surface", @class])}
      role="toolbar"
      data-variant={@variant}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Renders a toolbar button with icon content."
  attr :label, :string, default: nil
  attr :active, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :variant, :string, values: ~w(default compact), default: "default"
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec toolbar_button(map()) :: Phoenix.LiveView.Rendered.t()
  def toolbar_button(assigns) do
    ~H"""
    <button
      type="button"
      title={@label}
      disabled={@disabled}
      class={
        classes([
          "inline-flex items-center justify-center p-0 cursor-pointer",
          "border border-transparent hover:shadow-retro-raised",
          "active:shadow-retro-sunken focus:outline-none",
          "disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:shadow-none",
          if(@active, do: "shadow-retro-sunken bg-hover-bg", else: "bg-surface"),
          size_classes(@variant),
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc "Renders a vertical separator between toolbar buttons."
  attr :variant, :string, values: ~w(default compact), default: "default"
  attr :class, :any, default: nil

  @spec toolbar_separator(map()) :: Phoenix.LiveView.Rendered.t()
  def toolbar_separator(assigns) do
    ~H"""
    <div class={
      classes([
        "mx-[2px]",
        if(@variant == "compact",
          do: "w-[1px] h-[18px] bg-gray-500",
          else: "w-[1px] h-[24px] bg-gray-500"
        ),
        @class
      ])
    } />
    """
  end

  defp size_classes("compact"),
    do: "w-[24px] min-w-[24px] h-[24px] min-h-[24px]"

  defp size_classes(_default),
    do: "w-[34px] min-w-[34px] h-[34px] min-h-[34px]"
end
