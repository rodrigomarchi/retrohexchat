defmodule RetroHexChatWeb.Live.Surface do
  @moduledoc """
  What every app surface that is not the chat has in common.

  A call, a space or a game can live in a browser tab of its own, beside the
  chat. Getting there needs three things and deliberately not a fourth.

  It needs the person's nickname, which is the same Plug session the chat reads,
  and it needs the two refusals that go with it: no session goes to `/connect`,
  and a banned nickname goes there saying why. Those were written inside
  `ChatLive.mount/3`; a second copy in each surface is how one of them would end
  up missing the ban check.

  It needs to hear that the person's session ended. It subscribes to
  `Topics.surfaces/1` and nowhere else, because that topic carries only that
  message — the inbox carries private conversations too, and a surface
  subscribed there would need a clause that ignores them, which is the shape of
  a catch-all that eats what you depend on.

  It registers itself as one of the person's open surfaces
  (`RetroHexChat.Surfaces`). That is what keeps the chat's tab closing from
  taking the person out of the channels a call still stands on: the channels
  are left when the last surface closes, not when the chat's does.

  What it must **not** do is the fourth thing, and each omission is a bug that
  would exist without it:

    * it never announces a takeover. `ChatLive.mount/3` does, on the inbox, and
      that is what ends the previous chat. A surface that did the same would end
      the chat that opened it.
    * it never tracks or untracks global presence. That is owned by the chat
      session and released by `ChatLive.terminate/2`; a surface that untracked
      would make closing the game tab look like going offline while the chat is
      still open.
    * it never writes reconnect state, whowas, or a device session. Those record
      what a chat session did, and a surface did not do them.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1, push_navigate: 2, redirect: 2]

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Accounts.NicknameValidator
  alias RetroHexChat.Admin.ServerBans
  alias RetroHexChat.Surfaces
  alias RetroHexChat.Topics
  alias RetroHexChatWeb.App.Paths

  @spec on_mount(atom(), map(), map(), Socket.t()) :: {:cont, Socket.t()} | {:halt, Socket.t()}
  def on_mount(:default, _params, session, socket) do
    nickname = session["chat_nickname"]

    cond do
      not is_binary(nickname) or NicknameValidator.validate(nickname) != :ok ->
        {:halt, push_navigate(socket, to: Paths.connect_path(socket))}

      ServerBans.banned?(nickname) ->
        {:halt, push_navigate(socket, to: Paths.connect_path(socket, "banned"))}

      true ->
        {:cont, attach(socket, nickname)}
    end
  end

  defp attach(socket, nickname) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.surfaces(nickname))
      # The view, not a label. Which *instance* it is comes a moment later, from
      # `handle_params`: the module says what kind of screen this is, the path
      # says which one.
      Surfaces.open(nickname, socket.view)
    end

    # Only the nickname. Timezone and client info are the chat session's, and a
    # surface that assigned them without reading them would be state nobody
    # maintains — the shape `@retro_games` had before it was deleted.
    socket
    |> assign(surface_nickname: nickname)
    |> attach_hook(:surface_address, :handle_params, &address_changed/3)
    |> attach_hook(:surface_session_ended, :handle_info, &session_ended/2)
  end

  # Where this surface is, told to the registry every time it changes. It has to
  # be here and not in `attach/2`: at mount the address is not known yet — a
  # LiveView learns it in `handle_params`, which is also the only place it
  # learns that it moved.
  defp address_changed(_params, uri, socket) do
    if connected?(socket) do
      Surfaces.address(socket.assigns.surface_nickname, path_of(uri))
    end

    {:cont, socket}
  end

  # The path and nothing else: the chat compares it against the address it would
  # have opened, and a query string or a host would make two spellings of the
  # same tab.
  defp path_of(uri) when is_binary(uri) do
    case URI.parse(uri) do
      %URI{path: path} when is_binary(path) -> path
      _hostless -> uri
    end
  end

  defp path_of(_uri), do: "/"

  # The topic this arrives on carries nothing else, so there is no message here
  # to tell apart — anything else on it would be a bug in the publisher, and
  # letting it through to the surface's own `handle_info/2` is what surfaces it.
  defp session_ended({:force_disconnect, payload}, socket) do
    {:halt, redirect(socket, to: Paths.session_clear_path(socket, Map.get(payload, :reason, "")))}
  end

  defp session_ended(_message, socket), do: {:cont, socket}
end
