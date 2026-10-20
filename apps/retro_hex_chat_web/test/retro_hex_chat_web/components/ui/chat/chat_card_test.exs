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
