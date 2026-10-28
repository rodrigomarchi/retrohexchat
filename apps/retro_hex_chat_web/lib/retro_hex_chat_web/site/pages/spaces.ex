defmodule RetroHexChatWeb.Site.Pages.Spaces do
  @moduledoc """
  The public page of the Spaces: the pixel-art world every channel opens onto.

  This is the page a search for "virtual world chat in the browser" should land
  on, so it shows the world itself — the End of Time's island with people on
  it, the Construct, the Game Room, the Office and the character creator — in
  pictures taken from the real space by `make spaces.shots`, never drawn for
  the page. Each comes at full size and at half, and their sizes come from the
  capture's `manifest.json`, read at compile time: a picture the page needs and
  the capture did not write fails the build, not a reader.

  A Space opens from a channel, so the way in is the server's default one's —
  the channel everybody arrives in. A visitor is asked for an account first and
  comes back into that Space, which puts them in the channel on arrival
  (`VirtualSpace.enter_channel/2`).
  """
  use RetroHexChatWeb.Site.Page

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.ChatCard, only: [surface_link: 1]
  import RetroHexChatWeb.Components.UI.Landing.Screenshot

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.HelpTopics
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.SEO
  alias RetroHexChatWeb.Site.Shots

  @pictures ~w(island construct game_room office creator)
  @help_topics ~w(feature-virtual-spaces feature-space-construct feature-space-game-room
                  feature-space-office feature-space-talk feature-space-share)

  @shots_dir Path.expand("../../../../priv/static/images/spaces", __DIR__)
  @manifest_path Path.join(@shots_dir, "manifest.json")
  @external_resource @manifest_path
  @manifest @manifest_path |> File.read!() |> Jason.decode!()

  for name <- @pictures ++ ["og/spaces"], not Map.has_key?(@manifest, name) do
    raise "#{@manifest_path} has no #{name}: run make spaces.shots"
  end

  @impl RetroHexChatWeb.Site.Page
  def load(_params, ctx) do
    channel = Server.default_channel()

    {:ok,
     %{
       active_page: :spaces,
       visitor: ctx.visitor?,
       channel: channel,
       enter_path: enter_path(channel, ctx),
       shots: shots(),
       help: help(),
       windows: [
         Window.new("intro", dgettext("landing", "Spaces"), :icon_group_view,
           width: 900,
           body: &intro/1,
           status: [dgettext("landing", "Free, in the browser")]
         ),
         Window.new("places", dgettext("landing", "Places to go"), :icon_group_view,
           width: 900,
           body: &places/1
         ),
         Window.new("creator", dgettext("landing", "Your character"), :icon_palette,
           width: 760,
           body: &creator/1
         ),
         Window.new("how", dgettext("landing", "How to get in"), :icon_question,
           width: 520,
           body: &how/1
         )
       ],
       canonical_path: "/spaces",
       og_image:
         Shots.card(
           @manifest,
           "/images/spaces",
           "spaces",
           dgettext("landing", "Three characters talking on an island, in pixel art")
         ),
       json_ld: [
         SEO.breadcrumb_json_ld([
           {dgettext("landing", "Home"), PublicPages.localized_path("/")},
           {dgettext("landing", "Spaces"), PublicPages.localized_path("/spaces")}
         ])
       ],
       page_title: dgettext("landing", "Spaces: a pixel-art world for every chat room"),
       page_description:
         dgettext(
           "landing",
           "Walk around a pixel-art world with the people of a chat room, in your browser. Make a character, talk and build together for free."
         )
     }}
  end

  # A member walks straight in; a visitor is asked for an account and comes
  # back into the same Space.
  defp enter_path(channel, %{visitor?: false}), do: Paths.space_path(channel)

  defp enter_path(channel, _visitor),
    do: Paths.visitor_sign_in_path(:space, Paths.space_path(channel))

  defp shots, do: Shots.pictures(@manifest, "/images/spaces", @pictures)

  # Each topic's address and its own title, in the reader's language — the
  # same words the help shows — read once per page.
  defp help do
    for %{id: id, title: title} <- HelpTopics.all_topics(), id in @help_topics, into: %{} do
      {id, %{path: PublicPages.help_topic_path(id), title: title}}
    end
  end

  embed_templates "spaces/*"
end
