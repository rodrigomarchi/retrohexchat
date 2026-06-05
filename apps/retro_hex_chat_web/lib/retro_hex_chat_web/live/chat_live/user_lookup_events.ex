defmodule RetroHexChatWeb.ChatLive.UserLookupEvents do
  @moduledoc """
  Handle User Lookup dialog and result card events.

  Covers: open_user_lookup, close_user_lookup, user_lookup_change,
  user_lookup_whois, user_lookup_whowas, close_lookup_result,
  lookup_result_whois, lookup_result_whowas, lookup_result_query.
  """

  import Phoenix.Component, only: [assign: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers, only: [open_pm_conversation: 2]

  alias RetroHexChatWeb.ChatLive.CommandDispatch

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt | :cont, Phoenix.LiveView.Socket.t()}
  def handle_event("open_user_lookup", _params, socket) do
    {:halt,
     assign(socket,
       show_user_lookup_dialog: true,
       user_lookup_nick: "",
       user_lookup_error: nil
     )}
  end

  def handle_event("close_user_lookup", _params, socket) do
    {:halt,
     assign(socket,
       show_user_lookup_dialog: false,
       user_lookup_nick: "",
       user_lookup_error: nil
     )}
  end

  def handle_event("user_lookup_change", %{"nickname" => nickname}, socket) do
    {:halt, assign(socket, user_lookup_nick: nickname, user_lookup_error: nil)}
  end

  def handle_event("user_lookup_whois", params, socket) do
    {:halt, submit_lookup(socket, "whois", lookup_nick(params, socket))}
  end

  def handle_event("user_lookup_whowas", params, socket) do
    {:halt, submit_lookup(socket, "whowas", lookup_nick(params, socket))}
  end

  def handle_event("close_lookup_result", _params, socket) do
    {:halt, assign(socket, lookup_result: nil)}
  end

  def handle_event("lookup_result_whois", %{"nick" => nick}, socket) do
    {:halt, dispatch_lookup(socket, "whois", nick)}
  end

  def handle_event("lookup_result_whowas", %{"nick" => nick}, socket) do
    {:halt, dispatch_lookup(socket, "whowas", nick)}
  end

  def handle_event("lookup_result_query", %{"nick" => nick}, socket) do
    {:halt,
     socket
     |> assign(lookup_result: nil)
     |> open_pm_conversation(nick)}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  defp submit_lookup(socket, command, nickname) do
    nickname = String.trim(nickname || "")

    if nickname == "" do
      assign(socket, user_lookup_error: dgettext("chat", "Nickname is required."))
    else
      socket
      |> assign(
        show_user_lookup_dialog: false,
        user_lookup_nick: "",
        user_lookup_error: nil
      )
      |> dispatch_lookup(command, nickname)
    end
  end

  defp dispatch_lookup(socket, command, nickname) do
    CommandDispatch.dispatch_command(socket, socket.assigns.session, command, [nickname])
  end

  defp lookup_nick(params, socket) do
    Map.get(params, "nickname") || socket.assigns[:user_lookup_nick] || ""
  end
end
