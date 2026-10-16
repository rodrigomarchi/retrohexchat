defmodule RetroHexChatWeb.Live.PutLocale do
  @moduledoc """
  Restores the Gettext locale inside LiveView processes.

  `:default` restores the locale the session carries. `:path` reads it from the
  address instead — the desktop's addresses all carry their locale segment. The
  first render reads the request's own URI; the socket's URI is the socket's
  (`/live/websocket`), so a connected mount reads the page path the client
  sends with its connect params (`page_path`). An unprefixed address is the
  default locale.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [connected?: 1, get_connect_info: 2, get_connect_params: 1]

  alias RetroHexChatWeb.I18n
  alias RetroHexChatWeb.SEO

  @spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(:default, _params, session, socket) do
    locale =
      session
      |> Map.get("locale")
      |> I18n.normalize_locale()
      |> Kernel.||(I18n.default_locale())

    I18n.put_locale(locale)

    {:cont, assign(socket, :locale, locale)}
  end

  def on_mount(:path, _params, _session, socket) do
    locale =
      case connected?(socket) && get_connect_params(socket) do
        %{"page_path" => _} = params -> locale_of_page(params)
        _ -> locale_of(get_connect_info(socket, :uri))
      end

    I18n.put_locale(locale)

    {:cont, assign(socket, :locale, locale)}
  end

  @doc "The locale an address names with its first segment, or the default."
  @spec locale_of(URI.t() | nil) :: String.t()
  def locale_of(%URI{path: "/" <> path}) do
    segment = path |> String.split("/", parts: 2) |> hd()
    SEO.locale_from_segment(segment) || I18n.default_locale()
  end

  def locale_of(_uri), do: I18n.default_locale()

  @doc "The locale of the page a socket's connect params name (`page_path`)."
  @spec locale_of_page(map() | nil) :: String.t()
  def locale_of_page(%{"page_path" => "/" <> _ = path}), do: locale_of(%URI{path: path})
  def locale_of_page(_params), do: I18n.default_locale()
end
