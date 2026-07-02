defmodule RetroHexChatWeb.ChatLive.Components.AccountDialog do
  @moduledoc """
  The Account dialog: register/login, profile, presence and user-mode tabs.

  Owns the dialog's editable state — the active `tab`, the auth form (`auth_mode`,
  `auth_valid`, `error`), the nickname-change `nick_error`, the bio editor
  (`bio_draft`, `bio_warning`) and the `ghost_error`. The session-derived display
  fields (`nickname`, `account_state`, `registered`, `identified`, `away`,
  `away_message`, `wallops_enabled`, current `bio`) are supplied by the parent as
  template attrs. The island lives inside the managed `account` desktop window;
  every opener re-seeds tab, auth mode and bio via the `{:open, ...}` directive.

  Each form (`account_register_submit`, `account_auth_change`,
  `account_profile_change`, `account_change_nick_submit`, ...) is handled on the
  parent's `AccountEvents`, which runs the NickServ / profile / presence commands
  and reflects the resulting errors, auth mode, validity and bio draft back here
  via `send_update`. Password params are never logged. The NickServ-registration
  snapshot `account_registered` and the remembered `account_last_away_message`
  (read by the status-bar away toggle) live on the parent.
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
       away: false,
       away_message: "",
       wallops_enabled: false,
       # owned UI state
       tab: "register",
       auth_mode: "register",
       auth_valid: false,
       auth_password: "",
       auth_confirm: "",
       error: nil,
       nick_error: nil,
       bio_draft: "",
       bio_warning: nil,
       ghost_error: nil
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:open, tab, auth_mode, bio}}, socket) do
    {:ok,
     assign(socket,
       tab: tab,
       auth_mode: auth_mode,
       bio_draft: bio,
       error: nil,
       auth_valid: false,
       auth_password: "",
       auth_confirm: "",
       nick_error: nil,
       bio_warning: nil,
       ghost_error: nil
     )}
  end

  # Drafts are mirrored back so patches re-render the typed values — inputs in a
  # phx-change form lose unfocused values on any patch otherwise.
  def update(%{action: {:auth, mode, valid?, error, drafts}}, socket) do
    {:ok,
     assign(socket,
       auth_mode: mode,
       auth_valid: valid?,
       error: error,
       auth_password: drafts.password,
       auth_confirm: drafts.confirm
     )}
  end

  def update(%{action: {:auth_error, mode, message}}, socket) do
    {:ok, assign(socket, auth_mode: mode, auth_valid: false, error: message)}
  end

  def update(%{action: {:auth_reset, mode}}, socket) do
    {:ok,
     assign(socket,
       auth_mode: mode,
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
       account_state: Map.get(assigns, :account_state, socket.assigns.account_state),
       registered: Map.get(assigns, :registered, socket.assigns.registered),
       identified: Map.get(assigns, :identified, socket.assigns.identified),
       away: Map.get(assigns, :away, socket.assigns.away),
       away_message: Map.get(assigns, :away_message, socket.assigns.away_message),
       wallops_enabled: Map.get(assigns, :wallops_enabled, socket.assigns.wallops_enabled)
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
        active_tab={@tab}
        auth_mode={@auth_mode}
        auth_valid={@auth_valid}
        auth_password={@auth_password}
        auth_confirm={@auth_confirm}
        bio={@bio_draft || ""}
        bio_warning={@bio_warning}
        nick_error={@nick_error}
        away={@away}
        away_message={@away_message || ""}
        wallops_enabled={@wallops_enabled}
        error_message={@error}
        ghost_error={@ghost_error}
      />
    </div>
    """
  end
end
