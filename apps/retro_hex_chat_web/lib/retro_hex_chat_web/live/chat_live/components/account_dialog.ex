defmodule RetroHexChatWeb.ChatLive.Components.AccountDialog do
  @moduledoc """
  The Account window body: register/identify, drop registration, ghost session.

  Owns the auth form state (`auth_valid`, `auth_password`, `auth_confirm`,
  `error`) and the `ghost_error`. The session-derived display fields
  (`nickname`, `account_state`, `registered`, `identified`) are supplied by the
  parent as template attrs.

  Each form is handled on the parent's `AccountEvents`, which runs the NickServ
  commands and reflects the resulting errors, validity and mode back here via
  `send_update`. Password params are never logged. The NickServ-registration
  snapshot `account_registered` lives on the parent.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.AccountDialog

  @id "account-dialog"

  @doc "Stable component id."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       # passthrough context (session-derived)
       nickname: "",
       account_state: :guest,
       registered: false,
       identified: false,
       # owned UI state
       auth_valid: false,
       auth_password: "",
       auth_confirm: "",
       error: nil,
       ghost_error: nil
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  # Drafts are mirrored back so patches re-render the typed values — inputs in a
  # phx-change form lose unfocused values on any patch otherwise.
  def update(%{action: {:auth, valid?, error, drafts}}, socket) do
    {:ok,
     assign(socket,
       auth_valid: valid?,
       error: error,
       auth_password: drafts.password,
       auth_confirm: drafts.confirm
     )}
  end

  def update(%{action: {:auth_error, message}}, socket) do
    {:ok, assign(socket, auth_valid: false, error: message)}
  end

  def update(%{action: :auth_reset}, socket) do
    {:ok,
     assign(socket,
       error: nil,
       ghost_error: nil,
       auth_valid: false,
       auth_password: "",
       auth_confirm: ""
     )}
  end

  def update(%{action: {:ghost_error, message}}, socket) do
    {:ok, assign(socket, ghost_error: message)}
  end

  def update(assigns, socket) do
    {:ok,
     assign(socket,
       id: Map.get(assigns, :id, socket.assigns.id),
       nickname: Map.get(assigns, :nickname, socket.assigns.nickname),
       account_state: Map.get(assigns, :account_state, socket.assigns.account_state),
       registered: Map.get(assigns, :registered, socket.assigns.registered),
       identified: Map.get(assigns, :identified, socket.assigns.identified)
     )}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.account_panel
        id={@id}
        nickname={@nickname}
        account_state={@account_state}
        registered={@registered}
        identified={@identified}
        auth_valid={@auth_valid}
        auth_password={@auth_password}
        auth_confirm={@auth_confirm}
        error_message={@error}
        ghost_error={@ghost_error}
      />
    </div>
    """
  end
end
