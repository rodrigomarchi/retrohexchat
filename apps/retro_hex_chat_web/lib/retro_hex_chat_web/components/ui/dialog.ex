defmodule RetroHexChatWeb.Components.UI.Dialog do
  @moduledoc """
  Win98-style dialog component for the showcase design system.
  Visually matches the platform's retro dialog windows.
  """
  use RetroHexChatWeb.Component

  @doc """
  Dialog component — renders a Win98-style modal window.

  ## Examples:

      <.dialog id="my-dialog">
        <.dialog_header>
          <.dialog_title>Edit Profile</.dialog_title>
        </.dialog_header>
        <div class="p-retro-12">
          Content here
        </div>
        <.dialog_footer>
          <.button phx-click={hide_modal("my-dialog")}>Save</.button>
        </.dialog_footer>
      </.dialog>
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def dialog(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && JS.exec("phx-show-modal", to: "##{@id}")}
      phx-show-modal={show_modal(@id)}
      phx-hide-modal={@on_cancel |> hide_modal(@id)}
      class="relative z-modal hidden group/dialog"
    >
      <%!-- Overlay --%>
      <div
        id={"#{@id}-bg"}
        class="fixed inset-0 bg-black/30 group-data-[state=open]/dialog:animate-in group-data-[state=closed]/dialog:animate-out group-data-[state=closed]/dialog:fade-out-0 group-data-[state=open]/dialog:fade-in-0"
        aria-hidden="true"
      />
      <%!-- Centering container --%>
      <div
        class="fixed inset-0 flex items-center justify-center overflow-y-auto"
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <.focus_wrap
          id={"#{@id}-wrap"}
          phx-window-keydown={JS.exec("phx-hide-modal", to: "##{@id}")}
          phx-key="escape"
          phx-click-away={JS.exec("phx-hide-modal", to: "##{@id}")}
          class={classes(["w-full max-w-lg", @class])}
        >
          <%!-- Window frame (Win98 3D border) --%>
          <div class="bg-surface shadow-retro-window p-[3px]">
            {render_slot(@inner_block)}
          </div>
        </.focus_wrap>
      </div>
    </div>
    """
  end

  @doc """
  Dialog header — renders the Win98 blue gradient title bar.
  Children are laid out in a single flex row. Place dialog_icon, dialog_title,
  and dialog_close directly inside.
  """
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def dialog_header(assigns) do
    ~H"""
    <div class={classes(["bg-title-bar flex items-center gap-retro-4 px-retro-2 py-retro-2", @class])}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Dialog icon — small 16×16 icon in the title bar, before the title.
  Pass an SVG or image as the inner block.
  """
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def dialog_icon(assigns) do
    ~H"""
    <span class={classes(["shrink-0 flex items-center justify-center w-[16px] h-[16px]", @class])}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  Dialog title — white bold text for the title bar.
  """
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def dialog_title(assigns) do
    ~H"""
    <span class={classes(["text-xs font-bold text-white truncate select-none", @class])}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  Dialog description — body text below the title bar.
  """
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def dialog_description(assigns) do
    ~H"""
    <p class={classes(["text-sm text-foreground", @class])}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Dialog close button — Win98-style X button for the title bar.
  Must be placed inside dialog_header.
  """
  attr :id, :string, required: true
  attr :class, :string, default: nil

  def dialog_close(assigns) do
    ~H"""
    <button
      type="button"
      class={classes([
        "bg-surface shadow-retro-raised active:shadow-retro-sunken",
        "flex items-center justify-center shrink-0 ml-auto",
        "w-[16px] h-[14px]",
        @class
      ])}
      phx-click={JS.exec("phx-hide-modal", to: "##{@id}")}
      aria-label="Close"
    >
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 8 7" class="w-[8px] h-[7px]">
        <path d="M0 0L1 0L4 3L7 0L8 0L8 1L5 4L8 7L7 7L4 4L1 7L0 7L3 4L0 1Z" fill="#000" />
      </svg>
    </button>
    """
  end

  @doc """
  Dialog body — content area with padding.
  """
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def dialog_body(assigns) do
    ~H"""
    <div class={classes(["p-retro-12", @class])}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Dialog footer — button bar at the bottom.
  """
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def dialog_footer(assigns) do
    ~H"""
    <div class={classes(["flex justify-end gap-retro-4 px-retro-12 pb-retro-12", @class])}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @spec show_modal(Phoenix.LiveView.JS.t(), String.t()) :: Phoenix.LiveView.JS.t()
  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.set_attribute({"data-state", "open"}, to: "##{id}")
    |> JS.show(to: "##{id}", transition: {"_", "_", "_"}, time: 130)
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  @spec hide_modal(Phoenix.LiveView.JS.t(), String.t()) :: Phoenix.LiveView.JS.t()
  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.set_attribute({"data-state", "closed"}, to: "##{id}")
    |> JS.hide(to: "##{id}", transition: {"_", "_", "_"}, time: 130)
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end
end
