defmodule RetroHexChatWeb.ChatLive.Components.AsciiArtWindow do
  @moduledoc """
  Island for ASCII Art's window body: the art (made in the browser by
  `AsciiArtHook`), and posting it.

  Post sends the art up as the message it will be. The island checks it the
  way the chat will (`Content.validate/2` in the `irc_art` format) and shows
  it in the Post dialog drawn by the chat's own renderer — so what the dialog
  shows is exactly the line the channel will get — then hands it to the
  desktop (`ToolPost.post/3`).
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.AsciiArt, only: [ascii_body: 1]
  import RetroHexChatWeb.Components.UI.PostToDialog

  alias RetroHexChat.Chat.Content
  alias RetroHexChatWeb.ChatLive.ToolPost

  use RetroHexChatWeb.ChatLive.Components.DialogIsland,
    id: "ascii-art-window",
    initial: %{art: nil, post_error: nil},
    known: [:session]

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("ascii_post_open", %{"art" => art}, socket) when is_binary(art) do
    error =
      case Content.validate_message(art, :irc_art) do
        :ok -> nil
        {:error, reason} -> reason
      end

    {:noreply, assign(socket, art: art, post_error: error)}
  end

  def handle_event("ascii_post_cancel", _params, socket) do
    {:noreply, assign(socket, art: nil, post_error: nil)}
  end

  def handle_event("ascii_post", %{"target" => value}, socket) do
    art = socket.assigns.art

    with true <- is_binary(art),
         :ok <- Content.validate(art, :irc_art),
         {:ok, target} <- ToolPost.target(socket.assigns.session, value) do
      :ok = ToolPost.post(target, art, content_format: "irc_art")
      {:noreply, assign(socket, art: nil, post_error: nil)}
    else
      _refused ->
        {:noreply, assign(socket, post_error: dgettext("ui", "Choose where to post it."))}
    end
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns = assign(assigns, options: ToolPost.options(assigns.session))

    ~H"""
    <div
      id="ascii-art-root"
      phx-hook="AsciiArtHook"
      phx-target={@myself}
      class="relative flex min-h-0 flex-1 flex-col"
      data-testid="ascii-art"
    >
      <.ascii_body />

      <.post_to_dialog
        :if={@art}
        id="ascii-art-post"
        target={@myself}
        title={dgettext("ui", "Post text art")}
        options={@options}
        selected={ToolPost.default(@session)}
        ready?={is_nil(@post_error)}
        error={@post_error}
        submit="ascii_post"
        cancel="ascii_post_cancel"
      >
        <:preview>
          <div class="ascii-art__posted">
            {Content.render_html(@art, :irc_art)}
          </div>
        </:preview>
      </.post_to_dialog>
    </div>
    """
  end
end
