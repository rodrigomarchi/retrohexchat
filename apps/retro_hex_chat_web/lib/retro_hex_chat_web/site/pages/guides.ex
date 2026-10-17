defmodule RetroHexChatWeb.Site.Pages.Guides do
  @moduledoc """
  What the mIRC and IRC guide pages share: the links from one guide to the
  others, the windows that hold them, and the questions each one answers, translated once for both the
  page and its `FAQPage` structured data.
  """
  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChatWeb.Components.UI.Landing.IrcGuides
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.SEO
  alias RetroHexChatWeb.Site.Window

  @type link :: %{label: String.t(), path: String.t(), icon: atom()}

  @doc """
  The other guides, then the full command help and the games, every path in
  the reader's language.
  """
  @spec links(atom()) :: [link()]
  def links(current) do
    guides =
      for guide <- PublicPages.guides(), guide.page != current do
        %{label: guide.label, path: PublicPages.localized_path(guide.path), icon: guide.icon}
      end

    guides ++
      [
        %{
          label: dgettext("landing", "Every command, explained"),
          path: PublicPages.localized_path("/chat/help/commands-overview"),
          icon: :icon_question
        },
        %{
          label: dgettext("landing", "Games you can play here"),
          path: PublicPages.localized_path("/games"),
          icon: :icon_joystick
        }
      ]
  end

  @doc """
  Translates `{question, answer}` msgid pairs. They are kept as
  `dgettext_noop` in the page and translated here, at render, because a module
  attribute translated at compile time freezes in whichever locale compiled it.
  """
  @spec questions([{String.t(), String.t()}]) :: [{String.t(), String.t()}]
  def questions(entries) do
    Enum.map(entries, fn {question, answer} -> {translate(question), translate(answer)} end)
  end

  @doc "The window that answers a guide's questions, from the page's `questions`."
  @spec questions_window() :: Window.t()
  def questions_window do
    Window.new("questions", dgettext("landing", "Questions"), :icon_question,
      width: 560,
      body: &IrcGuides.guide_questions/1
    )
  end

  @doc "The window that leads to the other guides, from the page's `links`."
  @spec read_next_window() :: Window.t()
  def read_next_window do
    Window.new("read-next", dgettext("landing", "Read next"), :icon_link,
      width: 360,
      body: &IrcGuides.guide_links/1
    )
  end

  @doc "The window of one group of the mIRC parity table."
  @spec parity_window(%{id: String.t(), label: String.t(), rows: [map()]}) :: Window.t()
  def parity_window(group) do
    Window.new(group.id, group.label, :icon_terminal,
      width: 720,
      body: &IrcGuides.parity_table/1,
      assigns: %{rows: group.rows},
      status: [
        dngettext("landing", "%{count} command", "%{count} commands", length(group.rows))
      ]
    )
  end

  @doc "The page's breadcrumb, Home first."
  @spec breadcrumb(atom()) :: String.t()
  def breadcrumb(page) do
    guide = Enum.find(PublicPages.guides(), &(&1.page == page))

    SEO.breadcrumb_json_ld([
      {dgettext("landing", "Home"), PublicPages.localized_path("/")},
      {guide.label, PublicPages.localized_path(guide.path)}
    ])
  end

  defp translate(msgid), do: Gettext.dgettext(RetroHexChatWeb.Gettext, "landing", msgid)
end
