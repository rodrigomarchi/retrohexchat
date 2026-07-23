defmodule RetroHexChatWeb.Components.UI.LanguageMenu do
  @moduledoc """
  Shared language menu for app and public menu bars.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ContextMenu
  import RetroHexChatWeb.Components.UI.MenuBar

  alias RetroHexChatWeb.I18n
  alias RetroHexChatWeb.I18n.Locales
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.SEO

  attr :mode, :atom, required: true, values: [:app, :public]
  attr :current_path, :string, default: nil
  attr :return_to, :string, default: nil
  attr :locale, :string, default: nil
  attr :class, :any, default: nil

  @spec language_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def language_menu(assigns) do
    current_locale = I18n.normalize_locale(assigns.locale) || I18n.current_locale()

    assigns =
      assigns
      |> assign(:current_locale, current_locale)
      |> assign(:locales, locale_links(assigns.mode, assigns.current_path, assigns.return_to))

    ~H"""
    <.menu label={dgettext("ui", "Language")} testid="language-menu-trigger" class={@class}>
      <:icon><Icons.icon_globe class="h-4 w-4" /></:icon>
      <.language_menu_items
        mode={@mode}
        current_path={@current_path}
        return_to={@return_to}
        locale={@locale}
      />
    </.menu>
    """
  end

  attr :mode, :atom, required: true, values: [:app, :public]
  attr :current_path, :string, default: nil
  attr :return_to, :string, default: nil
  attr :locale, :string, default: nil

  @spec language_menu_items(map()) :: Phoenix.LiveView.Rendered.t()
  def language_menu_items(assigns) do
    current_locale = I18n.normalize_locale(assigns.locale) || I18n.current_locale()

    assigns =
      assigns
      |> assign(:current_locale, current_locale)
      |> assign(:locales, locale_links(assigns.mode, assigns.current_path, assigns.return_to))

    ~H"""
    <.context_menu_item
      :for={locale <- @locales}
      data-testid={"language-menu-item-#{locale.code}"}
      data-locale={locale.code}
      class={locale.code == @current_locale && "font-bold text-text"}
      aria-current={locale.code == @current_locale && "true"}
    >
      <:icon><Icons.flag_icon locale={locale.code} class="h-[14px] w-[14px]" /></:icon>
      <a
        href={locale.href}
        hreflang={locale.bcp47}
        class="block flex-1"
        aria-current={locale.code == @current_locale && "true"}
      >
        {locale.label}
      </a>
    </.context_menu_item>
    """
  end

  defp locale_links(mode, current_path, return_to) do
    Enum.map(I18n.supported_locales(), fn {code, label} ->
      %{
        code: code,
        label: label,
        bcp47: Locales.bcp47(code),
        href: locale_href(mode, code, current_path, return_to)
      }
    end)
  end

  defp locale_href(:public, code, current_path, _return_to) do
    current_path
    |> normalize_path()
    |> SEO.localized_path(code)
  end

  defp locale_href(:app, code, _current_path, return_to) do
    "/locale/#{code}?return_to=#{URI.encode_www_form(return_to || "/connect")}"
  end

  defp normalize_path(nil), do: "/"
  defp normalize_path(""), do: "/"
  defp normalize_path(path), do: path
end
