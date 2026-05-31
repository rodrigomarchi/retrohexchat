defmodule RetroHexChatWeb.Live.PutLocale do
  @moduledoc """
  Restores the Gettext locale inside LiveView processes.
  """

  import Phoenix.Component, only: [assign: 3]

  alias RetroHexChatWeb.I18n

  @spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(:default, _params, session, socket) do
    locale =
      session
      |> Map.get("locale")
      |> I18n.normalize_locale()
      |> Kernel.||(I18n.default_locale())

    I18n.put_locale(locale)

    {:cont, assign(socket, :locale, locale)}
  end
end
