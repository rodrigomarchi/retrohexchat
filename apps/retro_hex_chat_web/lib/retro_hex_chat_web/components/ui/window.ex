defmodule RetroHexChatWeb.Components.UI.Window do
  @moduledoc false
  use RetroHexChatWeb.Component

  @doc "Renders a Win98-style window frame."
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec window(map()) :: Phoenix.LiveView.Rendered.t()
  def window(assigns) do
    ~H"""
    <div class={classes(["shadow-retro-window bg-surface p-[3px]", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Renders a Win98-style title bar with gradient and control buttons."
  attr :title, :string, required: true
  attr :inactive, :boolean, default: false
  attr :controls, :list, default: [:minimize, :maximize, :close]
  attr :class, :any, default: nil
  attr :rest, :global

  slot :icon

  @spec window_title_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def window_title_bar(assigns) do
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
        <span :if={@icon != []} class="flex-shrink-0">
          {render_slot(@icon)}
        </span>
        <span class="font-bold text-white text-xs truncate mr-6">{@title}</span>
      </div>
      <div class="flex flex-shrink-0">
        <button
          :for={control <- @controls}
          type="button"
          aria-label={control_label(control)}
          class={[
            "inline-block min-w-[16px] min-h-[14px] p-0 shadow-retro-raised bg-surface",
            "active:shadow-retro-sunken focus:outline-none",
            control == :close && "ml-[2px]",
            control_bg_class(control)
          ]}
        />
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
    <div class={classes(["p-2", @class])} {@rest}>
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

  defp control_label(:minimize), do: "Minimize"
  defp control_label(:maximize), do: "Maximize"
  defp control_label(:restore), do: "Restore"
  defp control_label(:close), do: "Close"
  defp control_label(:help), do: "Help"
  defp control_label(other), do: to_string(other)

  defp control_bg_class(:minimize),
    do:
      "bg-no-repeat [background-position:bottom_3px_left_4px] [background-image:url(\"data:image/svg+xml;charset=utf-8,%3Csvg%20width='6'%20height='2'%20fill='none'%20xmlns='http://www.w3.org/2000/svg'%3E%3Cpath%20fill='%23000'%20d='M0%200h6v2H0z'/%3E%3C/svg%3E\")]"

  defp control_bg_class(:maximize),
    do:
      "bg-no-repeat [background-position:top_2px_left_3px] [background-image:url(\"data:image/svg+xml;charset=utf-8,%3Csvg%20width='9'%20height='9'%20fill='none'%20xmlns='http://www.w3.org/2000/svg'%3E%3Cpath%20fill-rule='evenodd'%20clip-rule='evenodd'%20d='M9%200H0v9h9V0zM8%202H1v6h7V2z'%20fill='%23000'/%3E%3C/svg%3E\")]"

  defp control_bg_class(:restore),
    do:
      "bg-no-repeat [background-position:top_2px_left_3px] [background-image:url(\"data:image/svg+xml;charset=utf-8,%3Csvg%20width='8'%20height='9'%20fill='none'%20xmlns='http://www.w3.org/2000/svg'%3E%3Cpath%20fill='%23000'%20d='M2%200h6v2H2zM7%202h1v4H7zM2%202h1v1H2zM6%205h1v1H6zM0%203h6v2H0zM5%205h1v4H5zM0%205h1v4H0zM1%208h4v1H1z'/%3E%3C/svg%3E\")]"

  defp control_bg_class(:close),
    do:
      "bg-no-repeat [background-position:top_3px_left_4px] [background-image:url(\"data:image/svg+xml;charset=utf-8,%3Csvg%20width='8'%20height='7'%20fill='none'%20xmlns='http://www.w3.org/2000/svg'%3E%3Cpath%20fill-rule='evenodd'%20clip-rule='evenodd'%20d='M0%200h2v1h1v1h2V1h1V0h2v1H7v1H6v1H5v1h1v1h1v1h1v1H6V6H5V5H3v1H2v1H0V6h1V5h1V4h1V3H2V2H1V1H0V0z'%20fill='%23000'/%3E%3C/svg%3E\")]"

  defp control_bg_class(:help),
    do:
      "bg-no-repeat [background-position:top_2px_left_5px] [background-image:url(\"data:image/svg+xml;charset=utf-8,%3Csvg%20width='6'%20height='9'%20fill='none'%20xmlns='http://www.w3.org/2000/svg'%3E%3Cpath%20fill='%23000'%20d='M0%201h2v2H0zM1%200h4v1H1zM4%201h2v2H4zM3%203h2v1H3zM2%204h2v2H2zM2%207h2v2H2z'/%3E%3C/svg%3E\")]"

  defp control_bg_class(_), do: ""
end
