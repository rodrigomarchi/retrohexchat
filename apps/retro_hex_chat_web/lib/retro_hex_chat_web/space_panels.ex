defmodule RetroHexChatWeb.SpacePanels do
  @moduledoc """
  The panels a Construct piece opens, ready for the canvas to show.

  The domain fills in what it reads from the conversation
  (`VirtualSpace.fill_construct_panel/3`); this adds what only the web layer
  knows: the address a picture is served from, and the games an arcade cabinet
  lists, each with the page it opens on.
  """

  alias RetroHexChat.VirtualSpace
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.GameCatalog
  alias RetroHexChatWeb.SpaceRef

  @panels ~w(sign board screen arcade)

  @doc """
  The panel `nickname` opened in the space `space_id`. A modal that is not a
  Construct panel (a gate's question) is returned as it came.
  """
  @spec fill(map(), String.t(), String.t() | nil) :: map()
  def fill(%{kind: kind} = modal, space_id, nickname) when kind in @panels do
    case conversation(space_id) do
      {:ok, conversation} ->
        modal
        |> VirtualSpace.fill_construct_panel(conversation, nickname)
        |> for_the_page()

      :error ->
        modal
    end
  end

  def fill(modal, _space_id, _nickname), do: modal

  defp for_the_page(%{kind: "screen", image: %{id: id} = image} = modal) do
    image = %{
      url: "/chat/attachments/#{id}/preview",
      name: image.filename,
      author: image.author
    }

    %{modal | image: image}
  end

  defp for_the_page(%{kind: "arcade"} = modal) do
    games =
      Enum.map(GameCatalog.list(), fn game ->
        %{id: game.id, name: game.name, tagline: game.tagline, url: game_url(game)}
      end)

    Map.put(modal, :games, games)
  end

  defp for_the_page(modal), do: modal

  # A cabinet opens the game itself, on its own page in a new tab, rather than
  # the chat's library: the Space stays where it is.
  defp game_url(%{kind: :arcade, id: id}), do: Paths.arcade_path(id)
  defp game_url(%{kind: :multiplayer, id: id}), do: Paths.play_path(id)

  defp conversation(space_id) do
    case VirtualSpace.construct_parent(space_id) do
      {:ok, "dm:" <> _pair} ->
        with {:ok, participants} <- SpaceRef.participants(space_id),
             do: {:ok, {:direct_message, participants}}

      {:ok, channel_name} ->
        {:ok, {:channel, channel_name}}

      :error ->
        :error
    end
  end
end
