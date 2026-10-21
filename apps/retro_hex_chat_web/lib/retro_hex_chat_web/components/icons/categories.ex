defmodule RetroHexChatWeb.Icons.Categories do
  @moduledoc """
  Channel subject plaques (14×14): what a channel is about — news, games,
  sport — as a coloured field with a white pixel glyph, beside the channel's
  name and its language flag.

  Each plaque has the language flags' footprint — a 12×9 field inside a 1px
  black outline, vertically centred in the 14×14 viewBox — so the two read as
  a pair. The colour tells the categories apart at a glance; the glyph says
  which one it is. The set is `RetroHexChat.Channels.Categories`.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @doc "The social plaque: a speech bubble."
  @spec icon_category_social(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_category_social(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#7B3FA0" />
      <rect x="4" y="4" width="6" height="1" fill="#fff" />
      <rect x="3" y="5" width="8" height="1" fill="#fff" />
      <rect x="3" y="6" width="8" height="1" fill="#fff" />
      <rect x="3" y="7" width="8" height="1" fill="#fff" />
      <rect x="4" y="8" width="6" height="1" fill="#fff" />
      <rect x="5" y="9" width="2" height="1" fill="#fff" />
      <rect x="4" y="10" width="1" height="1" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @doc "The news plaque: a folded newspaper."
  @spec icon_category_news(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_category_news(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#B3261E" />
      <rect x="3" y="4" width="7" height="1" fill="#fff" />
      <rect x="3" y="5" width="1" height="1" fill="#fff" />
      <rect x="9" y="5" width="2" height="1" fill="#fff" />
      <rect x="3" y="6" width="1" height="1" fill="#fff" />
      <rect x="5" y="6" width="3" height="1" fill="#fff" />
      <rect x="9" y="6" width="2" height="1" fill="#fff" />
      <rect x="3" y="7" width="1" height="1" fill="#fff" />
      <rect x="9" y="7" width="2" height="1" fill="#fff" />
      <rect x="3" y="8" width="1" height="1" fill="#fff" />
      <rect x="5" y="8" width="3" height="1" fill="#fff" />
      <rect x="9" y="8" width="2" height="1" fill="#fff" />
      <rect x="3" y="9" width="1" height="1" fill="#fff" />
      <rect x="9" y="9" width="2" height="1" fill="#fff" />
      <rect x="3" y="10" width="8" height="1" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @doc "The tech plaque: a monitor on its stand."
  @spec icon_category_tech(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_category_tech(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#1F5FB8" />
      <rect x="3" y="4" width="8" height="1" fill="#fff" />
      <rect x="3" y="5" width="1" height="1" fill="#fff" />
      <rect x="10" y="5" width="1" height="1" fill="#fff" />
      <rect x="3" y="6" width="1" height="1" fill="#fff" />
      <rect x="10" y="6" width="1" height="1" fill="#fff" />
      <rect x="3" y="7" width="1" height="1" fill="#fff" />
      <rect x="10" y="7" width="1" height="1" fill="#fff" />
      <rect x="3" y="8" width="8" height="1" fill="#fff" />
      <rect x="6" y="9" width="2" height="1" fill="#fff" />
      <rect x="4" y="10" width="6" height="1" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @doc "The dev plaque: the brackets of a tag."
  @spec icon_category_dev(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_category_dev(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#2B2B2B" />
      <rect x="8" y="4" width="1" height="1" fill="#fff" />
      <rect x="4" y="5" width="1" height="1" fill="#fff" />
      <rect x="7" y="5" width="1" height="1" fill="#fff" />
      <rect x="10" y="5" width="1" height="1" fill="#fff" />
      <rect x="3" y="6" width="1" height="1" fill="#fff" />
      <rect x="7" y="6" width="1" height="1" fill="#fff" />
      <rect x="11" y="6" width="1" height="1" fill="#fff" />
      <rect x="2" y="7" width="1" height="1" fill="#fff" />
      <rect x="6" y="7" width="1" height="1" fill="#fff" />
      <rect x="3" y="8" width="1" height="1" fill="#fff" />
      <rect x="6" y="8" width="1" height="1" fill="#fff" />
      <rect x="11" y="8" width="1" height="1" fill="#fff" />
      <rect x="4" y="9" width="1" height="1" fill="#fff" />
      <rect x="6" y="9" width="1" height="1" fill="#fff" />
      <rect x="10" y="9" width="1" height="1" fill="#fff" />
      <rect x="5" y="10" width="1" height="1" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @doc "The security plaque: a padlock."
  @spec icon_category_security(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_category_security(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#455A64" />
      <rect x="5" y="4" width="4" height="1" fill="#fff" />
      <rect x="4" y="5" width="1" height="1" fill="#fff" />
      <rect x="9" y="5" width="1" height="1" fill="#fff" />
      <rect x="4" y="6" width="1" height="1" fill="#fff" />
      <rect x="9" y="6" width="1" height="1" fill="#fff" />
      <rect x="3" y="7" width="8" height="1" fill="#fff" />
      <rect x="3" y="8" width="3" height="1" fill="#fff" />
      <rect x="8" y="8" width="3" height="1" fill="#fff" />
      <rect x="3" y="9" width="3" height="1" fill="#fff" />
      <rect x="8" y="9" width="3" height="1" fill="#fff" />
      <rect x="3" y="10" width="8" height="1" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @doc "The ai plaque: the letters AI."
  @spec icon_category_ai(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_category_ai(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#00897B" />
      <rect x="4" y="4" width="2" height="1" fill="#fff" />
      <rect x="8" y="4" width="3" height="1" fill="#fff" />
      <rect x="3" y="5" width="1" height="1" fill="#fff" />
      <rect x="6" y="5" width="1" height="1" fill="#fff" />
      <rect x="9" y="5" width="1" height="1" fill="#fff" />
      <rect x="3" y="6" width="1" height="1" fill="#fff" />
      <rect x="6" y="6" width="1" height="1" fill="#fff" />
      <rect x="9" y="6" width="1" height="1" fill="#fff" />
      <rect x="3" y="7" width="4" height="1" fill="#fff" />
      <rect x="9" y="7" width="1" height="1" fill="#fff" />
      <rect x="3" y="8" width="1" height="1" fill="#fff" />
      <rect x="6" y="8" width="1" height="1" fill="#fff" />
      <rect x="9" y="8" width="1" height="1" fill="#fff" />
      <rect x="3" y="9" width="1" height="1" fill="#fff" />
      <rect x="6" y="9" width="1" height="1" fill="#fff" />
      <rect x="9" y="9" width="1" height="1" fill="#fff" />
      <rect x="3" y="10" width="1" height="1" fill="#fff" />
      <rect x="6" y="10" width="1" height="1" fill="#fff" />
      <rect x="8" y="10" width="3" height="1" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @doc "The science plaque: a laboratory flask."
  @spec icon_category_science(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_category_science(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#3949AB" />
      <rect x="5" y="4" width="4" height="1" fill="#fff" />
      <rect x="6" y="5" width="2" height="1" fill="#fff" />
      <rect x="6" y="6" width="2" height="1" fill="#fff" />
      <rect x="5" y="7" width="4" height="1" fill="#fff" />
      <rect x="4" y="8" width="6" height="1" fill="#fff" />
      <rect x="3" y="9" width="8" height="1" fill="#fff" />
      <rect x="3" y="10" width="8" height="1" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @doc "The games plaque: a gamepad."
  @spec icon_category_games(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_category_games(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#E65100" />
      <rect x="3" y="5" width="8" height="1" fill="#fff" />
      <rect x="2" y="6" width="2" height="1" fill="#fff" />
      <rect x="5" y="6" width="4" height="1" fill="#fff" />
      <rect x="10" y="6" width="2" height="1" fill="#fff" />
      <rect x="2" y="7" width="1" height="1" fill="#fff" />
      <rect x="6" y="7" width="2" height="1" fill="#fff" />
      <rect x="9" y="7" width="1" height="1" fill="#fff" />
      <rect x="11" y="7" width="1" height="1" fill="#fff" />
      <rect x="2" y="8" width="2" height="1" fill="#fff" />
      <rect x="5" y="8" width="4" height="1" fill="#fff" />
      <rect x="10" y="8" width="2" height="1" fill="#fff" />
      <rect x="2" y="9" width="10" height="1" fill="#fff" />
      <rect x="2" y="10" width="3" height="1" fill="#fff" />
      <rect x="9" y="10" width="3" height="1" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @doc "The sports plaque: a ball."
  @spec icon_category_sports(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_category_sports(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#2E7D32" />
      <rect x="5" y="4" width="4" height="1" fill="#fff" />
      <rect x="4" y="5" width="6" height="1" fill="#fff" />
      <rect x="3" y="6" width="3" height="1" fill="#fff" />
      <rect x="8" y="6" width="3" height="1" fill="#fff" />
      <rect x="3" y="7" width="2" height="1" fill="#fff" />
      <rect x="9" y="7" width="2" height="1" fill="#fff" />
      <rect x="3" y="8" width="3" height="1" fill="#fff" />
      <rect x="8" y="8" width="3" height="1" fill="#fff" />
      <rect x="4" y="9" width="6" height="1" fill="#fff" />
      <rect x="5" y="10" width="4" height="1" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @doc "The money plaque: a dollar sign."
  @spec icon_category_money(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_category_money(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#9A7400" />
      <rect x="6" y="4" width="1" height="1" fill="#fff" />
      <rect x="5" y="5" width="4" height="1" fill="#fff" />
      <rect x="4" y="6" width="1" height="1" fill="#fff" />
      <rect x="6" y="6" width="1" height="1" fill="#fff" />
      <rect x="5" y="7" width="3" height="1" fill="#fff" />
      <rect x="6" y="8" width="1" height="1" fill="#fff" />
      <rect x="8" y="8" width="1" height="1" fill="#fff" />
      <rect x="4" y="9" width="4" height="1" fill="#fff" />
      <rect x="6" y="10" width="1" height="1" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @doc "The culture plaque: two beamed notes."
  @spec icon_category_culture(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_category_culture(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#C2185B" />
      <rect x="5" y="4" width="6" height="1" fill="#fff" />
      <rect x="5" y="5" width="1" height="1" fill="#fff" />
      <rect x="10" y="5" width="1" height="1" fill="#fff" />
      <rect x="5" y="6" width="1" height="1" fill="#fff" />
      <rect x="10" y="6" width="1" height="1" fill="#fff" />
      <rect x="5" y="7" width="1" height="1" fill="#fff" />
      <rect x="10" y="7" width="1" height="1" fill="#fff" />
      <rect x="3" y="8" width="3" height="1" fill="#fff" />
      <rect x="8" y="8" width="3" height="1" fill="#fff" />
      <rect x="3" y="9" width="3" height="1" fill="#fff" />
      <rect x="8" y="9" width="3" height="1" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @doc "The life plaque: a heart."
  @spec icon_category_life(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_category_life(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#8D5524" />
      <rect x="4" y="4" width="2" height="1" fill="#fff" />
      <rect x="7" y="4" width="2" height="1" fill="#fff" />
      <rect x="3" y="5" width="7" height="1" fill="#fff" />
      <rect x="3" y="6" width="7" height="1" fill="#fff" />
      <rect x="4" y="7" width="5" height="1" fill="#fff" />
      <rect x="5" y="8" width="3" height="1" fill="#fff" />
      <rect x="6" y="9" width="1" height="1" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @doc "The retro plaque: a floppy disk."
  @spec icon_category_retro(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_category_retro(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#000080" />
      <rect x="3" y="4" width="7" height="1" fill="#fff" />
      <rect x="3" y="5" width="2" height="1" fill="#fff" />
      <rect x="8" y="5" width="1" height="1" fill="#fff" />
      <rect x="10" y="5" width="1" height="1" fill="#fff" />
      <rect x="3" y="6" width="2" height="1" fill="#fff" />
      <rect x="8" y="6" width="3" height="1" fill="#fff" />
      <rect x="3" y="7" width="8" height="1" fill="#fff" />
      <rect x="3" y="8" width="1" height="1" fill="#fff" />
      <rect x="10" y="8" width="1" height="1" fill="#fff" />
      <rect x="3" y="9" width="1" height="1" fill="#fff" />
      <rect x="10" y="9" width="1" height="1" fill="#fff" />
      <rect x="3" y="10" width="8" height="1" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @doc "The help plaque: a question mark."
  @spec icon_category_help(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_category_help(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#008080" />
      <rect x="5" y="4" width="4" height="1" fill="#fff" />
      <rect x="4" y="5" width="2" height="1" fill="#fff" />
      <rect x="8" y="5" width="2" height="1" fill="#fff" />
      <rect x="8" y="6" width="2" height="1" fill="#fff" />
      <rect x="6" y="7" width="3" height="1" fill="#fff" />
      <rect x="6" y="8" width="2" height="1" fill="#fff" />
      <rect x="6" y="10" width="2" height="1" fill="#fff" />
    </svg>
    """
  end
end
