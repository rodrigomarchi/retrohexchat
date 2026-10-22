defmodule RetroHexChatWeb.Components.UI.Landing.GameCards do
  @moduledoc """
  The public games catalogue's pieces: a game's screenshot, the card that links
  to its page, the page's body, and the link other pages use to reach it.

  The catalogue's windows and a game's page are bodies of windows the page
  declares (`RetroHexChatWeb.Site.Window`). Built on the shared `card` and
  `button` primitives and the
  same `game_icon` the in-app library uses, so a game looks like itself on the
  public page and in the app. Every path arrives prepared by the page — these
  components never read the locale or build an address themselves.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Card

  alias RetroHexChatWeb.Components.UI.GameSheet
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.Site.Window

  attr :game, :map, required: true, doc: "a `RetroHexChatWeb.GameCatalog` game"

  attr :main, :boolean,
    default: false,
    doc: "the page's own picture: described, and fetched first"

  attr :class, :string, default: nil

  @doc """
  The game's screenshot at its real size, so the page does not jump when it
  loads. Inside a card it is decoration — the card's link already names the
  game — so only the page's main picture carries alt text. A game captured
  nowhere yet shows its icon instead of an empty box.
  """
  @spec game_screenshot(map()) :: Phoenix.LiveView.Rendered.t()
  def game_screenshot(%{game: %{screenshot: nil}} = assigns) do
    ~H"""
    <div class={classes(["flex aspect-[4/3] items-center justify-center bg-black", @class])}>
      <Icons.game_icon game_id={@game.id} class="h-16 w-16" />
    </div>
    """
  end

  def game_screenshot(%{main: true} = assigns) do
    ~H"""
    <img
      src={@game.screenshot.path}
      width={@game.screenshot.width}
      height={@game.screenshot.height}
      alt={dgettext("landing", "Screenshot of %{name}", name: @game.name)}
      fetchpriority="high"
      class={classes(["block h-auto w-full bg-black", @class])}
    />
    """
  end

  def game_screenshot(assigns) do
    ~H"""
    <img
      src={@game.screenshot.path}
      width={@game.screenshot.width}
      height={@game.screenshot.height}
      alt=""
      loading="lazy"
      decoding="async"
      class={classes(["block h-auto w-full bg-black", @class])}
    />
    """
  end

  attr :game, :map, required: true, doc: "a `RetroHexChatWeb.GameCatalog` game"

  attr :path, :string,
    required: true,
    doc: "where the card leads: the game's page, or in the chat the Arcade open on it"

  attr :heading, :string, default: "h3", doc: "the name's tag, one level below the list's"
  attr :testid, :string, default: nil

  @doc """
  A game in a list: its picture, its name and its line, as one link — to its
  page on the site, or in the chat to the Arcade open on its sheet.
  """
  @spec game_card(map()) :: Phoenix.LiveView.Rendered.t()
  def game_card(assigns) do
    ~H"""
    <.link
      patch={@path}
      class="block h-full no-underline text-inherit"
      data-testid={@testid || "game-card-#{@game.slug}"}
    >
      <.card class="h-full">
        <.game_screenshot game={@game} />
        <.card_header>
          <:icon><Icons.game_icon game_id={@game.id} class="h-4 w-4" /></:icon>
          <.dynamic tag={@heading} class="text-sm font-bold leading-tight tracking-tight">
            {@game.name}
          </.dynamic>
        </.card_header>
        <.card_content>
          <.card_description>{@game.tagline}</.card_description>
        </.card_content>
      </.card>
    </.link>
    """
  end

  attr :groups, :list,
    required: true,
    doc: "%{engine, name, cards: [%{game, path, testid?}]} per engine"

  attr :columns, :string, required: true, doc: "the grid's columns"

  @doc """
  The arcade's cards under their engines (`GameCatalog.arcade_groups/0`): the
  same grouping on the public catalogue and in the in-app Arcade.
  """
  @spec game_card_groups(map()) :: Phoenix.LiveView.Rendered.t()
  def game_card_groups(assigns) do
    ~H"""
    <section
      :for={group <- @groups}
      class="mb-4 last:mb-0"
      data-testid={"game-group-#{group.engine}"}
    >
      <h3 class="text-xs font-bold mb-2">
        {dgettext("games", "%{engine} Engine", engine: group.name)}
      </h3>
      <div class={["grid gap-3", @columns]}>
        <.game_card
          :for={card <- group.cards}
          game={card.game}
          path={card.path}
          heading="h4"
          testid={card[:testid]}
        />
      </div>
    </section>
    """
  end

  attr :groups, :list, required: true, doc: "`GameCatalog.arcade_cards/0`"
  attr :rest, :global

  @doc """
  The arcade in a few lines: each engine, then its games as icons that open
  their pages — the short form of the catalogue a page's summary window shows.
  """
  @spec arcade_game_links(map()) :: Phoenix.LiveView.Rendered.t()
  def arcade_game_links(assigns) do
    ~H"""
    <div class="space-y-retro-8" {@rest}>
      <section :for={group <- @groups}>
        <h4 class="text-xs font-bold mb-retro-4">
          {dgettext("games", "%{engine} Engine", engine: group.name)}
        </h4>
        <ul class="grid grid-cols-[repeat(auto-fill,minmax(88px,1fr))] gap-retro-6">
          <li :for={card <- group.cards}>
            <.link
              patch={card.path}
              class="flex flex-col items-center gap-retro-2 text-center text-xs hover:underline"
              data-testid={"arcade-link-#{card.game.slug}"}
            >
              <Icons.game_icon game_id={card.game.id} class="h-8 w-8" />
              <span class="leading-tight">{card.game.name}</span>
            </.link>
          </li>
        </ul>
      </section>
    </div>
    """
  end

  attr :window, Window, required: true
  attr :heading_id, :string, required: true
  attr :cards, :list, default: [], doc: "%{game, path} per card"
  attr :groups, :list, default: nil, doc: "the cards under their engines, instead of `cards`"
  attr :columns, :string, required: true, doc: "the grid's columns"

  attr :catalogue_path, :string,
    required: true,
    doc: "a link to the whole catalogue under the cards, or nil for the catalogue itself"

  @doc """
  Game cards under a heading of their own, so a list of games sits in the page
  outline as a section rather than as cards under the wrong h2.
  """
  @spec game_card_list(map()) :: Phoenix.LiveView.Rendered.t()
  def game_card_list(assigns) do
    ~H"""
    <h2 id={@heading_id} class="text-sm font-bold mb-2">{@window.title}</h2>
    <.game_card_groups :if={@groups} groups={@groups} columns={@columns} />
    <div :if={!@groups} class={["grid gap-3", @columns]}>
      <.game_card :for={card <- @cards} game={card.game} path={card.path} />
    </div>
    <p :if={@catalogue_path} class="text-sm mt-3">
      <.link patch={@catalogue_path} class="underline">{dgettext("landing", "All games")}</.link>
    </p>
    """
  end

  attr :game, :map, required: true, doc: "a `RetroHexChatWeb.GameCatalog` game"
  attr :how_to_play_path, :string, required: true

  attr :play_path, :string,
    required: true,
    doc: "the game for a member; for a visitor, the sign-in window asking for an account first"

  attr :visitor, :boolean, default: false, doc: "Play asks for a nickname first"

  @doc """
  An arcade game's page: the game's sheet (`GameSheet`), the same one the
  in-app Arcade shows, with the way in beside the name. A visitor's Play opens
  the sign-in window, which lands them on the game once they have an account.
  A Retro Game's page is its home (`Landing.GameHome`).
  """
  @spec game_detail(map()) :: Phoenix.LiveView.Rendered.t()
  def game_detail(assigns) do
    ~H"""
    <GameSheet.game_sheet game={@game} heading="h1" heading_id="game-heading">
      <:actions>
        <.button patch={@play_path} class="font-bold" data-testid="game-play">
          <:icon><Icons.icon_btn_join class="w-4 h-4" /></:icon>
          {if @visitor,
            do: dgettext("landing", "Play now — pick a nickname"),
            else: dgettext("landing", "Play now")}
        </.button>
        <.button variant="outline" patch={@how_to_play_path} data-testid="game-how-to-play">
          <:icon><Icons.icon_question class="w-4 h-4" /></:icon>
          {dgettext("landing", "How to play")}
        </.button>
      </:actions>
    </GameSheet.game_sheet>
    """
  end

  attr :path, :string,
    required: true,
    doc: "the catalogue, or a game's page, in the reader's language"

  attr :class, :string, default: "text-xs mt-2"
  attr :rest, :global
  slot :inner_block, doc: "the link's words; the catalogue's own when absent"

  @doc "The way from another page — a feature list, a help topic — to the catalogue."
  @spec catalogue_link(map()) :: Phoenix.LiveView.Rendered.t()
  def catalogue_link(assigns) do
    ~H"""
    <p class={@class} {@rest}>
      <.link patch={@path} class="inline-flex items-center gap-1 underline">
        <Icons.icon_joystick class="w-3 h-3 shrink-0" />
        <%= if @inner_block != [] do %>
          {render_slot(@inner_block)}
        <% else %>
          {dgettext("landing", "See every game in the catalogue")}
        <% end %>
      </.link>
    </p>
    """
  end
end
