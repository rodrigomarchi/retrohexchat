defmodule RetroHexChatWeb.Site.Address do
  @moduledoc """
  The address of what the chat is showing, so the URL can follow it.

  A channel is `/c/<name>`, in the reader's language; anything else — the
  status window, a private conversation, a member who has not opened a channel
  — is the desktop's home. A private conversation never gets an address: a
  URL is something people copy, and who somebody talks to privately is not.
  """

  import Phoenix.LiveView, only: [connected?: 1, push_patch: 2]

  alias RetroHexChat.Channels.Server
  alias RetroHexChatWeb.I18n
  alias RetroHexChatWeb.SEO

  @doc "A channel's path, unprefixed: `#retro` → `/c/retro`."
  @spec channel_path(String.t()) :: String.t()
  def channel_path("#" <> name), do: "/c/" <> URI.encode(name, &URI.char_unreserved?/1)
  def channel_path(name) when is_binary(name), do: channel_path("#" <> name)

  @doc "The channel a `/c/:channel` param names."
  @spec channel_name(String.t()) :: String.t()
  def channel_name("#" <> _rest = name), do: name
  def channel_name(name) when is_binary(name), do: "#" <> name

  @doc "The address of the conversation on screen, in the current locale."
  @spec chat_address(map()) :: String.t()
  def chat_address(assigns), do: assigns |> chat_path() |> localized()

  @doc "The address of the conversation on screen, unprefixed."
  @spec chat_path(map()) :: String.t()
  def chat_path(%{session: %{active_pm: pm}, show_status_tab: false})
      when is_binary(pm) and pm != "",
      do: "/"

  def chat_path(%{session: %{active_channel: channel}, show_status_tab: false})
      when is_binary(channel) and channel != "",
      do: channel_path(channel)

  def chat_path(_assigns), do: "/"

  @doc """
  Asks for the address bar to follow the chat once the work in hand is done.

  A conversation can change in front of the reader and change back within one
  message — the perform list joins a channel and puts the reader's own back in
  front — so the address is not decided here: the process sends itself
  `:sync_address`, read after the current message by `follow/1`, which sees
  the conversation that ended up in front.
  """
  @spec sync(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def sync(socket) do
    if connected?(socket), do: send(self(), {__MODULE__, :sync_address})
    socket
  end

  @doc """
  Makes the address bar follow the chat: replaced, not pushed, because
  switching channels is not a place to go back to. Nothing happens before the
  desktop has read its first address, or while a page of the site is the
  window in front.
  """
  @spec follow(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def follow(socket) do
    assigns = socket.assigns
    address = chat_address(assigns)

    if assigns[:address_ready?] == true and assigns[:focused_doc] == nil and
         address != assigns[:current_address] and not home_conversation?(assigns) do
      push_patch(socket, to: address, replace: true)
    else
      socket
    end
  end

  @doc """
  Whether the address bar is at the home and the chat shows the conversation
  the home opens with — a visitor's default channel. The home is that
  channel's address too, so the bar stays where the reader came in.
  """
  @spec home_conversation?(map()) :: boolean()
  def home_conversation?(assigns) do
    assigns[:visitor?] == true and assigns[:current_address] in home_paths() and
      chat_path(assigns) == channel_path(Server.default_channel())
  end

  @doc "The home's address in every locale: `/`, `/pt-BR`, …"
  @spec home_paths() :: [String.t()]
  def home_paths, do: ["/" | Enum.map(SEO.localized_locale_segments(), &("/" <> &1))]

  @doc "`path` in the current locale."
  @spec localized(String.t()) :: String.t()
  def localized(path), do: SEO.localized_path(path, I18n.current_locale())
end
