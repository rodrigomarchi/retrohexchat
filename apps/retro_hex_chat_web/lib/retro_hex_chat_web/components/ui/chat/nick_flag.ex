defmodule RetroHexChatWeb.Components.UI.NickFlag do
  @moduledoc """
  The flag of the language somebody uses the chat in, beside their nickname.

  The language is the one the chat is shown to them in
  (`RetroHexChat.Accounts.NickLocales`), so the flag is the language menu's
  own, and its tooltip names the language in that language. A locale with no
  flag — unknown, or one the chat no longer offers — draws nothing rather than
  a globe: a globe beside one nickname would read as a fact about that person.

  Always beside the nickname, never inside it: the nickname is an address
  (mentions, `data-nick`, the inbox topic) and a flag in the string would
  change who it names.

  ## Usage

      <.nick_flag locale="pt_BR" />
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.Icons.Registry
  alias RetroHexChatWeb.Icons.Sprite

  attr :locale, :string, default: nil, doc: "the person's locale code, or nil"
  attr :class, :any, default: nil
  attr :rest, :global

  @spec nick_flag(map()) :: Phoenix.LiveView.Rendered.t()
  def nick_flag(assigns) do
    ~H"""
    <.flag locale={@locale} class={@class} testid="nick-flag" {@rest} />
    """
  end

  @doc """
  The flag of the language a channel is spoken in, beside the channel's name —
  set by its founder (`/cs language`), and absent until they do.
  """
  attr :locale, :string, default: nil, doc: "the channel's locale code, or nil"
  attr :class, :any, default: nil
  attr :rest, :global

  @spec channel_flag(map()) :: Phoenix.LiveView.Rendered.t()
  def channel_flag(assigns) do
    ~H"""
    <.flag locale={@locale} class={@class} testid="channel-flag" {@rest} />
    """
  end

  attr :locale, :string, default: nil
  attr :class, :any, default: nil
  attr :testid, :string, required: true
  attr :rest, :global

  defp flag(assigns) do
    assigns = assign(assigns, :language, language(assigns.locale))

    ~H"""
    <span
      :if={@language}
      class={classes(["rh-nick-flag", @class])}
      title={@language}
      role="img"
      aria-label={@language}
      data-testid={@testid}
      data-locale={@locale}
      {@rest}
    >
      <Icons.flag_icon locale={@locale} class="rh-nick-flag__icon" />
    </span>
    """
  end

  @doc "The name of the language `locale` names, in itself, or nil when it has no flag."
  @spec language(String.t() | nil) :: String.t() | nil
  defdelegate language(locale), to: RetroHexChat.Locales, as: :label

  @doc """
  What a nickname drawn by the browser needs to draw the same flag
  (`js/lib/nick_flag.js`): the locale, the language's name and the sprite
  reference, so the browser never maps a locale to an icon itself. Nil when
  there is no flag to draw.
  """
  @spec payload(String.t() | nil) ::
          %{locale: String.t(), language: String.t(), href: String.t()} | nil
  def payload(locale) do
    case language(locale) do
      nil -> nil
      language -> %{locale: locale, language: language, href: Sprite.href(Registry.flag(locale))}
    end
  end
end
