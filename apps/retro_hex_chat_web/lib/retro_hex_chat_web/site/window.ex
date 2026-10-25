defmodule RetroHexChatWeb.Site.Window do
  @moduledoc """
  One window of a page, declared once: what it is called, how it looks, what
  it holds and what its status bar says.

  A page lists its windows in `load/2` (under `:windows`, built with `new/4`),
  in the order they open — the first is the one in front. A page of the site
  opens as a group of them, one per section; help, the archive, an invitation
  and sign-in declare one. Everything else reads that list: the desktop draws
  each window from its entry (`Components.UI.Site.Document`), the window's
  island renders its `body` (`RetroHexChatWeb.Site.WindowBody`), the taskbar
  names it, and the tests check every page against it.

  This is the site's counterpart to `RetroHexChatWeb.ChatLive.WindowRegistry`:
  the title, icon, size and contents of a window live here and nowhere else.
  """

  alias RetroHexChatWeb.Components.UI.Site.Section

  @enforce_keys [:id, :title, :icon, :body]
  defstruct [
    :id,
    :title,
    :icon,
    :body,
    :taskbar_label,
    :menu,
    :meta,
    icon_attrs: %{},
    assigns: %{},
    status: [],
    width: 560,
    height: nil,
    fill: 0.0
  ]

  @typedoc "A field of the status bar: its words, with a check mark before them when tagged."
  @type status_field :: String.t() | {:check, String.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          icon: atom(),
          icon_attrs: map(),
          body: (map() -> Phoenix.LiveView.Rendered.t()),
          assigns: map(),
          status: [status_field()],
          taskbar_label: String.t() | nil,
          menu: :help | nil,
          meta: String.t() | nil,
          width: pos_integer(),
          height: pos_integer() | nil,
          fill: float()
        }

  @doc """
  A window of a page.

  `icon` names a `RetroHexChatWeb.Icons` function. Options:

    * `:body` (required) — the function component that draws what the window
      holds. It is called with what the page loaded, the window's own
      `:assigns` on top, and the window itself as `@window`;
    * `:assigns` — what this window's body needs beyond the page's, when one
      body draws several windows (a group of the mIRC table, say);
    * `:status` — the status bar's fields, the first taking the free width;
    * `:width` (the width the window reads best at), `:height` (nil follows
      the content, up to the desk) and `:fill` (the share of the desk a window
      of its own opens at);
    * `:taskbar_label` — a shorter name for the taskbar when the title is a
      sentence;
    * `:icon_attrs` — what an icon that draws more than one picture needs (a
      game's, its `game_id`);
    * `:menu` and `:meta` — the menus under the title bar and the words after
      the title, for the windows that have them.
  """
  @spec new(String.t(), String.t(), atom(), keyword()) :: t()
  def new(id, title, icon, opts) do
    struct!(__MODULE__, [id: id, title: title, icon: icon] ++ opts)
  end

  @doc """
  The window a page of the site opens with, in front of the rest: the page's
  heading (its `h1`, the window's title, under `:heading_id`) and a paragraph
  on what the page is about (`:description`). Takes `:taskbar_label` and
  `:status` like `new/4`.
  """
  @spec intro(String.t(), atom(), keyword()) :: t()
  def intro(title, icon, opts) do
    {heading_id, opts} = Keyword.pop!(opts, :heading_id)
    {description, opts} = Keyword.pop!(opts, :description)

    new(
      "intro",
      title,
      icon,
      [
        width: 640,
        body: &Section.page_intro/1,
        assigns: %{heading_id: heading_id, description: description}
      ] ++ opts
    )
  end

  @doc "The window declared under `id`; raises when the page never declared it."
  @spec fetch!([t()], String.t()) :: t()
  def fetch!(windows, id) do
    Enum.find(windows, &(&1.id == id)) ||
      raise ArgumentError,
            "no window #{inspect(id)} declared; the page declares #{inspect(Enum.map(windows, & &1.id))}"
  end

  @doc "What the window's body is called with: the page's assigns, the window's own, and the window."
  @spec body_assigns(t(), map()) :: map()
  def body_assigns(%__MODULE__{assigns: own} = window, page_assigns) do
    page_assigns |> Map.merge(own) |> Map.put(:window, window)
  end

  @doc "The window's icon at `class` size (title-bar size by default)."
  @spec icon(t(), String.t()) :: Phoenix.LiveView.Rendered.t()
  def icon(%__MODULE__{icon: icon, icon_attrs: attrs}, class \\ "h-4 w-4") do
    apply(RetroHexChatWeb.Icons, icon, [Map.put(attrs, :class, class)])
  end

  @doc "The name the taskbar gives the window."
  @spec label(t()) :: String.t()
  def label(%__MODULE__{taskbar_label: nil, title: title}), do: title
  def label(%__MODULE__{taskbar_label: label}), do: label
end
