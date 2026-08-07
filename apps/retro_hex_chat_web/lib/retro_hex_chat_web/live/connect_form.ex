defmodule RetroHexChatWeb.ConnectForm do
  @moduledoc """
  Stateful island for the NickServ connect flow.

  Owns the whole nickname → password/register progression, the trusted-terminal
  choices and the remember-terminal fields. The host supplies only what comes
  from the Plug session (`trusted_device_id`), the takeover card and the two
  values the hidden POST form needs; everything else is the island's own.

  Authentication never navigates through LiveView: a successful step fills a
  hidden form and pushes `submit_connect`, and `ConnectFormHook` POSTs it to
  `/chat/session` so the nickname lands in the Plug session. That form and the
  hook both live inside this component, which is what lets the same island run
  on the connect desktop and inside a window on the public landing pages.

  `notify_step` is opt-in because only the connect desktop has a status bar
  reading the current step; landing hosts leave it off and never receive the
  message.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.ConnectFormPanel

  alias RetroHexChat.Accounts.NicknameValidator
  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Services.NickServ

  @id "connect-form"

  @doc "Stable DOM/component id used by the host for send_update/2."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       nickname: "",
       nickname_error: nil,
       password: "",
       password_confirm: "",
       password_error: nil,
       step: :nickname,
       auth_token: nil,
       remembered_nicks: [],
       manual_login: false,
       trusted_device_login: false,
       remember_device: false,
       device_label: "",
       submit_connect: false,
       auto_login_attempted: false,
       trusted_device_id: nil,
       takeover_session: nil,
       auto_login: false,
       notify_step: false
     )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign_context(assigns)
     |> load_remembered_nicks()
     |> maybe_auto_login()}
  end

  defp assign_context(socket, assigns) do
    assign(socket,
      trusted_device_id: Map.get(assigns, :trusted_device_id, socket.assigns.trusted_device_id),
      takeover_session: Map.get(assigns, :takeover_session, socket.assigns.takeover_session),
      csrf_token: Map.get(assigns, :csrf_token, socket.assigns[:csrf_token]),
      chat_session_path: Map.get(assigns, :chat_session_path, socket.assigns[:chat_session_path]),
      auto_login: Map.get(assigns, :auto_login, socket.assigns.auto_login),
      notify_step: Map.get(assigns, :notify_step, socket.assigns.notify_step)
    )
  end

  # The remembered list depends on a host-supplied session value, so it cannot be
  # read in mount/1. Loading it on the first update keeps it inside the same
  # mount patch rather than racing it with a later send_update.
  defp load_remembered_nicks(%{assigns: %{remembered_nicks: [], manual_login: false}} = socket) do
    assign(socket,
      remembered_nicks: TrustedDevices.remembered_nicks(socket.assigns.trusted_device_id)
    )
  end

  defp load_remembered_nicks(socket), do: socket

  @impl true
  def handle_event("connect", %{"nickname" => nickname}, socket) do
    case validate_nickname(nickname) do
      :ok ->
        route_valid_nickname(socket, nickname)

      {:error, msg} ->
        {:noreply, assign(socket, nickname: nickname, nickname_error: msg)}
    end
  end

  def handle_event("connect_remembered", %{"nickname" => nickname}, socket) do
    if TrustedDevices.nick_remembered?(socket.assigns.trusted_device_id, nickname) do
      {:noreply,
       socket
       |> assign(
         nickname: nickname,
         auth_token: nil,
         trusted_device_login: true,
         remember_device: false,
         device_label: "",
         submit_connect: true
       )
       |> push_event("submit_connect", %{})}
    else
      {:noreply, assign(socket, nickname_error: dgettext("connect", "Trusted login expired"))}
    end
  end

  def handle_event(
        "trusted_auto_login_toggle",
        %{"nickname" => nickname, "enabled" => enabled},
        socket
      ) do
    case TrustedDevices.set_auto_login(
           socket.assigns.trusted_device_id,
           nickname,
           truthy?(enabled),
           nickname
         ) do
      :ok ->
        {:noreply,
         assign(socket,
           remembered_nicks: TrustedDevices.remembered_nicks(socket.assigns.trusted_device_id)
         )}

      {:error, message} ->
        {:noreply, assign(socket, nickname_error: message)}
    end
  end

  def handle_event("manual_login", _params, socket) do
    {:noreply,
     assign(socket,
       manual_login: true,
       nickname: "",
       nickname_error: nil,
       trusted_device_login: false,
       auth_token: nil
     )}
  end

  def handle_event("trusted_choices", _params, socket) do
    {:noreply,
     assign(socket,
       manual_login: false,
       nickname: "",
       nickname_error: nil,
       trusted_device_login: false,
       auth_token: nil
     )}
  end

  def handle_event("authenticate", %{"password" => password} = params, socket) do
    nickname = socket.assigns.nickname

    case NickServ.identify(nickname, password) do
      {:ok, _msg} ->
        token = Phoenix.Token.sign(RetroHexChatWeb.Endpoint, "nickserv_identify", nickname)

        {:noreply,
         socket
         |> assign_auth_success(token, params)
         |> push_event("submit_connect", %{})}

      {:error, _msg} ->
        {:noreply,
         socket
         |> assign(password_error: dgettext("connect", "Incorrect password"), password: "")
         |> assign_remember_device_fields(params)}
    end
  end

  def handle_event("register", params, socket) do
    password = Map.get(params, "password", "")
    password_confirm = Map.get(params, "password_confirm", "")
    nickname = socket.assigns.nickname

    cond do
      String.length(password) < 5 ->
        {:noreply,
         socket
         |> assign(
           password: password,
           password_confirm: password_confirm,
           password_error: dgettext("connect", "Password must be at least 5 characters")
         )
         |> assign_remember_device_fields(params)}

      password != password_confirm ->
        {:noreply,
         socket
         |> assign(
           password: password,
           password_confirm: password_confirm,
           password_error: dgettext("connect", "Passwords do not match")
         )
         |> assign_remember_device_fields(params)}

      true ->
        register_nickname(socket, nickname, password, password_confirm, params)
    end
  end

  def handle_event("back", _params, socket) do
    {:noreply,
     socket
     |> assign(
       step: :nickname,
       password: "",
       password_confirm: "",
       password_error: nil
     )
     |> notify_step()}
  end

  defp register_nickname(socket, nickname, password, password_confirm, params) do
    case NickServ.register(nickname, password) do
      {:ok, _msg} ->
        token = Phoenix.Token.sign(RetroHexChatWeb.Endpoint, "nickserv_identify", nickname)

        {:noreply,
         socket
         |> assign_auth_success(token, params)
         |> push_event("submit_connect", %{})}

      {:error, msg} ->
        {:noreply,
         socket
         |> assign(
           password: password,
           password_confirm: password_confirm,
           password_error: msg
         )
         |> assign_remember_device_fields(params)}
    end
  end

  defp validate_nickname(nickname) do
    case NicknameValidator.validate(nickname) do
      :ok -> :ok
      {:error, message} -> {:error, translate_nickname_error(message)}
    end
  end

  defp translate_nickname_error("Nickname must be a string"),
    do: dgettext("connect", "Nickname must be a string")

  defp translate_nickname_error("Nickname cannot be empty"),
    do: dgettext("connect", "Nickname cannot be empty")

  defp translate_nickname_error("Nickname must be at most 16 characters"),
    do: dgettext("connect", "Nickname must be at most 16 characters")

  defp translate_nickname_error("Nickname must start with a letter or special character"),
    do: dgettext("connect", "Nickname must start with a letter or special character")

  defp translate_nickname_error("Nickname cannot contain spaces"),
    do: dgettext("connect", "Nickname cannot contain spaces")

  defp translate_nickname_error(message), do: message

  defp route_valid_nickname(socket, nickname) do
    cond do
      TrustedDevices.nick_remembered?(socket.assigns.trusted_device_id, nickname) ->
        {:noreply,
         socket
         |> assign(
           nickname: nickname,
           nickname_error: nil,
           auth_token: nil,
           trusted_device_login: true,
           remember_device: false,
           device_label: "",
           submit_connect: true
         )
         |> push_event("submit_connect", %{})}

      NickServ.registered?(nickname) ->
        {:noreply,
         socket
         |> assign(
           step: :password,
           nickname: nickname,
           password: "",
           password_error: nil,
           trusted_device_login: false
         )
         |> notify_step()}

      true ->
        {:noreply,
         socket
         |> assign(
           step: :register,
           nickname: nickname,
           password: "",
           password_confirm: "",
           password_error: nil,
           trusted_device_login: false
         )
         |> notify_step()}
    end
  end

  # Auto-login fires once, on the connected mount. The dead render must not push
  # it: the hook is not attached yet and the redirect would be lost.
  defp maybe_auto_login(%{assigns: %{auto_login_attempted: true}} = socket), do: socket
  defp maybe_auto_login(%{assigns: %{auto_login: false}} = socket), do: socket
  defp maybe_auto_login(%{assigns: %{manual_login: true}} = socket), do: socket

  defp maybe_auto_login(socket) do
    if connected?(socket) do
      socket
      |> assign(auto_login_attempted: true)
      |> apply_auto_login(TrustedDevices.auto_login_nick(socket.assigns.trusted_device_id))
    else
      socket
    end
  end

  defp apply_auto_login(socket, %{nickname: nickname}) when is_binary(nickname) do
    socket
    |> assign(
      nickname: nickname,
      nickname_error: nil,
      auth_token: nil,
      trusted_device_login: true,
      remember_device: false,
      device_label: "",
      submit_connect: true
    )
    |> push_event("submit_connect", %{})
  end

  defp apply_auto_login(socket, _auto_login_nick), do: socket

  defp assign_auth_success(socket, token, params) do
    assign(socket,
      auth_token: token,
      trusted_device_login: false,
      remember_device: truthy?(params["remember_device"]),
      device_label: params["device_label"] || "",
      submit_connect: true
    )
  end

  defp assign_remember_device_fields(socket, params) do
    assign(socket,
      remember_device: truthy?(params["remember_device"]),
      device_label: params["device_label"] || ""
    )
  end

  defp truthy?(value), do: value in [true, "true", "on", "1", 1]

  # The connect desktop renders a status bar outside this window, so it needs the
  # step. Landing hosts have no status bar and opt out.
  defp notify_step(%{assigns: %{notify_step: true, step: step}} = socket) do
    send(self(), {:connect_form_step, step})
    socket
  end

  defp notify_step(socket), do: socket

  # A reader with a remembered terminal is one click from being signed in, and
  # that click is lost if it lands before the socket is up. The public pages read
  # this to load their LiveSocket during render instead of on first touch. It is
  # also what makes auto-login work there: it needs a connected socket to push
  # submit_connect, and nothing else on a landing page would open one.
  #
  # Everyone else — first-time readers, crawlers — stays on the lazy path.
  defp eager_boot?(assigns), do: assigns.remembered_nicks != []

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :eager_boot, eager_boot?(assigns))

    ~H"""
    <div
      id={@id}
      phx-hook="ConnectFormHook"
      class="contents"
      data-connect-eager={to_string(@eager_boot)}
    >
      <.connect_form_panel
        step={@step}
        nickname={@nickname}
        nickname_error={@nickname_error}
        password={@password}
        password_confirm={@password_confirm}
        password_error={@password_error}
        auth_token={@auth_token}
        remembered_nicks={@remembered_nicks}
        takeover_session={@takeover_session}
        manual_login={@manual_login}
        trusted_device_login={@trusted_device_login}
        remember_device={@remember_device}
        device_label={@device_label}
        csrf_token={@csrf_token}
        chat_session_path={@chat_session_path}
        target={@myself}
      />
    </div>
    """
  end
end
