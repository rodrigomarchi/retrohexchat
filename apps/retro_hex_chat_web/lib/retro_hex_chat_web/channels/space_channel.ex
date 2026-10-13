defmodule RetroHexChatWeb.SpaceChannel do
  @moduledoc """
  Realtime channel for conversation-backed virtual spaces (`space:#channel`,
  `space:dm:<key>`, or either one's Construct, `space:construct:<space>`).

  Join is authorized by the signed `channel_join_token` issued by the LiveView
  shell. Channel spaces validate channel presence before joining. The reply is
  the `space_init` payload (participant + snapshot). Domain broadcasts on the
  `space:#channel` PubSub topic are pushed through to the client verbatim.
  """
  use Phoenix.Channel, log_join: :debug

  require Logger

  alias RetroHexChat.Accounts.Avatars
  alias RetroHexChat.VirtualSpace
  alias RetroHexChat.VirtualSpace.ChannelJoinToken
  alias RetroHexChat.VirtualSpace.DirectMessageSpace
  alias RetroHexChatWeb.SpaceAssets
  alias RetroHexChatWeb.SpacePanels
  alias RetroHexChatWeb.SpaceSessionAnnouncement

  # A sign holds a short line; anything far past it is not a sign edit at all.
  @label_bytes 400

  @impl true
  def join("space:#" <> channel_tail, params, socket) do
    channel_name = "#" <> channel_tail

    with {:ok, data} <- verify_channel_join_token(params, channel_name),
         {:ok, result} <-
           VirtualSpace.join_channel_space(channel_name, build_channel_actor(data, params)) do
      socket =
        socket
        |> assign(:space_kind, :channel)
        |> assign(:space_id, channel_name)
        |> assign(:participant_key, result.participant.key)
        |> assign(:user_id, data.user_id)
        |> assign(:nickname, data.nickname)

      announce(result, channel_name, "channel", data, [])
      {:ok, space_init(channel_name, result), socket}
    else
      {:error, reason} ->
        {:error, %{reason: join_error(reason)}}
    end
  end

  def join("space:dm:" <> key_tail, params, socket) do
    space_id = "dm:" <> key_tail

    with {:ok, data} <- verify_direct_message_join_token(params, space_id),
         {:ok, result} <-
           VirtualSpace.join_direct_message_space(
             space_id,
             build_channel_actor(data, params),
             data.participants
           ) do
      socket =
        socket
        |> assign(:space_kind, :direct_message)
        |> assign(:space_id, space_id)
        |> assign(:participant_key, result.participant.key)
        |> assign(:user_id, data.user_id)
        |> assign(:nickname, data.nickname)

      announce(result, space_id, "direct_message", data, data.participants)
      {:ok, space_init(space_id, result), socket}
    else
      {:error, reason} ->
        {:error, %{reason: join_error(reason)}}
    end
  end

  def join("space:construct:" <> parent_tail, params, socket) do
    construct_id = "construct:" <> parent_tail

    with {:ok, data} <- verify_construct_join_token(params, construct_id),
         {:ok, result} <-
           VirtualSpace.join_construct_space(
             construct_id,
             build_channel_actor(data, params),
             data.participants
           ) do
      socket =
        socket
        |> assign(:space_kind, :construct)
        |> assign(:space_id, construct_id)
        |> assign(:participant_key, result.participant.key)
        |> assign(:user_id, data.user_id)
        |> assign(:nickname, data.nickname)

      {:ok, space_init(construct_id, result), socket}
    else
      {:error, reason} ->
        {:error, %{reason: join_error(reason)}}
    end
  end

  def join("space:" <> _not_channel_topic, _params, _socket),
    do: {:error, %{reason: "not_found"}}

  # Walking into an empty space is what starts a gathering, and the join that
  # started one is the only one handed a session back. Every later arrival gets
  # `nil` here, which is what keeps one gathering to one card.
  defp announce(%{session: %{token: token}}, space_id, mode, data, participants) do
    SpaceSessionAnnouncement.announce(%{
      space_id: space_id,
      mode: mode,
      token: token,
      nickname: data.nickname,
      user_id: data.user_id,
      participants: participants
    })
  end

  defp announce(_result, _space_id, _mode, _data, _participants), do: :ok

  @impl true
  def handle_in("space_input", payload, socket) do
    with %{space_kind: kind, space_id: space_id, participant_key: key} <- socket.assigns,
         {:ok, step} <- parse_input(payload) do
      dispatch_input(kind, space_id, key, step)
    end

    {:noreply, socket}
  end

  def handle_in("space_interact", payload, socket) do
    with %{space_kind: kind, space_id: space_id, participant_key: key} <- socket.assigns,
         {:ok, interact} <- parse_interact(payload),
         {:ok, %{modal: modal}} <-
           dispatch_interact(kind, space_id, key, interact, socket.assigns[:nickname]) do
      push(socket, "space_modal", SpacePanels.fill(modal, space_id, socket.assigns[:nickname]))
    end

    {:noreply, socket}
  end

  def handle_in("space_action", payload, socket) do
    with %{space_kind: kind, space_id: space_id, participant_key: key} <- socket.assigns,
         {:ok, action} <- parse_action(payload) do
      dispatch_action(kind, space_id, key, action)
    end

    {:noreply, socket}
  end

  def handle_in("space_select_avatar", payload, socket) do
    with %{space_kind: kind, space_id: space_id, participant_key: key} <- socket.assigns,
         {:ok, avatar} <- parse_select_avatar(payload) do
      dispatch_select_avatar(kind, space_id, key, avatar)
      # Remembered here as well as at the door: a character can also be
      # changed from inside the running space, and the chat must not keep
      # drawing the one that was left behind.
      remember_avatar(socket, avatar)
    end

    {:noreply, socket}
  end

  # Building answers the client: a refused edit has a reason the builder is
  # shown, and an accepted one is redrawn from the layout broadcast that every
  # client in the room receives alike.
  def handle_in("construct_build", payload, %{assigns: %{space_kind: :construct}} = socket) do
    %{space_id: space_id, participant_key: key, nickname: nickname} = socket.assigns

    case parse_build(payload) do
      {:ok, op} ->
        case VirtualSpace.build_construct(space_id, key, nickname, op) do
          {:ok, revision} -> {:reply, {:ok, %{revision: revision}}, socket}
          {:error, reason} -> {:reply, {:error, %{reason: Atom.to_string(reason)}}, socket}
        end

      :error ->
        {:reply, {:error, %{reason: "invalid"}}, socket}
    end
  end

  def handle_in(_event, _payload, socket) do
    {:noreply, socket}
  end

  @spec remember_avatar(Phoenix.Socket.t(), String.t()) :: :ok
  defp remember_avatar(socket, avatar) do
    case socket.assigns do
      %{nickname: nickname} when is_binary(nickname) ->
        Avatars.remember(nickname, avatar)
        :ok

      _no_nickname ->
        :ok
    end
  end

  @impl true
  def handle_info(%{event: event, payload: payload}, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    case socket.assigns do
      %{space_kind: :channel, space_id: space_id} ->
        VirtualSpace.leave_channel_space_viewer(space_id)

      %{space_kind: :direct_message, space_id: space_id, participant_key: participant_key} ->
        VirtualSpace.leave_direct_message_space_viewer(space_id, participant_key)

      %{space_kind: :construct, space_id: space_id, participant_key: participant_key} ->
        VirtualSpace.leave_construct_space_viewer(space_id, participant_key)

      _ ->
        :ok
    end

    :ok
  end

  defp verify_channel_join_token(%{"join_token" => join_token}, channel_name) do
    case ChannelJoinToken.verify(join_token) do
      {:ok, %{channel_name: ^channel_name} = data} ->
        if Map.get(data, :space_kind, "channel") == "channel" do
          {:ok, data}
        else
          {:error, :invalid_token}
        end

      {:ok, _other_channel} ->
        {:error, :invalid_token}

      {:error, _} ->
        {:error, :invalid_token}
    end
  end

  defp verify_channel_join_token(_params, _channel_name), do: {:error, :invalid_token}

  defp verify_direct_message_join_token(%{"join_token" => join_token}, space_id) do
    case ChannelJoinToken.verify(join_token) do
      {:ok, %{space_kind: "direct_message", space_id: ^space_id} = data} ->
        with {:ok, [nick_a, nick_b] = participants} <-
               DirectMessageSpace.normalize_participants(Map.get(data, :participants)),
             true <- DirectMessageSpace.member?(participants, data.nickname),
             ^space_id <- DirectMessageSpace.space_id(nick_a, nick_b) do
          {:ok, %{data | participants: participants}}
        else
          _ -> {:error, :invalid_token}
        end

      {:ok, _other_space} ->
        {:error, :invalid_token}

      {:error, _} ->
        {:error, :invalid_token}
    end
  end

  defp verify_direct_message_join_token(_params, _space_id), do: {:error, :invalid_token}

  # A Construct admits whoever its space admits. A private space's carries the
  # pair, checked the same way the private space's own token is; a channel's
  # is checked against the channel when the runtime seats the joiner.
  defp verify_construct_join_token(%{"join_token" => join_token}, construct_id) do
    with {:ok, %{space_kind: "construct", space_id: ^construct_id} = data} <-
           ChannelJoinToken.verify(join_token),
         {:ok, parent_id} <- VirtualSpace.construct_parent(construct_id),
         {:ok, participants} <- construct_participants(parent_id, data) do
      {:ok, Map.put(data, :participants, participants)}
    else
      _ -> {:error, :invalid_token}
    end
  end

  defp verify_construct_join_token(_params, _construct_id), do: {:error, :invalid_token}

  defp construct_participants("dm:" <> _pair = parent_id, data) do
    with {:ok, [nick_a, nick_b] = participants} <-
           DirectMessageSpace.normalize_participants(Map.get(data, :participants)),
         true <- DirectMessageSpace.member?(participants, data.nickname),
         ^parent_id <- DirectMessageSpace.space_id(nick_a, nick_b) do
      {:ok, participants}
    else
      _ -> :error
    end
  end

  defp construct_participants(_channel_name, _data), do: {:ok, nil}

  # Only the closed step payload is accepted; anything else is dropped so the
  # channel never forwards malformed client input to the domain.
  defp parse_input(%{"seq" => seq, "dx" => dx, "dy" => dy})
       when is_integer(seq) and is_integer(dx) and is_integer(dy) do
    {:ok, %{seq: seq, dx: dx, dy: dy}}
  end

  defp parse_input(_), do: :error

  defp parse_interact(%{"kind" => kind, "target_id" => target_id})
       when kind in ["sit", "stand", "use"] and is_binary(target_id) do
    {:ok, %{kind: kind, target_id: target_id}}
  end

  defp parse_interact(%{"kind" => "stand"}), do: {:ok, %{kind: "stand", target_id: nil}}

  defp parse_interact(_), do: :error

  defp parse_action(%{"kind" => "sword", "dir" => dir})
       when dir in ["up", "down", "left", "right"] do
    {:ok, %{kind: "sword", dir: dir}}
  end

  defp parse_action(%{"kind" => "sword"}), do: {:ok, %{kind: "sword"}}

  defp parse_action(_), do: :error

  # A recipe is short; anything longer is not one, and is not carried further
  # (into telemetry, into the space) to be refused there.
  defp parse_select_avatar(%{"avatar" => avatar})
       when is_binary(avatar) and avatar != "" and byte_size(avatar) <= 64,
       do: {:ok, avatar}

  defp parse_select_avatar(_), do: :error

  defp parse_build(%{"op" => "place", "kind" => kind, "x" => x, "y" => y} = payload)
       when is_binary(kind) and is_integer(x) and is_integer(y),
       do: {:ok, {:place, kind, x, y, Map.get(payload, "dir")}}

  defp parse_build(%{"op" => "move", "item_id" => id, "x" => x, "y" => y})
       when is_binary(id) and is_integer(x) and is_integer(y),
       do: {:ok, {:move, id, x, y}}

  defp parse_build(%{"op" => "remove", "item_id" => id}) when is_binary(id),
    do: {:ok, {:remove, id}}

  defp parse_build(%{"op" => "rotate", "item_id" => id}) when is_binary(id),
    do: {:ok, {:rotate, id}}

  defp parse_build(%{"op" => "label", "item_id" => id, "text" => text})
       when is_binary(id) and is_binary(text) and byte_size(text) <= @label_bytes,
       do: {:ok, {:label, id, text}}

  defp parse_build(%{
         "op" => "paint",
         "x0" => x0,
         "y0" => y0,
         "x1" => x1,
         "y1" => y1,
         "material" => material
       })
       when is_integer(x0) and is_integer(y0) and is_integer(x1) and is_integer(y1) and
              is_binary(material),
       do: {:ok, {:paint, x0, y0, x1, y1, material}}

  defp parse_build(_payload), do: :error

  # The viewer made their character on the entry screen; naming it at join
  # means the snapshot already wears it, instead of showing a stranger who
  # changes a moment later.
  defp build_channel_actor(data, params) do
    %{
      user_id: data.user_id,
      nickname: data.nickname,
      avatar: parse_avatar(params)
    }
  end

  defp parse_avatar(%{"avatar" => avatar})
       when is_binary(avatar) and avatar != "" and byte_size(avatar) <= 64,
       do: avatar

  defp parse_avatar(_params), do: nil

  # `space_init` is the join reply (see `js/lib/space/protocol.js`): the full
  # canonical map inline, the viewer's own key, render config and the initial
  # snapshot. The map is serialized from the Elixir source of truth so the
  # client never keeps its own copy. Its tileset sources are digested on the way
  # out: the domain names the sheet, the web layer knows what URL that is.
  defp space_init(channel_name, result) do
    %{
      version: 1,
      channel_name: channel_name,
      self_key: result.participant.key,
      map: SpaceAssets.digest_map(result.map),
      config: %{
        tile_size: result.map.tile_size,
        # Isometric is the only projection and every tile/avatar is premium art
        # authored at world size, so the whole scene renders native 1:1.
        scale: 1,
        avatar_scale: 1,
        # Movement cooldown; the client paces held-key repeat steps to this.
        step_ms: VirtualSpace.step_ms(),
        text_chat: "global",
        # The Construct is the one world its visitors can build in.
        buildable: VirtualSpace.space_kind(channel_name) == :construct
      },
      snapshot: result.snapshot
    }
  end

  defp join_error(:not_found), do: "not_found"
  defp join_error(:invalid_token), do: "invalid_token"
  defp join_error(:not_in_channel), do: "not_in_channel"
  defp join_error(:not_in_direct_message), do: "not_in_direct_message"
  defp join_error(:invalid_participants), do: "invalid_token"

  defp join_error(other) do
    Logger.debug("Space join denied: #{inspect(other)}")
    "access_denied"
  end

  defp dispatch_input(kind, space_id, key, payload) when kind in [:channel, :construct],
    do: VirtualSpace.input(space_id, key, payload)

  defp dispatch_input(:direct_message, space_id, key, payload),
    do: VirtualSpace.input_direct_message(space_id, key, payload)

  defp dispatch_interact(kind, space_id, key, payload, nickname)
       when kind in [:channel, :construct],
       do: VirtualSpace.interact(space_id, key, payload, nickname)

  defp dispatch_interact(:direct_message, space_id, key, payload, _nickname),
    do: VirtualSpace.interact_direct_message(space_id, key, payload)

  defp dispatch_action(kind, space_id, key, payload) when kind in [:channel, :construct],
    do: VirtualSpace.action(space_id, key, payload)

  defp dispatch_action(:direct_message, space_id, key, payload),
    do: VirtualSpace.action_direct_message(space_id, key, payload)

  # A Construct is reached through the same calls as a channel space: the
  # runtime picks the process by the shape of the id.
  defp dispatch_select_avatar(kind, space_id, key, avatar) when kind in [:channel, :construct],
    do: VirtualSpace.select_avatar(space_id, key, avatar)

  defp dispatch_select_avatar(:direct_message, space_id, key, avatar),
    do: VirtualSpace.select_avatar_direct_message(space_id, key, avatar)
end
