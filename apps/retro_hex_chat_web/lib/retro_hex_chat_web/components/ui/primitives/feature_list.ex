defmodule RetroHexChatWeb.Components.UI.FeatureList do
  @moduledoc """
  What something offers, a line each, each line led by its icon: the
  features a page of the site describes, and what an account opens in the
  card that greets a visitor.

  ## Usage

      <.feature_list>
        <:item icon={:icon_p2p}>Direct calls</:item>
      </.feature_list>
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  slot :item, required: true, doc: "one feature, its words" do
    attr :icon, :atom, required: true, doc: "a `RetroHexChatWeb.Icons` function"
  end

  @doc "Renders the list, one icon-led line per item."
  @spec feature_list(map()) :: Phoenix.LiveView.Rendered.t()
  def feature_list(assigns) do
    ~H"""
    <ul class="space-y-1.5">
      <li :for={item <- @item} class="flex items-start gap-2 text-xs">
        {apply(Icons, item.icon, [%{class: "w-4 h-4 shrink-0 mt-0.5"}])}
        <span>{render_slot(item)}</span>
      </li>
    </ul>
    """
  end
end
