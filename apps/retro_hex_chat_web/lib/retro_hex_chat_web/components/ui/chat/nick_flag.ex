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

  alias RetroHexChatWeb.I18n.Locales
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.Icons.Registry
  alias RetroHexChatWeb.Icons.Sprite

  attr :locale, :string, default: nil, doc: "the person's locale code, or nil"
  attr :class, :any, default: nil
  attr :rest, :global

  @spec nick_flag(map()) :: Phoenix.LiveView.Rendered.t()
  def nick_flag(assigns) do
    assigns = assign(assigns, :language, language(assigns.locale))

    ~H"""
    <span
      :if={@language}
      class={classes(["rh-nick-flag", @class])}
      title={@language}
      role="img"
      aria-label={@language}
      data-testid="nick-flag"
      data-locale={@locale}
      {@rest}
    >
      <Icons.flag_icon locale={@locale} class="rh-nick-flag__icon" />
    </span>
    """
  end

  @doc "The name of the language `locale` names, in itself, or nil when it has no flag."
  @spec language(String.t() | nil) :: String.t() | nil
  def language(locale) when is_binary(locale) do
    case Locales.find(locale) do
      %{status: :enabled, label: label} -> label
      _none -> nil
    end
  end

  def language(_locale), do: nil

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
