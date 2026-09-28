defmodule RetroHexChatWeb.ChatLive.OpenTabEvents do
  @moduledoc """
  The gate between a click on a door and a second browser tab.

  `OpenTabConfirmHook` holds the click and pushes where it was going; this turns
  that into the dialog's pending target. The hook decided *which* anchors are
  gated and what kind of destination each one is — it has the DOM and the
  browser's own URL parser — and this decides only whether the address may be
  rendered into an `href` at all.

  That refusal is the reason this module exists rather than the component taking
  the payload straight. The payload comes from the client, and the dialog draws
  an anchor from it: a `javascript:` URL arriving here and being drawn there
  would reopen exactly the hole `URLDetector`'s `https?://`-only pattern and the
  Markdown sanitiser close. It is self-inflicted only — nothing but a message can
  put a link in front of somebody else, and a message yields no other scheme —
  but a sink that is safe only because of who can reach it is a sink waiting for
  its reach to change.

  What passes: `http`, `https`, and a path of our own. A refusal opens no dialog
  and says nothing; there is no sentence a reader could act on, and a screen that
  announces "that link was malformed" about markup it did not write is noise.
  """

  import Phoenix.LiveView, only: [send_update: 2]

  require Logger

  alias Phoenix.LiveView.Socket
  alias RetroHexChatWeb.ChatLive.Components.OpenTabConfirmDialog
  alias RetroHexChatWeb.SEO

  @type event_result :: {:cont, Socket.t()} | {:halt, Socket.t()}

  @schemes ~w(http https)

  @spec handle_event(String.t(), map(), Socket.t()) :: event_result()
  def handle_event("confirm_open_tab", params, socket) do
    case target(params) do
      nil ->
        Logger.debug("ChatLive: refused a confirm_open_tab target #{inspect(params["url"])}")
        {:halt, socket}

      target ->
        send_update(OpenTabConfirmDialog, id: OpenTabConfirmDialog.id(), action: {:set, target})
        {:halt, socket}
    end
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc """
  Raise the same question about a URL the server already holds.

  The right-click menu's **Open Link** arrives as an event rather than as a click
  on an anchor, so it never meets the hook. It meets this instead, and the reader
  gets the one dialog rather than a second spelling of it. The host is resolved
  here because the address is all there is to go on — the DOM that would have
  said more is not in the picture.

  A URL that cannot be opened is dropped exactly as the hook's path drops one:
  the menu item closes and nothing else happens.
  """
  @spec confirm(Socket.t(), String.t()) :: Socket.t()
  def confirm(socket, url) when is_binary(url) do
    if openable?(url) do
      send_update(OpenTabConfirmDialog,
        id: OpenTabConfirmDialog.id(),
        action: {:set, %{url: url, kind: kind_for(url), label: nil, host: host(url)}}
      )
    end

    socket
  end

  def confirm(socket, _url), do: socket

  # Ours or not, decided on the parsed host and never on a prefix:
  # `retrohexchat.app.evil.example` begins with our name and is not us. A path
  # with no host at all was typed against this site and is ours by construction.
  @spec kind_for(String.t()) :: atom()
  defp kind_for(url), do: if(host(url), do: :external, else: :surface)

  @spec host(String.t()) :: String.t() | nil
  defp host(url) do
    with %URI{host: host} when is_binary(host) and host != "" <- URI.parse(url),
         %URI{host: own} <- URI.parse(SEO.origin()),
         true <- host != own do
      host
    else
      _ours_or_pathless -> nil
    end
  end

  @spec target(map()) :: map() | nil
  defp target(%{"url" => url} = params) when is_binary(url) do
    if openable?(url) do
      %{
        url: url,
        kind: kind(params["kind"]),
        label: presence(params["label"]),
        host: presence(params["host"]),
        event: presence(params["event"]),
        params: event_params(params["params"])
      }
    end
  end

  defp target(_params), do: nil

  # A path of ours carries no scheme and no host, so it is ours by construction —
  # `//evil.example` is the exception that looks like one, and `URI.parse/1`
  # reports it as a host with no scheme, which is why the host is checked too.
  @spec openable?(String.t()) :: boolean()
  defp openable?(url) do
    case URI.parse(url) do
      %URI{scheme: nil, host: nil, path: "/" <> _rest} -> true
      %URI{scheme: scheme, host: host} when is_binary(host) and host != "" -> scheme in @schemes
      _otherwise -> false
    end
  end

  # Spelled out rather than resolved with `String.to_existing_atom/1`: the atom
  # only exists once some module that mentions it has been loaded, so that
  # version works right up until the component happens not to be loaded yet.
  @spec kind(term()) :: atom()
  defp kind("attachment"), do: :attachment
  defp kind("external"), do: :external
  defp kind(_surface_or_unknown), do: :surface

  # Only a flat map of strings, which is every shape a `phx-value-*` could have
  # had. A nested payload would be a template asking for something this path is
  # not, and dropping it is quieter than guessing at it.
  @spec event_params(term()) :: map()
  defp event_params(params) when is_map(params) do
    for {key, value} <- params,
        is_binary(key) and (is_binary(value) or is_number(value) or is_boolean(value)),
        into: %{},
        do: {key, value}
  end

  defp event_params(_params), do: %{}

  @spec presence(term()) :: String.t() | nil
  defp presence(value) when is_binary(value) and value != "", do: value
  defp presence(_value), do: nil
end
