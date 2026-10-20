defmodule RetroHexChatWeb.Components.UI.GameResultCardTest do
  @moduledoc """
  A match's score line with each player's language flag right before their
  name, and the same words as the plain line.
  """
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.UI.GameResultCard

  @moduletag :unit

  defp card(overrides \\ %{}) do
    Map.merge(
      %{p1_nickname: "ana", p2_nickname: "beto", p1_score: 11, p2_score: 7, difficulty: nil},
      overrides
    )
  end

  test "each player's flag sits before their name, in the translated order" do
    html =
      render_component(&GameResultCard.score_with_flags/1,
        card: card(%{p1_locale: "pt_BR", p2_locale: "de"})
      )

    doc = Floki.parse_fragment!(html)

    assert doc |> Floki.find(~s([data-testid="nick-flag"])) |> Floki.attribute("data-locale") ==
             ["pt_BR", "de"]

    assert Floki.text(doc) == GameResultCard.score_line(card())
  end

  test "a page's lookup is read by nickname, and the computer has no flag" do
    html =
      render_component(&GameResultCard.score_with_flags/1,
        card: card(%{p2_nickname: nil, difficulty: "hard"}),
        locales: %{"ana" => "fr"}
      )

    doc = Floki.parse_fragment!(html)

    assert doc |> Floki.find(~s([data-testid="nick-flag"])) |> Floki.attribute("data-locale") ==
             ["fr"]

    assert Floki.text(doc) ==
             GameResultCard.score_line(card(%{p2_nickname: nil, difficulty: "hard"}))
  end
end
