defmodule RetroHexChatWeb.ChatLive.Helpers.Persistence do
  @moduledoc """
  Durable async persistence for identified users.
  Each function returns the socket unchanged (pipeline-friendly).
  """

  require Logger

  alias RetroHexChat.Accounts.{ContactList, NickColors, Session}

  alias RetroHexChat.Chat.{
    AliasList,
    AutoJoinList,
    AutoRespondRules,
    ContextualTips,
    CustomMenus,
    FloodProtection,
    HighlightWords,
    IgnoreList,
    InputHistory,
    PerformList,
    PreferencePersistence,
    Queries,
    SoundSettings,
    UserBio
  }

  alias RetroHexChat.Presence.{NotifyList, Tracker}
  alias RetroHexChat.Topics

  @spec maybe_persist_notify_list(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_notify_list(socket, session) do
    persist(session, :notify_list, session.notify_list)
    socket
  end

  @spec maybe_persist_contacts(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_contacts(socket, session) do
    persist(session, :contacts, session.contacts)
    socket
  end

  @spec maybe_persist_nick_colors(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_nick_colors(socket, session) do
    persist(session, :nick_colors, session.nick_colors)
    socket
  end

  @spec maybe_persist_highlight_words(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_highlight_words(socket, session) do
    persist(session, :highlight_words, session.highlight_words)
    socket
  end

  @spec maybe_persist_ignore_list(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_ignore_list(socket, session) do
    persist(session, :ignore_list, session.ignore_list)
    socket
  end

  @spec maybe_persist_perform_list(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_perform_list(socket, session) do
    persist(session, :perform_list, session.perform_list)
    socket
  end

  @spec maybe_persist_autojoin_list(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_autojoin_list(socket, session) do
    persist(session, :autojoin_list, session.autojoin_list)
    socket
  end

  @spec maybe_persist_input_history(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_input_history(socket, session) do
    persist(session, :input_history, session.input_history)
    socket
  end

  @spec maybe_persist_aliases(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_aliases(socket, session) do
    persist(session, :aliases, session.aliases)
    socket
  end

  @spec maybe_persist_custom_menus(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_custom_menus(socket, session) do
    persist(session, :custom_menus, session.custom_menus)
    socket
  end

  @spec maybe_persist_autorespond_rules(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_autorespond_rules(socket, session) do
    persist(session, :autorespond_rules, session.autorespond_rules)
    socket
  end

  @spec load_persisted_data(Session.t(), String.t()) :: Session.t()
  def load_persisted_data(session, nick) do
    session
    |> load_if_found(NotifyList.load(nick), &Session.set_notify_list/2)
    |> sync_notify_online_status()
    |> load_if_found(ContactList.load(nick), &Session.set_contacts/2)
    |> load_if_found(NickColors.load(nick), &Session.set_nick_colors/2)
    |> load_if_found(HighlightWords.load(nick), &Session.set_highlight_words/2)
    |> load_if_found(IgnoreList.load(nick), &Session.set_ignore_list/2)
    |> load_if_found(PerformList.load(nick), &Session.set_perform_list/2)
    |> load_if_found(AutoJoinList.load(nick), &Session.set_autojoin_list/2)
    |> load_if_found(ContextualTips.load(nick), &Session.set_contextual_tips/2)
    |> load_if_found(InputHistory.load(nick), &Session.set_input_history/2)
    |> load_if_found(FloodProtection.load(nick), &Session.set_flood_protection/2)
    |> load_if_found(SoundSettings.load(nick), &Session.set_sound_settings/2)
    |> load_if_found(UserBio.load(nick), &Session.set_bio/2)
    |> load_if_found(AliasList.load(nick), &Session.set_aliases/2)
    |> load_if_found(CustomMenus.load(nick), &Session.set_custom_menus/2)
    |> load_if_found(AutoRespondRules.load(nick), &Session.set_autorespond_rules/2)
    |> restore_pm_conversations(nick)
  end

  @spec restore_pm_conversations(Session.t(), String.t()) :: Session.t()
  def restore_pm_conversations(session, nick) do
    page = Queries.list_pm_partners(nick)
    nicks = Enum.map(page.items, & &1.nickname)

    %{session | pm_conversations: nicks, pm_conversations_truncated: page.has_more}
  end

  @spec sync_notify_online_status(Session.t()) :: Session.t()
  defp sync_notify_online_status(session) do
    if session.notify_list.entries == [] do
      session
    else
      online_nicks =
        Tracker.list_users(Topics.presence())
        |> Enum.map(& &1.nickname)

      updated_list = NotifyList.sync_online_status(session.notify_list, online_nicks)
      Session.set_notify_list(session, updated_list)
    end
  end

  defp load_if_found(session, {:ok, data}, setter), do: setter.(session, data)
  defp load_if_found(session, {:error, _}, _setter), do: session

  defp persist(%Session{identified: true, nickname: nickname}, type, snapshot) do
    case PreferencePersistence.enqueue(nickname, type, snapshot) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "preference_persistence_enqueue_error type=#{type} reason=#{inspect(reason)}"
        )

        :ok
    end
  end

  defp persist(_session, _type, _snapshot), do: :ok
end
