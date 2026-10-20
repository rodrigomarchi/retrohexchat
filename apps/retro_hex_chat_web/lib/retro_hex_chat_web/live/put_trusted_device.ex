defmodule RetroHexChatWeb.Live.PutTrustedDevice do
  @moduledoc """
  Carries the trusted-device id from the Plug session into a LiveView.

  The connect window's list of remembered nicknames keys off this id, and so
  does Trusted Terminals. Assigning it once here keeps every LiveView that
  needs it from repeating the same session read.

  A visitor without the cookie gets `nil`, which every `TrustedDevices` lookup
  short-circuits — so a crawler never reaches the database for it.
  """

  import Phoenix.Component, only: [assign: 3]

  @spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(:default, _params, session, socket) do
    {:cont, assign(socket, :trusted_device_id, session["trusted_device_id"])}
  end
end
