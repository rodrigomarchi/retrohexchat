defmodule RetroHexChatWeb.LandingLive.Game do
  @moduledoc """
  One game's public page: what it is, what it looks like, and the way in.

  This is the page a search for "play DOOM in the browser" should land on, so
  it says that in its title and shows the game itself. How to play in depth —
  every control, tips — stays in the in-app help, which this page links to
  rather than repeats.
  """
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Landing.GameCards

  alias RetroHexChatWeb.GameCatalog
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.SEO

  defmodule NotFoundError do
    @moduledoc "A slug that names no game in the catalogue: a real 404, not an error page."
    defexception message: "no such game", plug_status: 404
  end

  # A search result cuts a title at about 70 characters, so the longest form
  # that fits wins: the site's name goes when a game's name is long.
  @title_limit 70

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"slug" => slug}, _session, socket) do
    game =
      case GameCatalog.get(slug) do
        {:ok, game} -> game
        :error -> raise NotFoundError
      end

    path = GameCatalog.page_path(game)

    {:ok,
     assign(socket,
       active_page: :games,
       game: game,
       path: path,
       play_path: GameCatalog.play_path(game),
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
     )}
  end

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
end
