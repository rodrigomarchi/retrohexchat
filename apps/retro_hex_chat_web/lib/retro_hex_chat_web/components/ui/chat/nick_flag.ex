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

  alias RetroHexChat.Channels.Categories
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

  @doc """
  The plaque of what a channel is about — news, games, sport — set by its
  founder (`/cs category`), and absent until they do. Its tooltip names the
  category in the reader's language.
  """
  attr :category, :string, default: nil, doc: "one of RetroHexChat.Channels.Categories, or nil"
  attr :class, :any, default: nil
  attr :rest, :global

  @spec channel_category(map()) :: Phoenix.LiveView.Rendered.t()
  def channel_category(assigns) do
    assigns =
      assign(
        assigns,
        :label,
        Registry.category(assigns.category) && Categories.label(assigns.category)
      )

    ~H"""
    <span
      :if={@label}
      class={classes(["rh-nick-flag", @class])}
      title={@label}
      role="img"
      aria-label={@label}
      data-testid="channel-category"
      data-category={@category}
      {@rest}
    >
      <Icons.category_icon category={@category} class="rh-nick-flag__icon" />
    </span>
    """
  end

  @doc """
  Both of a channel's badges, in the order they are read beside its name:
  what it is about, then the language it is spoken in. Each is drawn only
  when its founder set it.
  """
  attr :category, :string, default: nil
  attr :locale, :string, default: nil
  attr :class, :any, default: nil, doc: "classes for each badge"

  @spec channel_badges(map()) :: Phoenix.LiveView.Rendered.t()
  def channel_badges(assigns) do
    ~H"""
    <.channel_category category={@category} class={@class} /><.channel_flag
      locale={@locale}
      class={@class}
    />
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
