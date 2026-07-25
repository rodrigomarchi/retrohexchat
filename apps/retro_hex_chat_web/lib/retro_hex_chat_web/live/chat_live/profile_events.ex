defmodule RetroHexChatWeb.ChatLive.ProfileEvents do
  @moduledoc """
  Handle the Profile window: nickname change and the `/whois` bio.

  The nickname change runs `/nick` and reflects a validation failure back into
  the window instead of the chat surface; the bio editor normalizes the draft to
  200 graphemes here so the warning is inline.

  Attached as `attach_hook(:profile_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.LiveView, only: [send_update: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.{NicknameValidator, Session}
  alias RetroHexChatWeb.ChatLive.CommandDispatch
  alias RetroHexChatWeb.ChatLive.Components.ProfileDialog
  alias RetroHexChatWeb.ChatLive.Windows

  @max_bio_graphemes 200

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}

  def handle_event("open_profile_dialog", _params, socket) do
    {:halt, open(socket)}
  end

  def handle_event("profile_change_nick_submit", %{"nickname" => nickname}, socket) do
    nickname = String.trim(nickname)

    case validate_nickname_change(socket.assigns.session.nickname, nickname) do
      :ok ->
        {socket, result} =
          CommandDispatch.dispatch_command_with_result(
            socket,
            socket.assigns.session,
            "nick",
            [nickname]
          )

        case result do
          {:error, message} -> {:halt, nick_error(socket, message)}
          _result -> {:halt, nick_error(socket, nil)}
        end

      {:error, message} ->
        {:halt, nick_error(socket, message)}
    end
  end

  def handle_event("profile_bio_change", %{"bio" => bio}, socket) do
    {draft, warning} = normalize_bio_draft(bio)
    send_update(ProfileDialog, id: ProfileDialog.id(), action: {:bio, draft, warning})
    {:halt, socket}
  end

  def handle_event("profile_bio_submit", %{"bio" => bio}, socket) do
    {bio, warning} = normalize_bio_draft(bio)
    args = if String.trim(bio) == "", do: ["clear"], else: [bio]
    send_update(ProfileDialog, id: ProfileDialog.id(), action: {:bio, bio, warning})
    {:halt, dispatch(socket, "bio", args)}
  end

  def handle_event("profile_clear_bio", _params, socket) do
    send_update(ProfileDialog, id: ProfileDialog.id(), action: {:bio, "", nil})
    {:halt, dispatch(socket, "bio", ["clear"])}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc """
  Opens/focuses the Profile window, seeding the bio draft from the session and
  refreshing it from the domain (`/bio` echoes the stored value).
  """
  @spec open(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def open(socket) do
    bio = Session.get_bio(socket.assigns.session) || ""

    socket
    |> Windows.open_with("profile", ProfileDialog, id: ProfileDialog.id(), bio: bio)
    |> dispatch("bio", [])
  end

  defp validate_nickname_change(current_nickname, new_nickname) do
    if new_nickname == current_nickname do
      {:error, dgettext("chat", "You are already using that nickname")}
    else
      NicknameValidator.validate(new_nickname)
    end
  end

  defp normalize_bio_draft(bio) do
    bio = bio || ""
    draft = String.slice(bio, 0, @max_bio_graphemes)

    warning =
      if String.length(bio) > @max_bio_graphemes do
        dgettext("chat", "Bio is limited to 200 characters; extra text was not kept.")
      end

    {draft, warning}
  end

  defp nick_error(socket, message) do
    send_update(ProfileDialog, id: ProfileDialog.id(), action: {:nick_error, message})
    socket
  end

  defp dispatch(socket, name, args) do
    CommandDispatch.dispatch_command(socket, socket.assigns.session, name, args)
  end
end
