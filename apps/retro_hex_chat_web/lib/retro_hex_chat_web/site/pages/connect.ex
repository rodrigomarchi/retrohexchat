defmodule RetroHexChatWeb.Site.Pages.Connect do
  @moduledoc """
  Signing in, at `/connect`: the sign-in window over the chat.

  Everything the desktop asks a visitor to sign in for lands here —
  `?signup=<feature>` names what they tried to use and `?return_to=` where to
  go once signed in — and so does the end of a session: `?reason=` says why
  (expired, ended, banned). The NickServ flow is `RetroHexChatWeb.ConnectForm`, the same
  island on every screen that signs anybody in.
  """
  use RetroHexChatWeb.Site.Page

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  alias RetroHexChatWeb.App.ReturnTo
  alias RetroHexChatWeb.ChatLive.Visitor
  alias RetroHexChatWeb.ConnectForm
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.SEO

  @impl RetroHexChatWeb.Site.Page
  def slot, do: :connect

  @impl RetroHexChatWeb.Site.Page
  def load(params, ctx) do
    reason = reason(params)
    session = Map.get(ctx, :session, %{})

    {:ok,
     %{
       windows: [
         Window.new("connect", dgettext("connect", "Connect to RetroHexChat"), :icon_connect,
           menu: :connect,
           # A form in one column, as narrow on a desktop as on a phone.
           width: 400,
           body: &sign_in/1
         )
       ],
       page_title: dgettext("connect", "Connect - RetroHexChat"),
       canonical_path: "/connect",
       hreflang_alternates: false,
       robots: SEO.noindex_content(),
       reason_message: reason && reason_to_message(reason),
       feature: params["signup"] && Visitor.feature_named(params["signup"]),
       auto_login: is_nil(reason),
       trusted_device_id: session["trusted_device_id"],
       return_to: return_to(params, ctx)
     }}
  end

  @doc "The sign-in window's body: why it opened, then the form — an island of its own."
  @spec sign_in(map()) :: Phoenix.LiveView.Rendered.t()
  def sign_in(assigns) do
    ~H"""
    <div class="space-y-retro-8 p-4" data-testid="connect-window">
      <p
        :if={@reason_message}
        class="flex items-start gap-retro-4 text-xs font-bold text-destructive"
        role="alert"
        data-testid="session-alert"
      >
        <Icons.icon_warning class="h-4 w-4 shrink-0" />
        <span>{@reason_message}</span>
      </p>

      <div :if={@feature} class="space-y-retro-2 text-xs" data-testid="visitor-connect-reason">
        <p class="font-bold" data-feature={@feature}>{Visitor.feature_message(@feature)}</p>
        <p class="text-muted-foreground">
          {dgettext("chat", "Create an account or sign in, and you come back right where you were.")}
        </p>
      </div>

      <.live_component
        module={ConnectForm}
        id={ConnectForm.id()}
        trusted_device_id={@trusted_device_id}
        auto_login={@auto_login}
        csrf_token={Plug.CSRFProtection.get_csrf_token()}
        chat_session_path={~p"/chat/session"}
        return_to={@return_to}
      />
    </div>
    """
  end

  # Where signing in returns to: what the address asked for, or else the
  # conversation the reader was looking at when the window opened.
  defp return_to(%{"return_to" => path}, _ctx) when is_binary(path), do: ReturnTo.sanitize(path)
  defp return_to(_params, ctx), do: Map.get(ctx, :chat_address)

  # Only ever a word: `?reason[a]=b` is not a reason, and the page renders it.
  defp reason(%{"reason" => reason}) when is_binary(reason) and reason != "", do: reason
  defp reason(_params), do: nil

  defp reason_to_message("expired"), do: dgettext("connect", "Session expired")
  defp reason_to_message("disconnected"), do: dgettext("connect", "Session ended")
  defp reason_to_message("banned"), do: dgettext("connect", "Server banned")
  defp reason_to_message(reason), do: reason
end
