defmodule RetroHexChatWeb.Live.ShareControl do
  @moduledoc """
  One button on every surface that can hand out its address, and the dialog
  behind it.

  Minting and revoking belong to the surface — it is the one that knows what is
  being shared — so both are dispatched by name to the host LiveView, exactly as
  before. What lives here is the only state the surfaces would otherwise each
  have to carry: whether the dialog is open. Four copies of that assign, four
  copies of an open and a close event, is four chances for them to drift.

  The dialog opens by itself the moment a link first arrives, because pressing
  Share is a request to see the address, not merely to create one.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.ShareLinkDialog

  alias RetroHexChatWeb.Components.UI.Button
  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true
  attr :url, :string, default: nil, doc: "the minted share URL, once there is one"
  attr :available, :boolean, default: true, doc: "false when the viewer may not mint one"
  attr :on_share, :string, required: true
  attr :on_revoke, :string, default: nil
  attr :share_target, :any, default: nil, doc: "target for the host's mint and revoke events"
  attr :scope, :atom, default: :viewport, values: [:viewport, :window]
  attr :class, :any, default: nil

  attr :variant, :string,
    default: "default",
    doc: "how loudly the control reads beside whatever else the surface puts next to it"

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       open?: false,
       seen_once?: false,
       url: nil,
       available: true,
       on_revoke: nil,
       share_target: nil,
       scope: :viewport,
       variant: "default",
       class: nil
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    # Only a mint opens the dialog, and a mint is a link appearing on a control
    # that was already on screen without one. A control mounting with a link
    # already made is somebody arriving where the link exists — walking into a
    # call you had shared earlier must not put the address in front of you.
    minted? =
      socket.assigns.seen_once? and is_nil(socket.assigns.url) and is_binary(assigns[:url])

    still_open? = socket.assigns.open? and is_binary(assigns[:url])

    {:ok,
     socket
     |> assign(assigns)
     |> assign(open?: minted? or still_open?, seen_once?: true)}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("share_dialog_open", _params, socket),
    do: {:noreply, assign(socket, open?: true)}

  def handle_event("share_dialog_close", _params, socket),
    do: {:noreply, assign(socket, open?: false)}

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class={["flex items-center gap-2", @class]} data-testid="share-bar">
      <%!-- One control, one size, in both states: a surface that lays this out
            never has to make room for the link arriving. --%>
      <Button.button
        :if={is_nil(@url)}
        type="button"
        variant={@variant}
        phx-click={@on_share}
        phx-target={@share_target}
        disabled={!@available}
        data-testid="share-create"
      >
        <:icon><Icons.icon_btn_link class="h-4 w-4" /></:icon>
        {dgettext("share", "Share")}
      </Button.button>

      <Button.button
        :if={@url}
        type="button"
        variant={@variant}
        phx-click="share_dialog_open"
        phx-target={@myself}
        data-testid="share-open"
      >
        <:icon><Icons.icon_btn_link class="h-4 w-4" /></:icon>
        {dgettext("share", "Share link")}
      </Button.button>

      <span :if={is_nil(@url) and !@available} class="text-muted-foreground text-sm">
        {dgettext("share", "Register your nickname to share a link.")}
      </span>

      <%!-- No link, no window: a hidden dialog holding an empty field is a
            field on the page saying there is an address when there is none. --%>
      <.share_link_dialog
        :if={@url}
        id={"#{@id}-dialog"}
        show={@open?}
        url={@url}
        scope={@scope}
        on_close={JS.push("share_dialog_close", target: @myself)}
        on_revoke={@on_revoke}
        revoke_target={@share_target}
      />
    </div>
    """
  end
end
