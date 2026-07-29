defmodule RetroHexChatWeb.ChatLive.Components.UserLookupDialog do
  @moduledoc """
  The User Lookup island: a nickname form plus the Whois/Whowas result card,
  rendered inside the user-lookup desktop window.

  Owns the input draft (`nick`, `error`); the last `result` is a parent assign
  (`lookup_result`) passed through as a template attr, so it reaches the island
  in the same diff that mounts the window. The window is managed, so closing it
  unmounts the island and resets the draft. `user_lookup_change` updates the
  controlled nickname input locally. `user_lookup_whois` (form submit) and
  `user_lookup_whowas` run the lookup on the parent's `UserLookupEvents`,
  reading the nickname from the submitted params. The result-card actions
  (`lookup_result_whois`, `lookup_result_whowas`, `lookup_result_query`,
  `close_lookup_result`) are handled by the parent, which re-runs a lookup,
  opens a PM, or clears the card.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.UserLookupDialog

  # Must differ from the desktop window's DOM id ("user-lookup") — a
  # LiveComponent whose logical id collides with another element's DOM id
  # breaks component patching (updates land in the virtual tree, never the DOM).
  @id "user-lookup-dialog"

  @doc "Stable component id."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
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

  def update(%{action: {:open, nickname}}, socket) do
    {:ok, assign(socket, nick: nickname || "", error: nil)}
  end

  def update(%{action: {:error, message}}, socket) do
    {:ok, assign(socket, error: message)}
  end

  def update(assigns, socket) do
    {:ok,
     assign(socket,
       id: Map.get(assigns, :id, socket.assigns.id),
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
    <div id={"#{@id}-mount"} class="contents">
      <.user_lookup_panel
        id="user-lookup-dialog"
        nickname={@nick}
        error_message={@error}
        result={@result}
        on_change={JS.push("user_lookup_change", target: @myself)}
        on_whois="user_lookup_whois"
        on_whowas="user_lookup_whowas"
      />
    </div>
    """
  end
end
