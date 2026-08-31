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
  alias RetroHexChat.Channels.Visibility
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.GroupCall
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.Schema.Session, as: LobbySession
  alias RetroHexChat.ShareLinks
  alias RetroHexChat.VirtualSpace
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.SEO

  @impl true
  @spec mount(map(), map(), Socket.t()) :: {:ok, Socket.t()}
  def mount(%{"slug" => slug}, session, socket) do
    nickname = session["chat_nickname"]

    {:ok,
     socket
     |> assign(
       page_title: dgettext("share", "Join - RetroHexChat"),
       robots: SEO.noindex_content()
     )
     |> assign_card(slug, nickname)
     |> assign_preview()}
  end

  # The card's own words, lifted into the tags a link preview reads.
  #
  # `subject/1` is where the privacy rule lives — a channel is named only when a
  # stranger could have listed it anyway — and the rule was written *for* this
  # surface: the social preview is the place a channel name reaches people who
  # were never sent the link. Until now it fed the card body and stopped there,
  # so every share unfurled as the site's generic blurb. It is the same sentence
  # in both places on purpose; a second phrasing here would be a second rule.
  defp assign_preview(%{assigns: %{subject: %{name: name} = subject}} = socket)
       when is_binary(name) do
    assign(socket,
      page_title: name,
      page_description: subject[:tagline] || dgettext("share", "Somebody shared this with you.")
    )
  end

  defp assign_preview(socket), do: socket

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

  defp assign_card(socket, slug, nickname) do
    signed_in? = is_binary(nickname)

    case ShareLinks.resolve(slug) do
      {:ok, %{live?: true} = resolution} ->
        live_card(socket, resolution, signed_in?, slug)

      # A match whose seat is taken is not a dead link and must not read like
      # one: it stopped working because it *worked*, and "already full" is the
      # answer most late clicks on a 1v1 link will get. Whoever is already in
      # it still gets the way in — telling the host their own match is full
      # would be the card contradicting the room.
      {:ok, %{kind: "play", target: %{"session_token" => token}} = resolution} ->
        match_card(socket, resolution, token, nickname, signed_in?, slug)

      # A resolved-but-dead link and a link that never existed read the same on
      # purpose: telling them apart is an oracle for whether a room exists.
      _gone ->
        gone_card(socket)
    end
  end

  defp live_card(socket, resolution, signed_in?, slug) do
    assign(socket,
      state: if(signed_in?, do: :ready, else: :needs_session),
      kind: resolution.kind,
      creator_nick: resolution.creator_nick,
      subject: subject(resolution),
      enter_path: enter_path(resolution, signed_in?, slug)
    )
  end

  # Three answers, and the order is what keeps them honest: a match that is
  # over is a dead link like any other — including for the person who made it —
  # a match that is running is still the way in for the two people in it, and
  # for everybody else it is full.
  defp match_card(socket, resolution, token, nickname, signed_in?, slug) do
    case Lobby.get_session(token) do
      {:ok, %LobbySession{} = db_session} ->
        cond do
          LobbySession.terminal?(db_session.status) -> gone_card(socket)
          participant?(db_session, nickname) -> live_card(socket, resolution, signed_in?, slug)
          true -> full_card(socket, resolution)
        end

      {:error, :not_found} ->
        gone_card(socket)
    end
  end

  defp full_card(socket, resolution) do
    assign(socket,
      state: :filled,
      kind: resolution.kind,
      creator_nick: resolution.creator_nick,
      subject: subject(resolution),
      enter_path: nil
    )
  end

  defp gone_card(socket) do
    assign(socket,
      state: :gone,
      kind: nil,
      creator_nick: nil,
      subject: nil,
      enter_path: nil
    )
  end

  # Asked of the session and never of the link: a link says which room, and who
  # is in the room is the room's own answer.
  defp participant?(%LobbySession{} = db_session, nickname) when is_binary(nickname) do
    case SessionHelpers.resolve_user_id(nickname) do
      {:ok, user_id} -> user_id in [db_session.creator_id, db_session.peer_id]
      _stranger -> false
    end
  end

  defp participant?(_db_session, _nickname), do: false

  # What was shared, drawn rather than described. Resolved here because the card
  # is presentational and the catalogue is a domain read.
  defp subject(%{kind: "play", target: %{"game_id" => game_id} = target}) do
    case Catalog.get_game(game_id) do
      {:ok, game} ->
        game
        |> Map.take([:name, :tagline, :icon])
        |> Map.put(:tagline, match_tagline(target) || game.tagline)

      {:error, :not_found} ->
        nil
    end
  end

  # A call names its channel only when the channel is one a stranger could have
  # found anyway. "A call in #board" in a social-media preview leaks the
  # existence of a channel the reader could not have listed.
  defp subject(%{kind: "call", target: %{"room_token" => room_token}}) do
    case GroupCall.get_room(room_token) do
      {:ok, room} ->
        %{
          name: call_name(room.channel_name),
          tagline: call_tagline(room_token),
          icon: "protocol_conference"
        }

      {:error, :not_found} ->
        nil
    end
  end

  # A space names its channel under the same rule a call does, and for the same
  # reason: a preview that says "the space of #board" leaks the existence of a
  # channel the reader could not have listed. A private space names nobody at
  # all — its id *is* its two participants.
  defp subject(%{kind: "space", target: %{"space_id" => space_id, "mode" => "channel"}}) do
    %{
      name: space_name(space_id),
      tagline: space_tagline(space_id),
      icon: "community"
    }
  end

  defp subject(%{kind: "space"}) do
    %{
      name: dgettext("share", "A private space on RetroHexChat"),
      tagline: nil,
      icon: "community"
    }
  end

  # A P2P session names the two people in it and nothing else — it has no
  # channel to leak, and its whole subject *is* who is in it. Only the person
  # who shared it is named: the other half is whoever is reading, or somebody
  # who is not in it at all and will be refused anyway.
  defp subject(%{kind: "p2p", creator_nick: creator_nick}) when is_binary(creator_nick) do
    %{
      name: dgettext("share", "A P2P session with %{nick}", nick: creator_nick),
      tagline: dgettext("share", "One to one, browser to browser."),
      icon: "protocol_p2p"
    }
  end

  defp subject(%{kind: "p2p"}) do
    %{
      name: dgettext("share", "A P2P session on RetroHexChat"),
      tagline: dgettext("share", "One to one, browser to browser."),
      icon: "protocol_p2p"
    }
  end

  defp subject(_resolution), do: nil

  # A match says how many ways in are left, because that is the one fact that
  # decides whether following it does anything. A solo link has no seats and
  # keeps the game's own tagline.
  defp match_tagline(%{"session_token" => token}) do
    case Lobby.get_session(token) do
      {:ok, %LobbySession{status: "open", peer_id: nil}} ->
        dgettext("share", "1 seat open")

      {:ok, %LobbySession{}} ->
        dgettext("share", "No seats left")

      _absent ->
        nil
    end
  end

  defp match_tagline(_target), do: nil

  defp space_name(channel_name) do
    if Visibility.nameable?(channel_name) do
      dgettext("share", "The space of %{channel}", channel: channel_name)
    else
      dgettext("share", "A space on RetroHexChat")
    end
  end

  defp space_tagline(space_id) do
    case VirtualSpace.roster(space_id) do
      [] ->
        nil

      roster ->
        dngettext(
          "share",
          "%{count} person inside now",
          "%{count} people inside now",
          length(roster)
        )
    end
  end

  defp call_name(channel_name) do
    if Visibility.nameable?(channel_name) do
      dgettext("share", "A call in %{channel}", channel: channel_name)
    else
      dgettext("share", "A call on RetroHexChat")
    end
  end

  defp call_tagline(room_token) do
    case GroupCall.get_summary(room_token) do
      {:ok, %{participants: participants}} ->
        dngettext(
          "share",
          "%{count} person inside now",
          "%{count} people inside now",
          length(participants)
        )

      {:error, _reason} ->
        nil
    end
  end

  defp enter_path(_resolution, false, slug), do: ~p"/connect?return_to=/join/#{slug}"
  defp enter_path(resolution, true, _slug), do: surface_path(resolution)

  defp surface_path(%{kind: "play", target: %{"game_id" => game_id, "session_token" => token}}),
    do: Paths.play_match_path(game_id, token)

  defp surface_path(%{kind: "play", target: %{"game_id" => game_id}}), do: ~p"/play/#{game_id}"
  defp surface_path(%{kind: "play"}), do: ~p"/play"

  defp surface_path(%{kind: "call", target: %{"room_token" => room_token}}),
    do: Paths.call_path(room_token)

  defp surface_path(%{kind: "space", target: %{"space_id" => space_id}}),
    do: Paths.space_path(space_id)

  defp surface_path(%{kind: "p2p", target: %{"session_token" => session_token}}),
    do: Paths.p2p_path(session_token)

  defp surface_path(_resolution), do: ~p"/chat"
end
