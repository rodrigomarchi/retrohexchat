defmodule RetroHexChatWeb.App.ShareLinkEvents do
  @moduledoc """
  The Share and Revoke buttons of a surface with an address of its own — a
  call, a game, a P2P session, a space.

  Minting is a deliberate act, not a side effect of opening the surface: a
  link per visit would fill the table with addresses nobody ever sent. The
  link is shown through the `share_url`/`share_slug` assigns the surface
  starts with as nil.
  """

  import Phoenix.Component, only: [assign: 2]

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.ShareLinks
  alias RetroHexChatWeb.ShareLinkRef

  @doc """
  Mint a link of `kind` to `target` for whoever is on the socket, and show it.
  `creator` is that person's user id, as `{:ok, id}`; anything else (a visitor
  with no account) mints nothing.
  """
  @spec mint(Socket.t(), String.t(), map(), {:ok, integer()} | term()) :: {:noreply, Socket.t()}
  def mint(socket, kind, target, creator) do
    with {:ok, user_id} <- creator,
         {:ok, link} <-
           ShareLinks.create(%{
             kind: kind,
             target: target,
             creator_id: user_id,
             creator_nick: socket.assigns.nickname
           }) do
      {:noreply, assign(socket, share_url: ShareLinkRef.url(link.slug), share_slug: link.slug)}
    else
      _unavailable -> {:noreply, socket}
    end
  end

  @doc """
  Close the address without closing what it leads to. `ShareLinks` asks its
  own policy who may — the creator, or an operator of the channel the link
  leads into — so a screen that offers the button is not the thing deciding.
  """
  @spec revoke(Socket.t()) :: {:noreply, Socket.t()}
  def revoke(%{assigns: %{share_slug: slug}} = socket) when is_binary(slug) do
    case ShareLinks.revoke(slug, socket.assigns.nickname || "") do
      {:ok, _link} -> {:noreply, assign(socket, share_url: nil, share_slug: nil)}
      _refused -> {:noreply, socket}
    end
  end

  def revoke(socket), do: {:noreply, socket}
end
