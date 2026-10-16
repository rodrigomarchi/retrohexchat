defmodule RetroHexChatWeb.Site.Page do
  @moduledoc """
  A page of the site, as the one desktop shows it: a document window over the
  chat, with an address of its own.

  A page loads what it shows from the route's params (`load/2`) and renders the
  body of its window (`render/1`). What it loads is one map, read three ways:

    * the head of the HTML — `page_title`, `page_description`, `canonical_path`
      and the rest of `RetroHexChatWeb.Site.Head.keys/0`;
    * the window — `window_title` and `window_icon`, defaulting to the page's
      entry in the menus — and `windows`, the sections listed at the top of the
      document, each with its label and icon;
    * whatever else the template reads.

  `slot/0` says which document window a page opens in. Every page of the site
  shares one, the way a browser window shows one page at a time; help, the
  archive, an invite and sign-in each have their own, so reading the help does
  not close the page it was opened from.

  `use RetroHexChatWeb.Site.Page` brings what every page template needs.
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
  @callback render(map()) :: Phoenix.LiveView.Rendered.t()

  defmacro __using__(_opts) do
    quote do
      @behaviour RetroHexChatWeb.Site.Page

      use Phoenix.Component
      use Gettext, backend: RetroHexChatWeb.Gettext

      import RetroHexChatWeb.Components.UI.Site.Document
      import RetroHexChatWeb.Components.UI.Window
      import RetroHexChatWeb.Site.Pages.Helpers

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
