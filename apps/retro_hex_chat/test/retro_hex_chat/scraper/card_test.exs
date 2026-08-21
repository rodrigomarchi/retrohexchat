defmodule RetroHexChat.Scraper.CardTest do
  @moduledoc """
  The one card the product shows for a link, wherever the link came from.

  The RSS bot's own assertions live in `rss_test.exs` and are unchanged by this
  module existing — together the two files say the feed item and the pasted link
  render through the same rules.
  """
  use ExUnit.Case, async: true

  alias RetroHexChat.Scraper.Card
  alias RetroHexChat.Scraper.ScrapedPage

  @url "https://example.com/story"

  defp page(attrs \\ %{}) do
    struct!(
      %ScrapedPage{
        url: @url,
        url_hash: "hash",
        status: "ready",
        title: "A perfectly ordinary headline",
        site_name: "Example News"
      },
      attrs
    )
  end

  describe "markdown/2" do
    test "a full page becomes the same five-part card the RSS bot publishes" do
      card =
        Card.markdown(
          page(%{
            description: "A summary the publisher wrote.",
            image_url: "https://example.com/card.png",
            author: "Ada Lovelace",
            content_text: String.duplicate("word ", 400)
          })
        )

      assert card =~ "**Example News** | A perfectly ordinary headline"
      assert card =~ "_Ada Lovelace · 2 min read_"
      assert card =~ "![Example News preview image](<https://example.com/card.png>)"
      assert card =~ "> A summary the publisher wrote\\."
      assert card =~ "[Read full story](<https://example.com/story>)"
    end

    test "a page that would not say what it is gets no card at all" do
      refute Card.markdown(page(%{title: nil}))
      refute Card.markdown(page(%{title: ""}))
      refute Card.markdown(%{})
    end

    test "a caller that must always print something supplies the title" do
      card = Card.markdown(%{site_name: "Example News"}, fallback_title: "From the feed")

      assert card =~ "**Example News** | From the feed"
    end

    # A pasted link has no feed behind it to name the publication, and the
    # address bar is where a reader would have read the source from anyway.
    test "labels a page with its host when nobody names the publication" do
      assert Card.markdown(page(%{site_name: nil})) =~ "**example\\.com** | A perfectly"

      assert Card.markdown(page(%{site_name: nil, url: "https://www.example.com/a"})) =~
               "**example\\.com** |"
    end

    test "prints the headline alone when there is no host either" do
      card = Card.markdown(%{title: "Just a headline"})

      assert card =~ "Just a headline"
      refute card =~ "**"
    end

    # A publisher that ships `<title></title>` used to suppress the whole card,
    # because `"" || fallback` is `""` — the feed item's perfectly good headline
    # never got a look in.
    test "a blank field is treated as no field, not as an answer" do
      card = Card.markdown(%{title: "  ", site_name: ""}, fallback_title: "From the feed")

      assert card =~ "From the feed"
    end

    test "the page's own title wins over the caller's fallback" do
      card = Card.markdown(page(), fallback_title: "From the feed")

      assert card =~ "| A perfectly ordinary headline"
      refute card =~ "From the feed"
    end

    test "the publication is not printed twice" do
      card = Card.markdown(page(%{title: "Corals Spin Tiny Vortices | Example News"}))

      assert card =~ "**Example News** | Corals Spin Tiny Vortices"
      refute card =~ "Vortices | Example News"
    end

    test "the byline carries only what is known, and vanishes when nothing is" do
      assert Card.markdown(page(%{author: "Ada Lovelace"})) =~ "_Ada Lovelace_"
      refute Card.markdown(page()) =~ "_"
    end

    test "a title that is Markdown is printed, not interpreted" do
      card = Card.markdown(page(%{title: "*not emphasis* [not a link]"}))

      assert card =~ "\\*not emphasis\\* \\[not a link\\]"
    end

    test "a short page is not given a reading time it has not earned" do
      refute Card.markdown(page(%{content_text: "Three short words"})) =~ "min read"
    end

    test "uses a stored excerpt when the publisher had no description" do
      card = Card.markdown(page(%{description: nil, excerpt: "Extracted from the article body."}))

      assert card =~ "> Extracted from the article body\\."
    end

    test "uses stored image alt text when present" do
      card =
        Card.markdown(
          page(%{
            image_url: "https://example.com/card.png",
            image_alt: "Reporter speaking with residents"
          })
        )

      assert card =~ "![Reporter speaking with residents](<https://example.com/card.png>)"
    end

    test "the story links to the page's own address when it names no canonical one" do
      assert Card.markdown(page()) =~ "[Read full story](<#{@url}>)"

      assert Card.markdown(page(%{canonical_url: "https://example.com/canonical"})) =~
               "[Read full story](<https://example.com/canonical>)"
    end

    test "an address nobody can follow is left out rather than printed broken" do
      card = Card.markdown(page(%{url: "not a url", image_url: "javascript:alert(1)"}))

      assert card =~ "**Example News** |"
      refute card =~ "Read full story"
      refute card =~ "!["
    end
  end

  describe "source_label/1" do
    test "keeps the publication and drops its positioning statement" do
      assert Card.source_label("cs.LG updates on arXiv.org") == "cs.LG"
      assert Card.source_label("Phys.org - latest science and technology news") == "Phys.org"
      assert Card.source_label("Anime News Network") == "Anime News Network"
    end
  end
end
