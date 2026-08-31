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
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.GroupCall
  alias RetroHexChat.ShareLinks
  alias RetroHexChat.VirtualSpace
  alias RetroHexChatWeb.App.Paths
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

  defp space_name(channel_name) do
    if listed_channel?(channel_name) do
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
    if listed_channel?(channel_name) do
      dgettext("share", "A call in %{channel}", channel: channel_name)
    else
      dgettext("share", "A call on RetroHexChat")
    end
  end

  defp listed_channel?(channel_name) do
    case Server.get_state(channel_name) do
      {:ok, %{modes_detail: modes}} ->
        not (Map.get(modes, :secret, false) or Map.get(modes, :private, false) or
               Map.get(modes, :invite_only, false))

      _unreachable ->
        false
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
