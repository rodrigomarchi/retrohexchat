defmodule RetroHexChatWeb.Layouts do
  @moduledoc """
  Layout components for RetroHexChat.
  """
  use RetroHexChatWeb, :html

  alias RetroHexChatWeb.Icons.Sprite
  alias RetroHexChatWeb.Wallpaper

  embed_templates "layouts/*"

  @doc """
  The metas every full page carries after its charset: viewport, CSRF token,
  the analytics id and browser telemetry switches, and the
  `traceparent` that joins the page-load trace to the server's.
  """
  @spec head_meta(map()) :: Phoenix.LiveView.Rendered.t()
  def head_meta(assigns) do
    ~H"""
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="csrf-token" content={get_csrf_token()} />
    <%= if measurement_id = Application.get_env(:retro_hex_chat_web, :ga_measurement_id) do %>
      <meta name="ga-measurement-id" content={measurement_id} />
    <% end %>
    <meta
      name="faro-enabled"
      content={to_string(Application.get_env(:retro_hex_chat_web, :faro_enabled, false))}
    />
    <meta
      name="faro-collector-url"
      content={Application.get_env(:retro_hex_chat_web, :faro_collector_url, "/faro/collect")}
    />
    <meta name="faro-app-version" content={RetroHexChatWeb.BuildInfo.version()} />
    <%!-- Faro's tracing instrumentation adopts this as the parent of the
          page-load trace, so the browser's spans and the server's land in one
          trace instead of two that never reference each other. --%>
    <%= if traceparent = RetroHexChatWeb.TraceContext.traceparent() do %>
      <meta name="traceparent" content={traceparent} />
    <% end %>
    """
  end

  @doc """
  What makes a page installable and recognisable in a tab: the manifest, the
  theme colour the OS paints around an installed window (it has no chrome of
  its own), and the icons.
  """
  @spec app_icons(map()) :: Phoenix.LiveView.Rendered.t()
  def app_icons(assigns) do
    ~H"""
    <link rel="manifest" href={~p"/manifest.webmanifest"} />
    <meta name="theme-color" content="#000080" />
    <link rel="apple-touch-icon" href={~p"/images/app_icon_192.png"} />
    <link rel="icon" type="image/svg+xml" href={~p"/images/favicon.svg"} />
    <link rel="icon" type="image/x-icon" href={~p"/favicon.ico"} />
    """
  end

  @doc """
  The `<head>` links every surface shares, in the order the browser should act on them.

  Three of these earn their place by what they *don't* do. The icon sprite is not
  discoverable until the parser reaches the first `<use>`, deep in the body, so
  it is announced here and downloads alongside the stylesheet. The desktop
  wallpaper is worse off still — nothing refers to it until the stylesheet has
  been fetched and parsed — and on a desk it is the largest thing painted, so it
  is announced too. And the web font arrives as `media="print"`, which the
  browser fetches without letting it hold up the first paint; the `onload`
  promotes it once it is there.

  Only the wide wallpaper is preloaded. On a phone the window manager stacks,
  and the window on top covers the desk entirely — the art behind it is never
  the largest paint and rarely seen at all, so it is left to load whenever CSS
  gets round to asking for it rather than competing on a phone's connection.

  The sprite preload makes Chrome log "preloaded using link preload but not used
  within a few seconds", on every page, and no `as` value silences it: an
  external `<use>` reference does not consume link preloads at all, so the
  browser never credits this one no matter which destination it declares
  (`image`, `fetch`, with or without `crossorigin` — all measured, all warn).

  The warning is bookkeeping, not waste. Measured against production, the sprite
  crosses the wire exactly once: the preload transfers it and the `<use>` that
  follows is a cache hit. Dropping the preload does silence the warning, and
  costs the early start it was added for — on a channel's address especially,
  where the disconnected render is only the chat opening and most `<use>`s do
  not exist until LiveView has connected. So it stays, and the console line is
  expected.
  """
  @spec head_assets(map()) :: Phoenix.LiveView.Rendered.t()
  def head_assets(assigns) do
    ~H"""
    <link rel="preload" as="image" type="image/svg+xml" href={Sprite.url()} />
    <link
      rel="preload"
      as="image"
      type="image/webp"
      href={Wallpaper.desktop_url()}
      media="(min-width: 768px)"
    />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link
      href="https://fonts.googleapis.com/css2?family=Source+Code+Pro:wght@400;500;700&display=swap"
      rel="stylesheet"
      media="print"
      onload="this.media='all'"
    />
    <noscript>
      <link
        href="https://fonts.googleapis.com/css2?family=Source+Code+Pro:wght@400;500;700&display=swap"
        rel="stylesheet"
      />
    </noscript>
    """
  end

  @doc """
  Renders the app layout.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <.flash_group flash={@flash} />
    {render_slot(@inner_block)}
    """
  end

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          JS.show(to: ".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: "#client-error")
        }
        phx-connected={
          JS.hide(to: "#client-error") |> JS.set_attribute({"hidden", ""}, to: "#client-error")
        }
        hidden
      >
        {gettext("Attempting to reconnect")}
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          JS.show(to: ".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: "#server-error")
        }
        phx-connected={
          JS.hide(to: "#server-error") |> JS.set_attribute({"hidden", ""}, to: "#server-error")
        }
        hidden
      >
        {gettext("Attempting to reconnect")}
      </.flash>
    </div>
    """
  end
end
