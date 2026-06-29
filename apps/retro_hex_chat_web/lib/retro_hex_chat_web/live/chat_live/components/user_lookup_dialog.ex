defmodule RetroHexChatWeb.ChatLive.Components.UserLookupDialog do
  @moduledoc """
  The User Lookup dialog and its Whois/Whowas result card.

  Holds a nickname input and renders the result card from `lookup_result` (the
  card shares this component because it belongs to the same lookup flow). `result`
  and `visible` are supplied by the parent; `lookup_result` is produced by the
  `/whois` and `/whowas` commands, which run on the parent.

  Owns the input draft — `nick` and `error`. `user_lookup_change` updates the
  controlled nickname input locally. `user_lookup_whois` (form submit) and
  `user_lookup_whowas` run the lookup on the parent's `UserLookupEvents`, reading
  the nickname from the submitted params. The result-card actions
  (`lookup_result_whois`, `lookup_result_whowas`, `lookup_result_query`,
  `close_lookup_result`) are handled by the parent, which re-runs a lookup, opens
  a PM, or clears the result. `show_user_lookup_dialog` and `lookup_result` live
  on the parent because the Escape handler reads them.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.UserLookupDialog

  @id "user-lookup"

  @doc "Stable component id."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       visible: false,
       result: nil,
       nick: "",
       error: nil
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: :open}, socket) do
    {:ok, assign(socket, nick: "", error: nil)}
  end

  def update(%{action: {:error, message}}, socket) do
    {:ok, assign(socket, error: message)}
  end

  def update(assigns, socket) do
    {:ok,
     assign(socket,
       id: Map.get(assigns, :id, socket.assigns.id),
       visible: Map.get(assigns, :visible, socket.assigns.visible),
       result: Map.get(assigns, :result, socket.assigns.result)
     )}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("user_lookup_change", %{"nickname" => nickname}, socket) do
    {:noreply, assign(socket, nick: nickname, error: nil)}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"}>
      <.user_lookup_dialog
        id="user-lookup-dialog"
        show={@visible}
        nickname={@nick}
        error_message={@error}
        on_change={JS.push("user_lookup_change", target: @myself)}
        on_whois="user_lookup_whois"
        on_whowas="user_lookup_whowas"
        on_close="close_user_lookup"
      />

      <.lookup_result_card
        id="lookup-result-dialog"
        show={@result != nil}
        result={@result}
        on_close="close_lookup_result"
        on_whois="lookup_result_whois"
        on_whowas="lookup_result_whowas"
        on_query="lookup_result_query"
      />
    </div>
    """
  end
end
