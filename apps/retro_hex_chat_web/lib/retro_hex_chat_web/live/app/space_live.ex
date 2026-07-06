defmodule RetroHexChatWeb.App.SpaceLive do
  @moduledoc """
  Shell LiveView for a virtual space.

  Validates the HTTP session, the space token and the join policy, then
  renders the canvas shell with a signed `join_token`. The world runtime
  never flows through this process: the `SpaceCanvasHook` opens its own
  Phoenix Channel (`space:<token>`) authorized by the signed token.

  Invalid, terminal, full and access-denied sessions render retro terminal
  states instead of the canvas.
  """
  use RetroHexChatWeb, :live_view

  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.VirtualSpace
  alias RetroHexChat.VirtualSpace.JoinToken
  alias RetroHexChatWeb.App.SessionHelpers

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"token" => token}, session, socket) do
    nickname = session["chat_nickname"]

    with {:ok, socket} <- SessionHelpers.verify_nickname(socket, nickname),
         {:ok, user_id} <- SessionHelpers.resolve_user_id(nickname),
         {:ok, db_session} <- fetch_session(token),
         actor = build_actor(user_id, nickname),
         :ok <- VirtualSpace.can_join?(actor, db_session),
         :ok <- VirtualSpace.check_capacity(db_session, user_id) do
      {:ok, assign_shell(socket, token, db_session, user_id, nickname)}
    else
      {:redirect, redirect_socket} when is_struct(redirect_socket) ->
        {:ok, redirect_socket}

      {:redirect, _} ->
        {:ok, assign_state(socket, :denied, token, nil)}

      {:error, :not_found} ->
        {:ok, assign_state(socket, :invalid, token, nil)}

      {:error, :terminal_session} ->
        {:ok, assign_terminal(socket, token)}

      {:error, :space_full} ->
        {:ok, assign_state(socket, :full, token, nil)}

      {:error, _denied} ->
        {:ok, assign_state(socket, :denied, token, nil)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center p-4" data-testid="space-root">
      <%= case @state do %>
        <% :invalid -> %>
          <.terminal_panel testid="space-invalid" title={dgettext("space", "SPACE NOT FOUND")}>
            {dgettext("space", "This virtual space link is invalid or was removed.")}
          </.terminal_panel>
        <% :terminal -> %>
          <.terminal_panel
            testid="space-terminal"
            title={dgettext("space", "SPACE ENDED — %{status}", status: @session_status)}
          >
            {dgettext("space", "This virtual space is no longer active.")}
          </.terminal_panel>
        <% :full -> %>
          <.terminal_panel testid="space-full" title={dgettext("space", "SPACE FULL")}>
            {dgettext("space", "This virtual space is at capacity. Try again later.")}
          </.terminal_panel>
        <% :denied -> %>
          <.terminal_panel testid="space-denied" title={dgettext("space", "ACCESS DENIED")}>
            {dgettext(
              "space",
              "You do not have access to this virtual space. You must be registered, identified and allowed into its channel."
            )}
          </.terminal_panel>
        <% :ready -> %>
          <div class="w-full max-w-4xl" data-testid="space-shell">
            <div class="mb-2 flex items-baseline justify-between">
              <h1 class="font-bold text-lg">{@space_title}</h1>
              <span class="text-xs text-muted-foreground">{@channel_name}</span>
            </div>
            <div
              id="space-canvas-root"
              phx-hook="SpaceCanvasHook"
              phx-update="ignore"
              data-space-token={@space_token}
              data-join-token={@join_token}
              data-nickname={@nickname}
              class="relative bg-canvas shadow-retro-field aspect-[4/3] w-full"
            >
              <canvas id="space-canvas" class="h-full w-full"></canvas>
              <div class="absolute top-1 right-1 bg-canvas shadow-retro-field px-2 py-0.5 text-xs font-bold">
                <span data-space-hud-count>1</span>
                <span>{dgettext("space", "here")}</span>
              </div>
              <div
                data-space-modal
                hidden
                class="absolute inset-0 m-auto h-fit w-fit bg-canvas shadow-retro-field p-3 text-center"
              >
              </div>
              <input
                type="text"
                data-space-chat-input
                maxlength="160"
                autocomplete="off"
                placeholder={dgettext("space", "Say something… (Enter to send)")}
                class="absolute bottom-1 left-1 right-1 bg-canvas shadow-retro-field px-2 py-1 text-sm"
              />
              <div
                :if={@is_creator}
                class="absolute top-1 left-1 bg-canvas shadow-retro-field p-2 text-xs"
              >
                <div class="font-bold mb-1">{dgettext("space", "Host controls")}</div>
                <div data-space-admin-list class="flex flex-col gap-1"></div>
              </div>
              <div
                data-space-kicked
                hidden
                class="absolute inset-0 flex items-center justify-center bg-canvas font-mono text-center p-6"
              >
                <div>
                  <div class="font-bold mb-2">{dgettext("space", "REMOVED FROM SPACE")}</div>
                  <p class="text-sm">{dgettext("space", "The host removed you from this space.")}</p>
                  <.link navigate={~p"/chat"} class="mt-4 inline-block underline text-sm">
                    {dgettext("space", "Back to chat")}
                  </.link>
                </div>
              </div>
              <div
                data-space-closed
                hidden
                class="absolute inset-0 flex items-center justify-center bg-canvas font-mono text-center p-6"
              >
                <div>
                  <div class="font-bold mb-2">{dgettext("space", "SPACE CLOSED")}</div>
                  <p class="text-sm">{dgettext("space", "This virtual space has ended.")}</p>
                  <.link navigate={~p"/chat"} class="mt-4 inline-block underline text-sm">
                    {dgettext("space", "Back to chat")}
                  </.link>
                </div>
              </div>
            </div>
            <p class="mt-1 text-xs text-muted-foreground">
              {dgettext("space", "Arrows/WASD to move · E to use · F to sit · Esc to close")}
            </p>
          </div>
      <% end %>
    </div>
    """
  end

  attr :testid, :string, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  defp terminal_panel(assigns) do
    ~H"""
    <div
      class="max-w-md w-full bg-canvas shadow-retro-field p-6 text-center font-mono"
      data-testid={@testid}
    >
      <div class="font-bold mb-3">{@title}</div>
      <p class="text-sm">{render_slot(@inner_block)}</p>
      <.link navigate={~p"/chat"} class="mt-4 inline-block underline text-sm">
        {dgettext("space", "Back to chat")}
      </.link>
    </div>
    """
  end

  defp fetch_session(token) do
    VirtualSpace.get_session(token)
  end

  defp build_actor(user_id, nickname) do
    %{
      user_id: user_id,
      nickname: nickname,
      identified: NickServ.identified?(nickname),
      is_admin: false,
      is_server_operator: false
    }
  end

  defp assign_shell(socket, token, db_session, user_id, nickname) do
    socket
    |> assign(
      state: :ready,
      space_token: token,
      join_token: JoinToken.sign(token, user_id, nickname),
      space_title: db_session.title || dgettext("space", "Virtual space"),
      channel_name: db_session.channel_name,
      nickname: nickname,
      user_id: user_id,
      is_creator: db_session.creator_id == user_id,
      page_title: db_session.title || dgettext("space", "Virtual space")
    )
  end

  defp assign_terminal(socket, token) do
    status =
      case VirtualSpace.get_session(token) do
        {:ok, session} -> session.status
        _ -> "closed"
      end

    socket
    |> assign_state(:terminal, token, status)
  end

  defp assign_state(socket, state, token, session_status) do
    assign(socket,
      state: state,
      space_token: token,
      session_status: session_status,
      page_title: dgettext("space", "Virtual space")
    )
  end
end
