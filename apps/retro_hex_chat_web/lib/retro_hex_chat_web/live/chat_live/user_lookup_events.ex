defmodule RetroHexChatWeb.ChatLive.UserLookupEvents do
  @moduledoc """
  Handle User Lookup window and result card events.

  Covers: open_user_lookup, user_lookup_submit,
  close_lookup_result, lookup_result_whois,
  lookup_result_whowas, lookup_result_query.
  """

  import Phoenix.LiveView, only: [push_event: 3, send_update: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import Phoenix.Component, only: [assign: 2]
  import RetroHexChatWeb.ChatLive.Helpers, only: [open_pm_conversation: 2]

  alias RetroHexChatWeb.ChatLive.CommandDispatch
  alias RetroHexChatWeb.ChatLive.Components.UserLookupDialog
  alias RetroHexChatWeb.ChatLive.Windows

  @doc "Opens (or focuses) the User Lookup window with a fresh input draft."
  @spec open(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def open(socket) do
    socket
    |> assign(lookup_result: nil)
    |> Windows.open_with("user-lookup", UserLookupDialog,
      id: UserLookupDialog.id(),
      action: :open
    )
  end

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt | :cont, Phoenix.LiveView.Socket.t()}
  def handle_event("open_user_lookup", %{"nickname" => nickname}, socket) do
    nickname = String.trim(nickname || "")

    socket =
      if nickname == "" do
        open(socket)
      else
        socket
        |> open_prefilled(nickname)
        |> dispatch_lookup("whois", nickname)
      end

    {:halt, socket}
  end

  def handle_event("open_user_lookup", _params, socket) do
    {:halt, open(socket)}
  end

  # Both buttons submit the form, so the nickname comes from the field rather
  # than from an assign a `phx-change` may not have filled yet.
  def handle_event("user_lookup_submit", %{"lookup" => "whowas"} = params, socket) do
    {:halt, submit_lookup(socket, "whowas", lookup_nick(params))}
  end

  def handle_event("user_lookup_submit", params, socket) do
    {:halt, submit_lookup(socket, "whois", lookup_nick(params))}
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
     |> push_event("window_command", %{action: "close", id: "user-lookup"})
     |> open_pm_conversation(nick)}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  defp submit_lookup(socket, command, nickname) do
    nickname = String.trim(nickname || "")

    if nickname == "" do
      send_update(UserLookupDialog,
        id: UserLookupDialog.id(),
        action: {:error, dgettext("chat", "Nickname is required.")}
      )

      socket
    else
      dispatch_lookup(socket, command, nickname)
    end
  end

  defp dispatch_lookup(socket, command, nickname) do
    CommandDispatch.dispatch_command(socket, socket.assigns.session, command, [nickname])
  end

  defp open_prefilled(socket, nickname) do
    socket
    |> assign(lookup_result: nil)
    |> Windows.open_with("user-lookup", UserLookupDialog,
      id: UserLookupDialog.id(),
      action: {:open, nickname}
    )
  end

  defp lookup_nick(params) do
    Map.get(params, "nickname") || ""
  end
end
