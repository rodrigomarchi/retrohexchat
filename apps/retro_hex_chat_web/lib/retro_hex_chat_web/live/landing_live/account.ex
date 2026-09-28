defmodule RetroHexChatWeb.LandingLive.Account do
  @moduledoc """
  The two pages an e-mail link lands on: confirming an address, and choosing a
  new password.

  On the landing pipeline rather than the app's, for the same reason a shared
  link is: whoever follows one of these may have no session at all, and finding
  out what the link was for must not cost them the whole application bundle.

  Both routes exist under every locale segment. A public first segment that is
  registered only unprefixed is how `/pt-BR/join/:slug` once became a router
  error instead of a page.
  """
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.Alert
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Label
  import RetroHexChatWeb.Components.UI.Landing.LandingShell, only: [landing_layout: 1]
  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChat.Services.NickEmail
  alias RetroHexChatWeb.Icons

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(%{"token" => token}, _session, socket) do
    {:ok,
     socket
     |> assign(
       active_page: :account,
       trusted_device_id: nil,
       canonical_path: nil,
       password: "",
       error: nil,
       link_dead: false,
       done: false,
       checking: false,
       windows: [
         %{id: "account-link", label: window_label(socket), icon: :icon_lock}
       ]
     )
     |> apply_action(socket.assigns.live_action, token)}
  end

  # Only once connected. A LiveView mounts twice — the static render, then the
  # socket — and a token is single-use: spending it on the first pass means the
  # second finds it gone and every person confirming an address sees the link
  # fail. The static pass says nothing and waits.
  defp apply_action(socket, action, token) do
    if connected?(socket) do
      act(socket, action, token)
    else
      assign(socket, token: token, nickname: nil, checking: true)
    end
  end

  # Confirming is not a form: the link itself is the whole act, so following it
  # is what confirms. Choosing a password is, so that one waits for a submit.
  defp act(socket, :verify, token) do
    case NickEmail.verify_email(token) do
      {:ok, nickname} ->
        assign(socket, done: true, nickname: nickname, token: nil, checking: false)

      {:error, reason} ->
        assign(socket,
          error: link_error(reason),
          link_dead: true,
          token: nil,
          nickname: nil,
          checking: false
        )
    end
  end

  # Checked without being spent. A form that the submit is going to refuse is
  # worse than saying up front that the link is dead.
  defp act(socket, :reset, token) do
    if NickEmail.reset_token_valid?(token) do
      assign(socket, token: token, nickname: nil, checking: false)
    else
      assign(socket,
        error: link_error(:invalid),
        link_dead: true,
        token: nil,
        nickname: nil,
        checking: false
      )
    end
  end

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("reset", %{"password" => password}, socket) do
    case NickEmail.reset_password(socket.assigns.token, password) do
      :ok ->
        {:noreply, assign(socket, done: true, error: nil, password: "")}

      {:error, reason} when reason in [:expired, :invalid] ->
        {:noreply, assign(socket, error: link_error(reason), link_dead: true, password: "")}

      {:error, message} ->
        {:noreply, assign(socket, error: message, password: password)}
    end
  end

  defp link_error(:expired) do
    dgettext(
      "landing",
      "This link has expired. Ask for a new one and it will work for a day."
    )
  end

  defp link_error(_reason) do
    dgettext(
      "landing",
      "This link is no longer good. It may have been used already, or replaced by a newer one."
    )
  end

  defp window_label(socket) do
    case socket.assigns[:live_action] do
      :reset -> dgettext("landing", "Choose a new password")
      _verify -> dgettext("landing", "Confirm your address")
    end
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <.landing_layout active_page={@active_page} windows={@windows}>
      <%!-- This page has nothing to show until LiveView is driving it: the token
            is spent on the connected mount, and the reset form is a `phx-submit`.
            The public bundle keeps its socket shut until a reader reaches for the
            sign-in window, and there is no sign-in window here to reach for. --%>
      <section class="m-4" aria-labelledby="account-heading" data-live-boot="true">
        <%!-- One window, and it is the one that acts. A second window explaining
              the first would land on top of it — the desk cascades what it is
              given — and the control this page exists for would be behind the
              explanation of why it exists. --%>
        <.desktop_window
          id="account-link"
          width={460}
          default_centered
          title={window_label(%{assigns: assigns})}
        >
          <:icon><Icons.icon_lock class="w-4 h-4" /></:icon>

          <h1 id="account-heading" class="text-lg font-bold mb-2 text-text">
            {window_label(%{assigns: assigns})}
          </h1>
          <p class="text-sm mb-3">
            {dgettext(
              "landing",
              "An address on a nickname is optional, private, and the only way back in when a password is gone."
            )}
          </p>

          <.alert :if={@error} class="mb-3" data-testid="account-error">
            <:icon><Icons.icon_reject /></:icon>
            <.alert_description>{@error}</.alert_description>
          </.alert>

          <p :if={@checking} class="text-sm" data-testid="account-checking">
            {dgettext("landing", "Checking this link…")}
          </p>

          <.account_outcome :if={@done and @live_action == :verify} />
          <.account_reset_done :if={@done and @live_action == :reset} />

          <.account_reset_form
            :if={@live_action == :reset and not @done and not @checking and not @link_dead}
            password={@password}
          />

          <:status>
            <.window_status_bar_field grow>
              {dgettext("landing", "Account")}
            </.window_status_bar_field>
          </:status>
        </.desktop_window>
      </section>
    </.landing_layout>
    """
  end

  defp account_outcome(assigns) do
    ~H"""
    <div data-testid="account-verified">
      <p class="text-sm">
        {dgettext(
          "landing",
          "Your address is confirmed. It stays private, and you can remove it at any time from the Account window in the chat."
        )}
      </p>
      <div class="mt-4 flex justify-end">
        <.button navigate="/connect" data-testid="account-to-connect">
          <:icon><Icons.icon_connect /></:icon>
          {dgettext("landing", "Go to Connect")}
        </.button>
      </div>
    </div>
    """
  end

  defp account_reset_done(assigns) do
    ~H"""
    <div data-testid="account-reset-done">
      <p class="text-sm">
        {dgettext("landing", "Your password has been changed. You can sign in with it now.")}
      </p>
      <div class="mt-4 flex justify-end">
        <.button navigate="/connect" data-testid="account-to-connect">
          <:icon><Icons.icon_connect /></:icon>
          {dgettext("landing", "Go to Connect")}
        </.button>
      </div>
    </div>
    """
  end

  attr :password, :string, required: true

  defp account_reset_form(assigns) do
    ~H"""
    <form phx-submit="reset" autocomplete="off" data-testid="account-reset-form">
      <.label for="password">{dgettext("landing", "New password")}</.label>
      <.input
        type="password"
        id="password"
        name="password"
        value={@password}
        autocomplete="new-password"
        data-testid="account-reset-password"
      />
      <div class="mt-4 flex justify-end">
        <.button type="submit" data-testid="account-reset-submit">
          <:icon><Icons.icon_lock /></:icon>
          {dgettext("landing", "Change password")}
        </.button>
      </div>
    </form>
    """
  end
end
