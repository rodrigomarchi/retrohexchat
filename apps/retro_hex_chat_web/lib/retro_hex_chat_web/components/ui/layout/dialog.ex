defmodule RetroHexChatWeb.Components.UI.Dialog do
  @moduledoc """
  Win98-style dialog component for the showcase design system.
  Visually matches the platform's retro dialog windows.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

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
  attr :on_cancel, :any, default: nil
  attr :lock, :boolean, default: false, doc: "When true, disables click-away and escape dismissal"
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def dialog(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && JS.exec("phx-show-modal", to: "##{@id}")}
      phx-show-modal={show_modal(@id)}
      phx-hide-modal={close_modal(@on_cancel, @id)}
      class={classes(["relative z-modal group/dialog", !@show && "hidden"])}
    >
      <%!-- Server-driven show/hide trigger: mounts when show=true, removed when show=false --%>
      <div
        :if={@show}
        id={"#{@id}-show-trigger"}
        phx-mounted={JS.exec("phx-show-modal", to: "##{@id}")}
        phx-remove={JS.exec("phx-hide-modal", to: "##{@id}")}
        class="hidden"
      />
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
          phx-window-keydown={!@lock && close_modal(@on_cancel, @id)}
          phx-key="escape"
          phx-click-away={!@lock && close_modal(@on_cancel, @id)}
          class={classes(["w-full max-w-none md:max-w-lg p-0 md:p-4", @class])}
        >
          <%!-- Window frame (Win98 3D border) --%>
          <div
            id={"#{@id}-surface"}
            class="bg-surface shadow-retro-window p-[3px] min-h-[100dvh] md:min-h-0"
          >
            {render_slot(@inner_block)}
          </div>
        </.focus_wrap>
      </div>
    </div>
    """
  end

  @doc """
  Dialog header — renders the Win98 blue gradient title bar with mandatory icon,
  title, and close button. Guarantees visual consistency across all dialogs.

  ## Examples

      <.dialog_header id="my-dialog" title="Edit Profile">
        <:icon><Icons.icon_btn_edit /></:icon>
      </.dialog_header>
  """
  attr :id, :string, required: true, doc: "Dialog id — used by the close button"
  attr :title, :string, required: true, doc: "Title text displayed in the title bar"
  attr :on_close, :any, default: nil
  attr :class, :string, default: nil
  slot :icon, required: true, doc: "16×16 title bar icon — mandatory"

  def dialog_header(assigns) do
    ~H"""
    <div class={classes(["bg-title-bar flex items-center gap-retro-4 px-retro-2 py-retro-2", @class])}>
      <.dialog_icon>{render_slot(@icon)}</.dialog_icon>
      <.dialog_title>{@title}</.dialog_title>
      <.dialog_close id={@id} on_close={@on_close} />
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
  attr :on_close, :any, default: nil
  attr :class, :string, default: nil

  def dialog_close(assigns) do
    ~H"""
    <button
      type="button"
      class={
        classes([
          "bg-surface shadow-retro-raised active:shadow-retro-sunken",
          "flex items-center justify-center shrink-0 ml-auto",
          "w-[16px] h-[14px]",
          @class
        ])
      }
      phx-click={close_modal(@on_close, @id)}
      aria-label={gettext("Close")}
    >
      <Icons.icon_close_pixel class="w-[8px] h-[7px]" />
    </button>
    """
  end

  defp close_modal(nil, id), do: hide_modal(id)
  defp close_modal(%JS{} = js, id), do: hide_modal(js, id)
  defp close_modal(event, id) when is_binary(event), do: JS.push(event) |> hide_modal(id)

  @doc """
  Dialog body — content area with padding.
  """
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def dialog_body(assigns) do
    ~H"""
    <div class={classes(["p-retro-12 overflow-y-auto", @class])}>
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

  @spec show_modal(String.t()) :: Phoenix.LiveView.JS.t()
  def show_modal(id) when is_binary(id) do
    JS.set_attribute(%JS{}, {"data-state", "open"}, to: "##{id}")
    |> JS.show(to: "##{id}", transition: {"_", "_", "_"}, time: 130)
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.push_focus()
    |> JS.focus_first(to: "##{id}-surface")
  end

  @spec show_modal(Phoenix.LiveView.JS.t(), String.t()) :: Phoenix.LiveView.JS.t()
  def show_modal(%JS{} = js, id) when is_binary(id) do
    js
    |> JS.set_attribute({"data-state", "open"}, to: "##{id}")
    |> JS.show(to: "##{id}", transition: {"_", "_", "_"}, time: 130)
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.push_focus()
    |> JS.focus_first(to: "##{id}-surface")
  end

  @spec hide_modal(String.t()) :: Phoenix.LiveView.JS.t()
  def hide_modal(id) when is_binary(id) do
    JS.set_attribute(%JS{}, {"data-state", "closed"}, to: "##{id}")
    |> JS.hide(to: "##{id}", transition: {"_", "_", "_"}, time: 130)
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @spec hide_modal(Phoenix.LiveView.JS.t(), String.t()) :: Phoenix.LiveView.JS.t()
  def hide_modal(%JS{} = js, id) do
    js
    |> JS.set_attribute({"data-state", "closed"}, to: "##{id}")
    |> JS.hide(to: "##{id}", transition: {"_", "_", "_"}, time: 130)
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end
end
