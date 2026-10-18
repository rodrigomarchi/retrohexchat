defmodule RetroHexChatWeb.Components.UI.ChatCardTest do
  @moduledoc """
  The one shape of a card in the conversation: no frame, upright text, the
  title and its state word together, the actions in one row under the words,
  and a way out that opens beside the chat rather than over it.
  """
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.ChatCard

  @moduletag :unit

  defp row_card(assigns) do
    ~H"""
    <.chat_card layout={:row} data-testid="card">
      <:icon><span data-testid="icon"></span></:icon>
      <:title>Movie night</:title>
      <:badge>
        <.chat_card_badge tone={:live} data-testid="badge">Live</.chat_card_badge>
      </:badge>
      <span data-testid="body">Friday</span>
      <:actions><button data-testid="act">Go</button></:actions>
    </.chat_card>
    """
  end

  defp block_card(assigns) do
    ~H"""
    <.chat_card data-testid="card">
      <:title>Help</:title>
      <p>text</p>
    </.chat_card>
    """
  end

  describe "chat_card/1" do
    test "draws no frame: no bevel, no border, no background of its own" do
      for html <- [render_component(&row_card/1, %{}), render_component(&block_card/1, %{})] do
        [class] =
          html
          |> LazyHTML.from_fragment()
          |> LazyHTML.query("[data-testid=card]")
          |> LazyHTML.attribute("class")

        assert class =~ "chat-card"
        refute class =~ "shadow-"
        refute class =~ "border"
        refute class =~ "bg-"
      end
    end

    test "a row card puts the icon beside the title, the badge and the actions" do
      doc = render_component(&row_card/1, %{}) |> LazyHTML.from_fragment()

      for id <- ~w(icon badge body act) do
        assert LazyHTML.query(doc, "[data-testid=card] [data-testid=#{id}]") |> Enum.count() == 1
      end

      assert LazyHTML.text(doc) =~ "Movie night"
    end

    test "a block card titles itself with a heading and draws no empty action row" do
      doc = render_component(&block_card/1, %{}) |> LazyHTML.from_fragment()

      assert doc |> LazyHTML.query("h3") |> LazyHTML.text() == "Help"
      assert doc |> LazyHTML.query(".flex-wrap") |> Enum.count() == 0
    end
  end

  describe "chat_card_badge/1" do
    defp badge(assigns) do
      ~H"""
      <.chat_card_badge tone={@tone}>word</.chat_card_badge>
      """
    end

    test "says live in the primary colour and a record in the muted one" do
      live = render_component(&badge/1, %{tone: :live})
      over = render_component(&badge/1, %{tone: :muted})

      assert live =~ "text-primary"
      assert over =~ "text-muted-foreground"
      refute over =~ "opacity"
    end
  end

  describe "surface_link/1" do
    defp surface(assigns) do
      ~H"""
      <.surface_link href="/play/pong" label="Pong" as={@as}>Open</.surface_link>
      """
    end

    test "opens the place in a tab of its own, as a link or a button" do
      for as <- [:link, :button] do
        [anchor] =
          render_component(&surface/1, %{as: as})
          |> LazyHTML.from_fragment()
          |> LazyHTML.query("a")
          |> Enum.to_list()

        assert LazyHTML.attribute(anchor, "href") == ["/play/pong"]
        assert LazyHTML.attribute(anchor, "target") == ["_blank"]
        assert LazyHTML.attribute(anchor, "rel") == ["noopener"]
        assert LazyHTML.attribute(anchor, "data-confirm-tab") == ["surface"]
        assert LazyHTML.attribute(anchor, "data-confirm-label") == ["Pong"]
      end
    end
  end
end
