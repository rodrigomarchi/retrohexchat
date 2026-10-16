defmodule RetroHexChatWeb.Site.Pages.Connect do
  @moduledoc """
  Signing in, at `/connect`: the sign-in window over the chat.

  Everything the desktop asks a visitor to sign in for lands here —
  `?signup=<feature>` names what they tried to use and `?return_to=` where to
  go once signed in — and so does the end of a session: `?reason=` says why
  (expired, ended, banned), and a session another screen took over offers
  itself back. The NickServ flow is `RetroHexChatWeb.ConnectForm`, the same
  island on every screen that signs anybody in.
  """
  use RetroHexChatWeb.Site.Page

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Alert

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChatWeb.App.ReturnTo
  alias RetroHexChatWeb.ChatLive.Visitor
  alias RetroHexChatWeb.ConnectForm
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.SEO

  @disconnect_context_ttl_seconds 600

  @impl RetroHexChatWeb.Site.Page
  def slot, do: :connect

  @impl RetroHexChatWeb.Site.Page
  def load(params, ctx) do
    reason = reason(params)
    session = Map.get(ctx, :session, %{})

    {:ok,
     %{
       window_title: dgettext("connect", "Connect to RetroHexChat"),
       window_icon: :icon_connect,
       menu: :connect,
       windows: [],
       page_title: dgettext("connect", "Connect - RetroHexChat"),
       canonical_path: "/connect",
       hreflang_alternates: false,
       robots: SEO.noindex_content(),
       reason_message: reason && reason_to_message(reason),
       feature: params["signup"] && Visitor.feature_named(params["signup"]),
       takeover_session: reason && takeover_session(last_disconnect_context(session)),
       auto_login: is_nil(reason),
       trusted_device_id: session["trusted_device_id"],
       return_to: return_to(params, ctx)
     }}
  end

  @impl RetroHexChatWeb.Site.Page
  def render(assigns) do
    ~H"""
    <div class="p-4" data-testid="connect-window">
      <.alert :if={@reason_message} variant="destructive" class="mb-4" data-testid="session-alert">
        <:icon><Icons.icon_warning /></:icon>
        <.alert_description>{@reason_message}</.alert_description>
      </.alert>

      <div :if={@feature} class="mb-retro-8 space-y-1 text-xs" data-testid="visitor-connect-reason">
        <p class="font-bold" data-feature={@feature}>{Visitor.feature_message(@feature)}</p>
        <p class="text-muted-foreground">
          {dgettext("chat", "Create an account or sign in, and you come back right where you were.")}
        </p>
      </div>

      <.live_component
        module={ConnectForm}
        id={ConnectForm.id()}
        trusted_device_id={@trusted_device_id}
        takeover_session={@takeover_session}
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

  defp last_disconnect_context(%{"last_disconnect_context" => context}) when is_map(context),
    do: context

  defp last_disconnect_context(_session), do: nil

  defp takeover_session(nil), do: nil

  defp takeover_session(context) when is_map(context) do
    session_ref = context_value(context, :session_ref)
    nickname = context_value(context, :nickname)
    recorded_at = context_value(context, :recorded_at)

    if recent_disconnect_context?(recorded_at) do
      TrustedDevices.takeover_session_for_disconnect(session_ref, nickname)
    end
  end

  defp context_value(context, key) do
    Map.get(context, Atom.to_string(key)) || Map.get(context, key)
  end

  defp recent_disconnect_context?(recorded_at) when is_binary(recorded_at) do
    with {:ok, recorded_at, _offset} <- DateTime.from_iso8601(recorded_at),
         :gt <-
           DateTime.compare(
             DateTime.add(recorded_at, @disconnect_context_ttl_seconds, :second),
             DateTime.utc_now()
           ) do
      true
    else
      _ -> false
    end
  end

  defp recent_disconnect_context?(_recorded_at), do: false
end
