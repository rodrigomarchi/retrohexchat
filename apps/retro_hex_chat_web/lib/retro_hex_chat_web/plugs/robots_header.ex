defmodule RetroHexChatWeb.Plugs.RobotsHeader do
  @moduledoc """
  Tells robots, in the response itself, which desktop addresses are not for an
  index: a channel's live conversation (`/c/…`), the sign-in window
  (`/connect`) and an invitation (`/join/…`), under any locale segment.

  The page's own `robots` meta says the same; the header also covers whatever
  reads the response without parsing it, and an address that redirects.
  """
  @behaviour Plug

  import Plug.Conn

  alias RetroHexChatWeb.SEO

  @impl Plug
  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @impl Plug
  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    if private_address?(unlocalized(conn.path_info)),
      do: put_resp_header(conn, "x-robots-tag", SEO.noindex_content()),
      else: conn
  end

  @doc "Whether an unprefixed path is one of the desktop's addresses no index should hold."
  @spec private_address?([String.t()]) :: boolean()
  def private_address?(["c" | _rest]), do: true
  def private_address?(["connect" | _rest]), do: true
  def private_address?(["join" | _rest]), do: true
  def private_address?(_path_info), do: false

  defp unlocalized([segment | rest] = path_info) do
    if SEO.locale_from_segment(segment), do: rest, else: path_info
  end

  defp unlocalized([]), do: []
end
