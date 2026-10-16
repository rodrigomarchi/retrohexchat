defmodule RetroHexChatWeb.Site.Pages.Game do
  @moduledoc """
  One game's public page: what it is, what it looks like, and the way in.

  This is the page a search for "play DOOM in the browser" should land on, so
  it says that in its title and shows the game itself. How to play in depth —
  every control, tips — stays in the in-app help, which this page links to
  rather than repeats.
  """
  use RetroHexChatWeb.Site.Page

  import RetroHexChatWeb.Components.UI.Landing.GameCards

  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.GameCatalog
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.SEO

  # A search result cuts a title at about 70 characters, so the longest form
  # that fits wins: the site's name goes when a game's name is long.
  @title_limit 70

  @impl RetroHexChatWeb.Site.Page
  def load(%{"slug" => slug}, ctx) do
    case GameCatalog.get(slug) do
      {:ok, game} -> load_game(game, ctx)
      :error -> :not_found
    end
  end

  defp load_game(game, ctx) do
    path = GameCatalog.page_path(game)

    {:ok,
     %{
       active_page: :games,
       game: game,
       path: path,
       play_path: play_path(game, ctx),
       kind_label: kind_label(game),
       how_to_play_path: PublicPages.localized_path("/chat/help/#{game.help_topic}"),
       catalogue_path: PublicPages.localized_path("/games"),
       related: game |> GameCatalog.related() |> Enum.map(&card/1),
       windows: [
         %{id: "game", label: game.name, icon: :icon_joystick},
         %{id: "more-games", label: dgettext("landing", "More games"), icon: :icon_joystick}
       ],
       canonical_path: path,
       og_image: og_image(game),
       json_ld: [
         SEO.breadcrumb_json_ld([
           {dgettext("landing", "Home"), PublicPages.localized_path("/")},
           {dgettext("landing", "Games"), PublicPages.localized_path("/games")},
           {game.name, PublicPages.localized_path(path)}
         ]),
         SEO.video_game_json_ld(game, path)
       ],
       page_title: title(game),
       page_description: SEO.meta_description("#{game.tagline} — #{game.description}")
     }}
  end

  # A visitor's Play asks for an account first, naming games, and comes back
  # to the game once they have one.
  defp play_path(game, %{visitor?: true}),
    do: Paths.visitor_sign_in_path(:games, GameCatalog.play_path(game))

  defp play_path(game, _ctx), do: GameCatalog.play_path(game)

  defp card(game),
    do: %{game: game, path: PublicPages.localized_path(GameCatalog.page_path(game))}

  defp kind_label(%{kind: :arcade}), do: dgettext("landing", "Solo arcade")

  defp kind_label(%{kind: :multiplayer}),
    do: dgettext("landing", "Multiplayer — or against the AI")

  defp title(game) do
    candidates = [
      dgettext("landing", "Play %{name} in your browser — Retro Hex Chat", name: game.name),
      dgettext("landing", "Play %{name} in your browser", name: game.name)
    ]

    Enum.find(candidates, List.last(candidates), &(String.length(&1) <= @title_limit))
  end

  defp og_image(%{screenshot: nil}), do: SEO.social_image()

  defp og_image(%{screenshot: shot} = game) do
    %{
      url: SEO.site_url(shot.og_path),
      width: shot.og_width,
      height: shot.og_height,
      type: "image/jpeg",
      alt: dgettext("landing", "Screenshot of %{name}", name: game.name)
    }
  end

  embed_templates "game.html"

  @impl RetroHexChatWeb.Site.Page
  def render(assigns), do: game(assigns)
end
