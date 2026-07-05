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

      {:ok, space_init(result), socket}
    else
      {:error, reason} ->
        {:error, %{reason: join_error(reason)}}
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

  defp build_actor(data) do
    %{
      user_id: data.user_id,
      nickname: data.nickname,
      identified: NickServ.identified?(data.nickname),
      is_admin: false,
      is_server_operator: false
    }
  end

  defp space_init(result) do
    %{
      version: 1,
      participant: result.participant,
      snapshot: result.snapshot
    }
  end

  defp join_error(:space_full), do: "space_full"
  defp join_error(:not_found), do: "not_found"
  defp join_error(:terminal_session), do: "terminal_session"
  defp join_error(:invalid_token), do: "invalid_token"

  defp join_error(other) do
    Logger.info("Space join denied: #{inspect(other)}")
    "access_denied"
  end
end
