defmodule RetroHexChatWeb.SpaceChannel do
  @moduledoc """
  Realtime channel for a virtual space (`space:<token>`).

  Join is authorized by the signed `join_token` that `SpaceLive` issues after
  running the join policy; the channel re-runs policy and capacity through
  `VirtualSpace.join_session/2`, so a stale or replayed token can never
  overfill a space. The reply is the `space_init` payload (participant +
  snapshot). Domain broadcasts on the `space:<token>` PubSub topic are pushed
  through to the client verbatim.
  """
  use Phoenix.Channel

  require Logger

  alias RetroHexChat.Accounts.ServerRoles
  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.VirtualSpace
  alias RetroHexChat.VirtualSpace.JoinToken

  @impl true
  def join("space:" <> token, params, socket) do
    with {:ok, data} <- verify_join_token(params, token),
         {:ok, result} <- VirtualSpace.join_session(token, build_actor(data)) do
      socket =
        socket
        |> assign(:space_token, token)
        |> assign(:participant_key, result.participant.key)
        |> assign(:user_id, data.user_id)
        |> assign(:nickname, data.nickname)

      {:ok, space_init(token, result), socket}
    else
      {:error, reason} ->
        {:error, %{reason: join_error(reason)}}
    end
  end

  @impl true
  def handle_in("space_input", payload, socket) do
    with %{space_token: token, participant_key: key} <- socket.assigns,
         {:ok, step} <- parse_input(payload) do
      VirtualSpace.input(token, key, step)
    end

    {:noreply, socket}
  end

  def handle_in("space_chat_bubble", %{"text" => text}, socket) when is_binary(text) do
    with %{space_token: token, participant_key: key} <- socket.assigns do
      VirtualSpace.chat_bubble(token, key, text)
    end

    {:noreply, socket}
  end

  def handle_in("space_admin_action", payload, socket) do
    with %{space_token: token} <- socket.assigns,
         {:ok, action} <- parse_admin_action(payload) do
      VirtualSpace.admin_action(token, admin_actor(socket), action)
    end

    {:noreply, socket}
  end

  def handle_in("space_interact", payload, socket) do
    with %{space_token: token, participant_key: key} <- socket.assigns,
         {:ok, interact} <- parse_interact(payload),
         {:ok, %{modal: modal}} <- VirtualSpace.interact(token, key, interact) do
      push(socket, "space_modal", modal)
    end

    {:noreply, socket}
  end

  def handle_in(_event, _payload, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{event: event, payload: payload}, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    case socket.assigns do
      %{space_token: token, participant_key: key} ->
        VirtualSpace.leave(token, key)

      _ ->
        :ok
    end

    :ok
  end

  defp verify_join_token(%{"join_token" => join_token}, token) do
    case JoinToken.verify(join_token) do
      {:ok, %{space_token: ^token} = data} -> {:ok, data}
      {:ok, _other_space} -> {:error, :invalid_token}
      {:error, _} -> {:error, :invalid_token}
    end
  end

  defp verify_join_token(_params, _token), do: {:error, :invalid_token}

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

  defp parse_admin_action(%{"kind" => "kick"} = p),
    do: {:ok, %{kind: "kick", target_key: p["target_key"], reason: p["reason"] || "kicked"}}

  defp parse_admin_action(%{"kind" => "mute"} = p),
    do: {:ok, %{kind: "mute", target_key: p["target_key"], muted: p["muted"] == true}}

  defp parse_admin_action(%{"kind" => "close"} = p),
    do: {:ok, %{kind: "close", reason: p["reason"] || "closed"}}

  defp parse_admin_action(%{"kind" => "change_map", "map_id" => map_id}) when is_binary(map_id),
    do: {:ok, %{kind: "change_map", map_id: map_id}}

  defp parse_admin_action(_), do: :error

  defp admin_actor(socket) do
    nickname = socket.assigns[:nickname]
    identified = NickServ.identified?(nickname)

    %{
      user_id: socket.assigns[:user_id],
      nickname: nickname,
      is_admin: ServerRoles.admin?(nickname, identified),
      is_server_operator: ServerRoles.server_operator?(nickname, identified)
    }
  end

  defp build_actor(data) do
    %{
      user_id: data.user_id,
      nickname: data.nickname,
      identified: NickServ.identified?(data.nickname),
      is_admin: false,
      is_server_operator: false
    }
  end

  # `space_init` is the join reply (see `js/lib/space/protocol.js`): the full
  # canonical map inline, the viewer's own key, render config and the initial
  # snapshot. The map is serialized from the Elixir source of truth so the
  # client never keeps its own copy.
  defp space_init(token, result) do
    %{
      version: 1,
      token: token,
      self_key: result.participant.key,
      map: result.map,
      config: %{
        tile_size: result.map.tile_size,
        scale: 2,
        text_chat: "global"
      },
      snapshot: result.snapshot
    }
  end

  defp join_error(:space_full), do: "space_full"
  defp join_error(:not_found), do: "not_found"
  defp join_error(:terminal_session), do: "terminal_session"
  defp join_error(:invalid_token), do: "invalid_token"
  defp join_error(:kicked), do: "kicked"

  defp join_error(other) do
    Logger.info("Space join denied: #{inspect(other)}")
    "access_denied"
  end
end
