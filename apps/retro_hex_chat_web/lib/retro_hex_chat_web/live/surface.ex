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

  It also carries what a surface does *to itself*: `error/2`, `system/2` and
  `close/1`. These used to choose between a parent process and a page, because
  every surface had a mount inside the chat as well. None of them does now, so
  the choice is gone and what is left is a screen saying something on its own
  status bar and a screen saying it is finished.
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

  @doc "A refusal or a failure, in the words the policy used."
  @spec error(Socket.t(), String.t()) :: Socket.t()
  def error(socket, message), do: notice(socket, :error, message)

  @doc "Something that happened, worth recording where the person is reading."
  @spec system(Socket.t(), String.t()) :: Socket.t()
  def system(socket, message), do: notice(socket, :system, message)

  defp notice(socket, kind, message) do
    assign(socket, notice: %{kind: kind, message: message})
  end

  @doc """
  The surface is finished and should leave the screen.

  Leaving is **not** navigating to `/chat`. Mounting the chat is announcing a
  chat session, and a chat session announces a takeover — so going "back" by
  navigation ended the chat this person already had open, in another tab, that
  they never asked to leave. Measured: cancelling an antechamber left the
  original chat sitting on
  `/connect?reason=Session ended — logged in from another window`.

  The surface says it is finished instead, and the way back is the same
  `back_to_chat` every surface already draws — a request for the tab that
  exists, and a plain link only when there is none.
  """
  @spec close(Socket.t()) :: Socket.t()
  def close(socket) do
    _ = release_address(socket)
    assign(socket, surface_left: true)
  end

  # The tab is still open and still counts for the membership rule; it is just
  # not somewhere to send anybody any more.
  defp release_address(socket) do
    case socket.assigns[:surface_nickname] || socket.assigns[:nickname] do
      nickname when is_binary(nickname) and nickname != "" -> Surfaces.release(nickname)
      _anonymous -> :ok
    end
  end
end
