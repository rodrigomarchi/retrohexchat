defmodule RetroHexChatWeb.Site.Page do
  @moduledoc """
  A page of the site, as the one desktop shows it: windows over the chat, with
  an address of their own.

  A page loads what it shows from the route's params (`load/2`) into one map,
  read two ways:

    * the head of the HTML — `page_title`, `page_description`, `canonical_path`
      and the rest of `RetroHexChatWeb.Site.Head.keys/0`;
    * the windows — `windows`, one `RetroHexChatWeb.Site.Window` per window,
      the first in front. Each declares its title, icon, size, status bar and
      the function component that draws its body, which the window's island
      (`RetroHexChatWeb.Site.WindowBody`) calls with the rest of the map.

  `slot/0` says where a page opens. Every page of the site shares the `:site`
  slot, the way a browser shows one page at a time, and opens as a group of
  windows, one per section; help, the archive, an invitation and sign-in each
  have a window of their own, so reading the help does not close the page it
  was opened from.

  `use RetroHexChatWeb.Site.Page` brings what every page and its bodies need.
  """

  @type slot :: :site | :help | :archive | :join | :connect

  @typedoc "What the desktop knows about the reader a page is loaded for."
  @type ctx :: %{
          required(:locale) => String.t(),
          required(:visitor?) => boolean(),
          optional(atom()) => term()
        }

  @callback slot() :: slot()
  @callback load(params :: map(), ctx()) :: {:ok, map()} | {:redirect, String.t()} | :not_found

  defmacro __using__(_opts) do
    quote do
      @behaviour RetroHexChatWeb.Site.Page

      use Phoenix.Component
      use Gettext, backend: RetroHexChatWeb.Gettext

      import RetroHexChatWeb.Components.UI.Landing.LandingMockups, except: [readme_text: 1]
      import RetroHexChatWeb.Components.UI.Site.Section

      alias RetroHexChatWeb.Site.Window

      @impl RetroHexChatWeb.Site.Page
      def slot, do: :site

      defoverridable slot: 0
    end
  end

  defmodule NotFoundError do
    @moduledoc "An address that names no page — an unknown game, a day the archive does not publish: a real 404."
    defexception message: "no such page", plug_status: 404
  end
end
