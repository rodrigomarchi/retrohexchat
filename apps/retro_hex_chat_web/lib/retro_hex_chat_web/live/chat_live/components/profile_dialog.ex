defmodule RetroHexChatWeb.ChatLive.Components.ProfileDialog do
  @moduledoc """
  The Profile window body: nickname change and the `/whois` bio editor.

  Owns the `nick_error` and the bio editor state (`bio_draft`, `bio_warning`);
  the current `nickname` is supplied by the parent as a template attr. The forms
  are handled on the parent's `ProfileEvents`, which runs the nick/bio commands
  and reflects errors and the normalized draft back here via `send_update`.

  The bio draft is seeded on the island's `mount/1` from the session — the
  window is server-managed, so closing unmounts it and reopening re-seeds.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.ProfileDialog

  @id "profile-dialog"

  @doc "Stable component id."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       nickname: "",
       bio_draft: "",
       bio_warning: nil,
       nick_error: nil
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:nick_error, message}}, socket) do
    {:ok, assign(socket, nick_error: message)}
  end

  def update(%{action: {:bio, draft, warning}}, socket) do
    {:ok, assign(socket, bio_draft: draft, bio_warning: warning)}
  end

  def update(assigns, socket) do
    {:ok,
     assign(socket,
       id: Map.get(assigns, :id, socket.assigns.id),
       nickname: Map.get(assigns, :nickname, socket.assigns.nickname),
       bio_draft: Map.get(assigns, :bio, socket.assigns.bio_draft)
     )}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.profile_panel
        id={@id}
        nickname={@nickname}
        nick_error={@nick_error}
        bio={@bio_draft || ""}
        bio_warning={@bio_warning}
      />
    </div>
    """
  end
end
