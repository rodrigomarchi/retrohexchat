defmodule RetroHexChatWeb.HelpContent.Helpers do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChatWeb.Components.UI.Site.Section
  alias RetroHexChatWeb.GameCatalog
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PublicPages

  @doc "Section heading with icon, used inside help content templates."
  attr :icon, :atom, required: true
  slot :inner_block, required: true

  @spec help_h4(map()) :: Phoenix.LiveView.Rendered.t()
  def help_h4(assigns) do
    ~H"""
    <h4 class="flex items-center gap-1.5 text-sm font-bold mt-4 mb-1.5 text-text">
      <.help_icon name={@icon} class="w-3.5 h-3.5 flex-shrink-0" />
      {render_slot(@inner_block)}
    </h4>
    """
  end

  @doc "Cross-reference link to another help topic."
  attr :topic, :string, required: true
  slot :inner_block, required: true

  @spec help_link(map()) :: Phoenix.LiveView.Rendered.t()
  def help_link(assigns) do
    ~H"""
    <.link
      patch={PublicPages.help_topic_path(@topic)}
      class="text-link hover:underline"
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc "Link to one of the site's public pages, by its name: `<.page_link page={:spaces}>`."
  @spec page_link(map()) :: Phoenix.LiveView.Rendered.t()
  defdelegate page_link(assigns), to: Section

  @doc "A key the topic names, drawn as the key (`Components.UI.Keycap`)."
  @spec keycap(map()) :: Phoenix.LiveView.Rendered.t()
  defdelegate keycap(assigns), to: RetroHexChatWeb.Components.UI.Keycap

  @doc """
  The games of the catalogue, read from it so the help never lists fewer than
  there are, on the same category shelves as the app's folders. Each name opens
  the game's page — its screenshot, keys and tips — and How to play opens its
  topic.
  """
  attr :kind, :atom, required: true, values: [:arcade, :multiplayer]

  @spec help_game_list(map()) :: Phoenix.LiveView.Rendered.t()
  def help_game_list(assigns) do
    assigns = assign(assigns, :groups, GameCatalog.cards(assigns.kind))

    ~H"""
    <div data-testid={"help-games-#{@kind}"}>
      <section :for={group <- @groups} data-testid={"help-games-#{group.category}"}>
        <h4 class="flex items-center gap-1.5 text-sm font-bold mt-4 mb-1.5 text-text">
          {apply(Icons, group.icon_fn, [%{class: "w-3.5 h-3.5 flex-shrink-0"}])}
          {group.name}
        </h4>
        <ul>
          <.help_game_item :for={card <- group.cards} card={card} />
        </ul>
      </section>
    </div>
    """
  end

  attr :card, :map, required: true

  defp help_game_item(assigns) do
    ~H"""
    <li>
      <.link patch={@card.path} class="text-link hover:underline font-bold">
        {@card.game.name}
      </.link>
      — {@card.game.tagline} ·
      <.help_link topic={@card.game.help_topic}>{dgettext("games", "How to play")}</.help_link>
    </li>
    """
  end

  @doc "Render an icon by name. Dispatches to the Icons facade at runtime."
  attr :name, :atom, required: true
  attr :class, :string, default: "w-3.5 h-3.5"

  @spec help_icon(map()) :: Phoenix.LiveView.Rendered.t()
  def help_icon(assigns) do
    apply(Icons, assigns.name, [%{class: assigns.class}])
  end
end
