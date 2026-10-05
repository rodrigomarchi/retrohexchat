defmodule RetroHexChatWeb.Components.UI.Landing.GameCards do
  @moduledoc """
  The public games catalogue's pieces: a game's screenshot, the card that links
  to its page, the page's body, and the link other pages use to reach it.

  Built on the shared `card`, `button` and `desktop_window` primitives and the
  same `game_icon` the in-app library uses, so a game looks like itself on the
  public page and in the app. Every path arrives prepared by the page — these
  components never read the locale or build an address themselves.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Card
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChatWeb.Icons

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
  attr :path, :string, required: true, doc: "the game's page, in the reader's language"

  @doc "A game in a list: its picture, its name and its line, as one link to its page."
  @spec game_card(map()) :: Phoenix.LiveView.Rendered.t()
  def game_card(assigns) do
    ~H"""
    <.link
      navigate={@path}
      class="block no-underline text-inherit"
      data-testid={"game-card-#{@game.slug}"}
    >
      <.card class="h-full">
        <.game_screenshot game={@game} />
        <.card_header>
          <:icon><Icons.game_icon game_id={@game.id} class="h-4 w-4" /></:icon>
          <.card_title class="text-sm font-bold leading-tight">{@game.name}</.card_title>
        </.card_header>
        <.card_content>
          <.card_description>{@game.tagline}</.card_description>
        </.card_content>
      </.card>
    </.link>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :heading_id, :string, required: true
  attr :cards, :list, required: true, doc: "%{game, path} per card"
  attr :width, :integer, default: 1000
  attr :columns, :string, default: "grid-cols-2 md:grid-cols-3 lg:grid-cols-4"
  slot :icon, required: true
  slot :status
  slot :footer

  @doc """
  A window of game cards under a heading of its own, so a list of games sits
  in the page outline as a section rather than as cards under the wrong h2.
  """
  @spec game_card_window(map()) :: Phoenix.LiveView.Rendered.t()
  def game_card_window(assigns) do
    ~H"""
    <.desktop_window id={@id} width={@width} title={@title}>
      <:icon>{render_slot(@icon)}</:icon>
      <h2 id={@heading_id} class="text-sm font-bold mb-2">{@title}</h2>
      <div class={["grid gap-3", @columns]}>
        <.game_card :for={card <- @cards} game={card.game} path={card.path} />
      </div>
      {render_slot(@footer)}
      <:status :if={@status != []}>{render_slot(@status)}</:status>
    </.desktop_window>
    """
  end

  attr :game, :map, required: true, doc: "a `RetroHexChatWeb.GameCatalog` game"
  attr :kind_label, :string, required: true
  attr :how_to_play_path, :string, required: true

  @doc """
  A game's page: what it is, what it looks like, how it is played and the way
  in. Playing needs a nickname, so the button brings forward the page's own
  Connect window, which is told to land the reader on the game.
  """
  @spec game_detail(map()) :: Phoenix.LiveView.Rendered.t()
  def game_detail(assigns) do
    ~H"""
    <.desktop_window id="game" width={760} title={@game.name}>
      <:icon><Icons.game_icon game_id={@game.id} class="w-4 h-4" /></:icon>

      <h1 id="game-heading" class="text-lg font-bold mb-1 text-text">{@game.name}</h1>
      <p class="text-sm mb-3">{@game.tagline}</p>

      <div class="shadow-retro-field mb-3">
        <.game_screenshot game={@game} main />
      </div>

      <div class="flex flex-wrap gap-2 mb-4">
        <.button type="button" data-window-open="connect" data-testid="game-play">
          <:icon><Icons.icon_joystick class="w-4 h-4" /></:icon>
          {dgettext("landing", "Play now — pick a nickname")}
        </.button>
        <.button variant="outline" href={@how_to_play_path} data-testid="game-how-to-play">
          <:icon><Icons.icon_question class="w-4 h-4" /></:icon>
          {dgettext("landing", "How to play")}
        </.button>
      </div>

      <h2 class="text-sm font-bold mb-1">{dgettext("landing", "About")}</h2>
      <p class="text-sm mb-3">{@game.description}</p>

      <h2 class="text-sm font-bold mb-1">{dgettext("landing", "Controls")}</h2>
      <p class="text-sm mb-3" data-testid="game-controls">{@game.controls}</p>

      <div :if={@game.modes != []} data-testid="game-modes">
        <h2 class="text-sm font-bold mb-1">{dgettext("landing", "Modes")}</h2>
        <ul class="text-sm list-disc pl-5">
          <li :for={mode <- @game.modes}>
            <strong>{mode.name}</strong> — {mode.tagline}
          </li>
        </ul>
      </div>

      <:status>
        <.window_status_bar_field grow>{@kind_label}</.window_status_bar_field>
        <.window_status_bar_field>
          {dgettext("landing", "Free, in the browser")}
        </.window_status_bar_field>
      </:status>
    </.desktop_window>
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
      <.link navigate={@path} class="inline-flex items-center gap-1 underline">
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
