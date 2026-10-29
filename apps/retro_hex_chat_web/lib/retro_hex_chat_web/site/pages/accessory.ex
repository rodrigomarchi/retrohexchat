defmodule RetroHexChatWeb.Site.Pages.Accessory do
  @moduledoc """
  The public page of a program of the desktop — Hex Paint (`/paint`), ASCII
  Art (`/ascii-art`), Hex Radio (`/radio`) — built once: the program open on
  something made in it, what else it does (the things posted in a channel, the
  equalizer), and how to get in.

  The pictures are taken from the real desktop by `make tools.shots`; their
  sizes come from its `manifest.json`, read at compile time. Each page module
  says only what is its own — its name, words, help topics and templates —
  and the way in: straight to the program for a member, through an account for
  a visitor, back to the program after.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.SEO
  alias RetroHexChatWeb.Site.{Shots, Window}

  @dir "/images/tools"
  @pictures ~w(paint ascii_art in_chat radio radio_equalizer)
  @cards ~w(og/paint og/ascii_art og/radio)

  @manifest_path Path.expand("../../../../priv/static#{@dir}/manifest.json", __DIR__)
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> Jason.decode!()

  for name <- @pictures ++ @cards, not Map.has_key?(@manifest, name) do
    raise "#{@manifest_path} has no #{name}: run make tools.shots"
  end

  @typedoc """
  What a page is: its `key` (pictures and card), the visitor `feature` and
  desktop `window` it opens, its `path`, `name`, `description`, `title`, the
  card's `alt`, its `help` topics, its first and last window bodies (`intro`,
  `how`) and the `panes` between them, each `{key, title, icon, body}`.
  """
  @type page :: %{
          key: String.t(),
          feature: atom(),
          window: String.t(),
          path: String.t(),
          name: String.t(),
          icon: atom(),
          description: String.t(),
          title: String.t(),
          alt: String.t(),
          help: [String.t()],
          intro: (map() -> Phoenix.LiveView.Rendered.t()),
          panes: [{String.t(), String.t(), atom(), (map() -> Phoenix.LiveView.Rendered.t())}],
          how: (map() -> Phoenix.LiveView.Rendered.t())
        }

  @doc "The page's assigns, for its `Site.Page.load/2`."
  @spec load(page(), map()) :: {:ok, map()}
  def load(page, ctx) do
    {:ok,
     %{
       active_page: String.to_existing_atom(page.key),
       open_path: open_path(page, ctx),
       shots: Shots.pictures(@manifest, @dir, @pictures),
       help: help(page.help),
       windows:
         [
           Window.new("intro", page.name, page.icon,
             width: 900,
             body: page.intro,
             status: [dgettext("landing", "Free, in the browser")]
           )
         ] ++
           for {key, title, icon, body} <- page.panes do
             Window.new(key, title, icon, width: 760, body: body)
           end ++
           [
             Window.new("how", dgettext("landing", "How to get in"), :icon_question,
               width: 520,
               body: page.how
             )
           ],
       canonical_path: page.path,
       og_image: Shots.card(@manifest, @dir, page.key, page.alt),
       json_ld: [
         SEO.breadcrumb_json_ld([
           {dgettext("landing", "Home"), PublicPages.localized_path("/")},
           {page.name, PublicPages.localized_path(page.path)}
         ]),
         SEO.web_application_json_ld(
           page.name,
           page.description,
           page.path,
           Shots.card_url(@dir, page.key)
         )
       ],
       page_title: page.title,
       # Translated, a description can outgrow what a search result shows.
       page_description: SEO.meta_description(page.description)
     }}
  end

  # A member goes straight to the program on the desktop; a visitor to an
  # account first, and back to the program after.
  defp open_path(page, %{visitor?: false}), do: Paths.chat_window_path(page.window)

  defp open_path(page, _ctx),
    do: Paths.visitor_sign_in_path(page.feature, Paths.chat_window_path(page.window))

  # Each topic's address and its own title, in the reader's language.
  defp help(ids) do
    for %{id: id, title: title} <- HelpTopics.all_topics(), id in ids, into: %{} do
      {id, %{path: PublicPages.help_topic_path(id), title: title}}
    end
  end
end
