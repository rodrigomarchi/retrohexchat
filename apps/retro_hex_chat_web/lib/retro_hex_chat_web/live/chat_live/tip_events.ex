defmodule RetroHexChatWeb.ChatLive.TipEvents do
  @moduledoc """
  Persists contextual-tip state sent by the ContextualTipsHook JS hook.

  Attached as `attach_hook(:tip_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  require Logger

  import Phoenix.Component, only: [assign: 2]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.ContextualTips

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont | :halt, Phoenix.LiveView.Socket.t()}

  def handle_event("tips_seen", %{"tips" => tip_ids}, socket) when is_list(tip_ids) do
    tips =
      Enum.reduce(tip_ids, socket.assigns.session.contextual_tips, fn tip_id, acc ->
        ContextualTips.mark_seen(acc, tip_id)
      end)

    {:halt, commit_tips(socket, tips)}
  end

  def handle_event("tip_seen", %{"tip" => tip_id}, socket) do
    {:halt,
     commit_tips(socket, ContextualTips.mark_seen(socket.assigns.session.contextual_tips, tip_id))}
  end

  def handle_event("tips_suppressed_changed", %{"suppressed" => suppressed}, socket)
      when is_boolean(suppressed) do
    tips = ContextualTips.set_suppressed(socket.assigns.session.contextual_tips, suppressed)

    {:halt, commit_tips(socket, tips)}
  end

  def handle_event("tips_suppressed_changed", _params, socket), do: {:halt, socket}
  def handle_event("tips_state_sync", _params, socket), do: {:halt, socket}

  def handle_event(_event, _params, socket), do: {:cont, socket}

  defp commit_tips(socket, tips) do
    session = Session.set_contextual_tips(socket.assigns.session, tips)
    persist_contextual_tips(session)
    assign(socket, session: session)
  end

  defp persist_contextual_tips(%Session{identified: true, nickname: nickname} = session) do
    case ContextualTips.save(nickname, session.contextual_tips) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to persist contextual tips for #{nickname}: #{inspect(reason)}")
        :ok
    end
  rescue
    error ->
      Logger.warning(
        "Failed to persist contextual tips for #{nickname}: #{Exception.message(error)}"
      )

      :ok
  end

  defp persist_contextual_tips(_session), do: :ok
end
