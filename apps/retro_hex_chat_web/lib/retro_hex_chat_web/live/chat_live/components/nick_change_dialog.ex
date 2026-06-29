defmodule RetroHexChatWeb.ChatLive.Components.NickChangeDialog do
  @moduledoc """
  Stateful LiveComponent owning the nick-change dialog. Unlike the
  knock/invite dialogs this one is NOT in the Escape-dismissal map, so the
  component owns its visibility (`show`) outright — like `DeleteConfirmDialog`.

  Owned state: `target_nick`, `registered`, `password`, `password_error`.

  - Password keyup and Cancel are handled component-locally (`@myself`).
  - Confirm bubbles to the parent (`confirm_nick_change`) carrying `target` and
    `registered` via `JS.push`, plus `password` via the UI button's
    `phx-value-password`, because the NickServ identify + token redirect must run
    on the parent LiveView.

  `CommandDispatch`/`CoreEvents` drive it via `send_update/2`:

  - `{:open, %{target_nick:, registered:}}` — open, clear the password draft
  - `{:password_error, message}`            — show the error, clear the password
  - `:close`                                — hide and reset
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.NickChangeDialog

  @id "nick-change-dialog"

  @doc "Stable DOM/component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       show: false,
       target_nick: "",
       registered: false,
       password: "",
       password_error: nil
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:open, %{target_nick: target, registered: registered}}}, socket) do
    {:ok,
     assign(socket,
       show: true,
       target_nick: target,
       registered: registered,
       password: "",
       password_error: nil
     )}
  end

  def update(%{action: {:password_error, message}}, socket) do
    {:ok, assign(socket, password_error: message, password: "")}
  end

  def update(%{action: :close}, socket) do
    {:ok,
     assign(socket,
       show: false,
       target_nick: "",
       registered: false,
       password: "",
       password_error: nil
     )}
  end

  def update(_assigns, socket), do: {:ok, socket}

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("update_nick_change_password", %{"value" => value}, socket) do
    {:noreply, assign(socket, password: value)}
  end

  def handle_event("nick_change_cancel", _params, socket) do
    {:noreply,
     assign(socket,
       show: false,
       target_nick: "",
       registered: false,
       password: "",
       password_error: nil
     )}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"}>
      <.nick_change_dialog
        id={@id}
        show={@show}
        target_nick={@target_nick}
        registered={@registered}
        password={@password}
        password_error={@password_error}
        on_confirm={
          JS.push("confirm_nick_change", value: %{target: @target_nick, registered: @registered})
        }
        on_cancel={JS.push("nick_change_cancel", target: @myself)}
        on_password_change={JS.push("update_nick_change_password", target: @myself)}
      />
    </div>
    """
  end
end
