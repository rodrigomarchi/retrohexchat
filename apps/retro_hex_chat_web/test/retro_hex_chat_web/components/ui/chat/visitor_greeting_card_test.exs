defmodule RetroHexChatWeb.Components.UI.VisitorGreetingCardTest do
  @moduledoc """
  The card a visitor is greeted with. What it promises has to be where it says:
  the controls are named by the labels the screen shows, every feature leads to
  its help topic, and the sign-up button goes through the visitor gate.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.VisitorGreetingCard

  alias RetroHexChat.Chat.HelpTopics

  @moduletag :unit

  defp card do
    render_component(&visitor_greeting_card/1,
      server: "RetroHexChat",
      guest: "Guest4821",
      channel: "#lobby"
    )
  end

  test "welcomes the visitor by the guest name the user list shows, in the channel" do
    html = card()

    assert html =~ "Welcome to RetroHexChat, Guest4821!"
    assert html =~ "You are reading #lobby live as a visitor"
  end

  test "names the sidebar's controls by their labels" do
    html = card()

    for label <- ["Conversations", "Open channels", "Popular channels", "Browse All Channels..."] do
      assert html =~ label
    end
  end

  test "every feature an account opens leads to its help topic" do
    links =
      card()
      |> Floki.parse_fragment!()
      |> Floki.find("li a")
      |> Enum.map(&{Floki.text(&1) |> String.trim(), Floki.attribute(&1, "href")})

    assert links == [
             {"Talk", ["/chat/help/channels"]},
             {"Space", ["/chat/help/feature-virtual-spaces"]},
             {"Group Call", ["/chat/help/feature-channel-conference"]},
             {"P2P", ["/chat/help/feature-universal-lobby"]},
             {"Arcade", ["/chat/help/feature-arcade"]}
           ]

    for {_label, [path]} <- links do
      assert HelpTopics.get_topic(String.replace_prefix(path, "/chat/help/", ""))
    end
  end

  test "signing up goes through the visitor gate, help opens the visitor's topic" do
    doc = Floki.parse_fragment!(card())

    assert [button] = Floki.find(doc, ~s([data-testid="visitor-greeting-sign-up"]))
    assert Floki.attribute(button, "phx-click") == ["visitor_sign_in"]
    assert Floki.text(button) =~ "Create an account to talk"

    assert Floki.attribute(doc, ~s([data-testid="visitor-greeting-help"]), "href") ==
             ["/chat/help/watching-without-account"]
  end
end
