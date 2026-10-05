defmodule RetroHexChatWeb.IrcGuidesTest do
  @moduledoc """
  The mIRC and IRC guides: pages written for a search, reachable from the
  sitemap and from each other but kept out of the menus.

  The generic landing checks — one h1, the taskbar, the lightweight bundle, no
  link to /connect, a unique title and description — run over these pages from
  `LandingLiveTest`; what is asserted here is what is particular to a guide.
  """
  use RetroHexChatWeb.ConnCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Chat.Archive
  alias RetroHexChat.Chat.Queries
  alias RetroHexChat.Commands.MircParity
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredChannel
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.SEO

  @guides ~w(/mirc-commands /mirc-online /irc-chat)

  defp document(conn, path),
    do: conn |> get(path) |> html_response(200) |> Floki.parse_document!()

  defp hrefs(document), do: document |> Floki.find("a") |> Floki.attribute("href")

  defp json_ld(document, type) do
    document
    |> Floki.find(~s(script[type="application/ld+json"]))
    |> Enum.map(&(&1 |> elem(2) |> hd() |> String.trim() |> Jason.decode!()))
    |> Enum.find(&(&1["@type"] == type))
  end

  describe "where the guides are listed" do
    test "the sitemap has them, the menus do not" do
      for path <- @guides do
        assert path in SEO.landing_paths()
        refute path in Enum.map(PublicPages.all(), & &1.path)
      end
    end

    test "each guide links the other two", %{conn: conn} do
      for path <- @guides do
        links = conn |> document(path) |> hrefs()

        for other <- @guides -- [path] do
          assert other in links, "#{path} does not link #{other}"
        end
      end
    end
  end

  describe "/mirc-commands" do
    test "shows every parity row, with a link to the help for each command that has one",
         %{conn: conn} do
      document = document(conn, "/mirc-commands")
      text = Floki.text(document)
      links = hrefs(document)

      for row <- MircParity.rows() do
        assert text =~ row.mirc
        if row.help_topic, do: assert("/chat/help/#{row.help_topic}" in links)
      end
    end

    test "a localized page links the localized help", %{conn: conn} do
      assert "/pt-BR/chat/help/cmd-join" in (conn |> document("/pt-BR/mirc-commands") |> hrefs())
    end
  end

  describe "the questions a guide answers" do
    for path <- ~w(/mirc-online /irc-chat) do
      test "#{path} states as FAQPage exactly the questions it shows", %{conn: conn} do
        document = document(conn, unquote(path))
        faq = json_ld(document, "FAQPage")
        shown = document |> Floki.find("#questions") |> Floki.text()

        assert faq["url"] == "https://retrohexchat.app" <> unquote(path)
        assert faq["mainEntity"] != []

        for %{"name" => question} <- faq["mainEntity"] do
          assert shown =~ question
        end
      end
    end
  end

  describe "/irc-chat rooms" do
    test "a server with no published room shows no window for them", %{conn: conn} do
      assert conn |> document("/irc-chat") |> Floki.find("#open-rooms") == []
    end

    test "lists a room that publishes its archive, linking to it", %{conn: conn} do
      channel = "#guide#{System.unique_integer([:positive])}"

      {:ok, _} =
        Repo.insert(%RegisteredChannel{
          name: channel,
          founder_nickname: "Founder",
          registered_at: DateTime.utc_now(),
          last_activity_at: DateTime.utc_now()
        })

      {:ok, _} = Archive.publish(channel)

      {:ok, _} =
        Queries.insert_message(%{
          channel_name: channel,
          author_nickname: "Speaker",
          content: "hello",
          plain_content: "hello",
          type: "message"
        })

      document = document(conn, "/irc-chat")

      assert ("/archive/" <> String.trim_leading(channel, "#")) in hrefs(document)
      assert document |> Floki.find("#open-rooms") |> Floki.text() =~ channel
    end
  end
end
