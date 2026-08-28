defmodule RetroHexChatWeb.JoinLive do
  @moduledoc """
  The public card a shared link resolves to.

  This is the first thing a stranger sees of the product, so it rides the
  landing pipeline rather than the app one: it costs the small public bundle
  instead of the whole application, and it works with no session at all.

  The card resolves the link and then says one of four things. It never says
  whether the person may enter — that is the surface's question, asked with the
  surface's own policy. What it does decide is where the way in points and
  whether there is one.

  A link is dead far more of its life than it is alive, because a call lasts
  minutes and a link lasts forever. So the dead card is not an error page: it
  says what happened and offers the next plausible thing.
  """
  use RetroHexChatWeb, :live_view

  import RetroHexChatWeb.Components.UI.JoinCard

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.ShareLinks
  alias RetroHexChatWeb.SEO

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(%{"slug" => slug}, session, socket) do
    signed_in? = is_binary(session["chat_nickname"])

    {:ok,
     socket
     |> assign(
       page_title: dgettext("share", "Join - RetroHexChat"),
       robots: SEO.noindex_content()
     )
     |> assign_card(slug, signed_in?)}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <.join_card
      state={@state}
      kind={@kind}
      creator_nick={@creator_nick}
      subject={@subject}
      enter_path={@enter_path}
    />
    """
  end

  defp assign_card(socket, slug, signed_in?) do
    case ShareLinks.resolve(slug) do
      {:ok, %{live?: true} = resolution} ->
        assign(socket,
          state: if(signed_in?, do: :ready, else: :needs_session),
          kind: resolution.kind,
          creator_nick: resolution.creator_nick,
          subject: subject(resolution),
          enter_path: enter_path(resolution, signed_in?, slug)
        )

      # A resolved-but-dead link and a link that never existed read the same on
      # purpose: telling them apart is an oracle for whether a room exists.
      _gone ->
        assign(socket,
          state: :gone,
          kind: nil,
          creator_nick: nil,
          subject: nil,
          enter_path: nil
        )
    end
  end

  # What was shared, drawn rather than described. Resolved here because the card
  # is presentational and the catalogue is a domain read.
  defp subject(%{kind: "play", target: %{"game_id" => game_id}}) do
    case Catalog.get_game(game_id) do
      {:ok, game} -> Map.take(game, [:name, :tagline, :icon])
      {:error, :not_found} -> nil
    end
  end

  defp subject(_resolution), do: nil

  defp enter_path(_resolution, false, slug), do: ~p"/connect?return_to=/join/#{slug}"
  defp enter_path(resolution, true, _slug), do: surface_path(resolution)

  defp surface_path(%{kind: "play", target: %{"game_id" => game_id}}), do: ~p"/play/#{game_id}"
  defp surface_path(%{kind: "play"}), do: ~p"/play"
  defp surface_path(_resolution), do: ~p"/chat"
end
