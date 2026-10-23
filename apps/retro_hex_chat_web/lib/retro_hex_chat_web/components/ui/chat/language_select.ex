defmodule RetroHexChatWeb.Components.UI.LanguageSelect do
  @moduledoc """
  The picker for the language something is spoken in — a channel, a bot —
  with the flag it will wear drawn beside it.

  The list is the languages the chat is offered in (`RetroHexChat.Locales`),
  headed by "No language", because a language is set by somebody and absent
  until they do. Every window that sets one draws this, so the flag, the
  empty choice and the list read the same wherever a language is picked.

  It renders the field, not the form: the window around it owns the form and
  what a change sends.

  ## Usage

      <form phx-change="bot_set_locale">
        <.language_select id="bot-language-select" locale={@locale} />
      </form>
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.NickFlag
  import RetroHexChatWeb.Components.UI.Select

  alias RetroHexChat.Locales

  @doc "Renders the language picker with its flag."
  attr :id, :string, required: true
  attr :name, :string, default: "locale"
  attr :locale, :string, default: nil, doc: "the language picked so far, or nil"
  attr :flag, :atom, default: :nick, values: [:nick, :channel], doc: "whose flag it is"
  attr :testid, :string, default: nil, doc: "the select's test id; the id when nil"
  attr :option_testid, :string, default: nil, doc: "each option's test id"

  attr :on_select, :any,
    default: nil,
    doc:
      "an event each option sends with `%{locale: code}`, for a form that is not sent on change"

  @spec language_select(map()) :: Phoenix.LiveView.Rendered.t()
  def language_select(assigns) do
    assigns =
      assigns
      |> assign(:testid, assigns.testid || assigns.id)
      |> assign(:none, label(nil))
      |> assign(:options, [%{code: "", label: nil} | Locales.enabled()])

    ~H"""
    <div class="flex items-center gap-retro-4">
      <.nick_flag :if={@flag == :nick} locale={@locale} />
      <.channel_flag :if={@flag == :channel} locale={@locale} />
      <.select
        :let={builder}
        id={@id}
        name={@name}
        value={@locale || ""}
        default-value=""
        label={label(@locale)}
        placeholder={@none}
        class="w-56"
        data-testid={@testid}
      >
        <.select_trigger builder={builder} class="h-7 text-xs" />
        <.select_content builder={builder}>
          <.select_group>
            <.select_item
              :for={option <- @options}
              builder={builder}
              value={option.code}
              label={option.label || @none}
              on_select={@on_select}
              on_select_value={%{locale: option.code}}
              data-testid={@option_testid}
            >
              {option.label || @none}
            </.select_item>
          </.select_group>
        </.select_content>
      </.select>
    </div>
    """
  end

  @doc "The name of the language `locale` names, in itself, or \"No language\" when it has none."
  @spec label(String.t() | nil) :: String.t()
  def label(locale), do: language(locale) || dgettext("dialogs", "No language")
end
