defmodule RetroHexChatWeb.Components.UI.Tabs do
  @moduledoc """
  Implementation of tabs components from https://ui.shadcn.com/docs/components/tabs

  ## Example:

      <.tabs default="account" id="settings" :let={builder} class="w-[400px]">
        <.tabs_list class="grid w-full grid-cols-2">
          <.tabs_trigger builder={builder} value="account">account</.tabs_trigger>
          <.tabs_trigger builder={builder} value="password">password</.tabs_trigger>
        </.tabs_list>
        <.tabs_content value="account">
          <.card>
            <.card_content class="p-6">
              Account
            </.card_content>
          </.card>
        </.tabs_content>
        <.tabs_content value="password">
          <.card>
            <.card_content class="p-6">
              Password
            </.card_content>
          </.card>
        </.tabs_content>
      </.tabs>
  """
  use RetroHexChatWeb.Component

  attr :id, :string, required: true, doc: "id for root tabs tag"
  attr :default, :string, default: nil, doc: "default tab value"
  attr :class, :string, default: nil
  slot :inner_block, required: true
  attr :rest, :global

  def tabs(assigns) do
    assigns = assign(assigns, :builder, %{default: assigns.default, id: assigns.id})

    ~H"""
    <div class={@class} id={@id} {@rest} phx-mounted={show_tab(@id, @default)}>
      {render_slot(@inner_block, @builder)}
    </div>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true
  attr :rest, :global

  def tabs_list(assigns) do
    ~H"""
    <div
      class={
        classes([
          "inline-flex h-10 items-center justify-center bg-surface p-1 text-foreground",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :builder, :map, required: true, doc: "builder instance of tabs"
  attr :value, :string, required: true, doc: "target value of tab content"
  attr :class, :string, default: nil
  slot :inner_block, required: true
  attr :rest, :global

  def tabs_trigger(assigns) do
    ~H"""
    <button
      class={
        classes([
          "tabs-trigger",
          "inline-flex items-center justify-center whitespace-nowrap shadow-retro-tab px-3 py-1.5 text-sm font-medium focus-visible:outline focus-visible:outline-2 focus-visible:outline-black disabled:pointer-events-none disabled:opacity-50 data-[state=active]:bg-surface data-[state=active]:text-foreground data-[state=active]:font-bold",
          @class
        ])
      }
      data-target={@value}
      {@rest}
      phx-click={show_tab(@builder.id, @value)}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :value, :string, required: true, doc: "unique for tab content"
  attr :class, :string, default: nil
  slot :inner_block, required: true
  attr :rest, :global

  def tabs_content(assigns) do
    ~H"""
    <div
      class={
        classes([
          "tabs-content",
          "mt-2 shadow-retro-window bg-surface p-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-black",
          @class
        ])
      }
      value={@value}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  # Set selected tab to active
  # show appropriate tab content
  defp show_tab(root, value) do
    %JS{}
    |> JS.set_attribute({"data-state", ""}, to: "##{root} .tabs-trigger[data-state=active]")
    |> JS.set_attribute({"data-state", "active"},
      to: "##{root} .tabs-trigger[data-target=#{value}]"
    )
    |> JS.hide(to: "##{root} .tabs-content:not([value=#{value}])")
    |> JS.show(to: "##{root} .tabs-content[value=#{value}]")
  end
end
