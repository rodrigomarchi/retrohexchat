defmodule RetroHexChatWeb.ChatLive.Helpers.Persistence do
  @moduledoc """
  Fire-and-forget async persistence for identified users.
  Each function returns the socket unchanged (pipeline-friendly).
  """

  alias RetroHexChat.Accounts.{ContactList, NickColors, Session}

  alias RetroHexChat.Chat.{
    AliasList,
    AutoJoinList,
    AutoRespondRules,
    CustomMenus,
    FloodProtection,
    HighlightWords,
    IgnoreList,
    PerformList,
    Queries,
    SoundSettings,
    UserBio,
    UserPreferences
  }

  alias RetroHexChat.Chat.{CtcpSettings, NoticeRouting}
  alias RetroHexChat.Presence.NotifyList

  @spec maybe_persist_notify_list(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_notify_list(socket, session) do
    if session.identified do
      Task.start(fn -> NotifyList.save(session.nickname, session.notify_list) end)
    end

    socket
  end

  @spec maybe_persist_contacts(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_contacts(socket, session) do
    if session.identified do
      Task.start(fn -> ContactList.save(session.nickname, session.contacts) end)
    end

    socket
  end

  @spec maybe_persist_nick_colors(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_nick_colors(socket, session) do
    if session.identified do
      Task.start(fn -> NickColors.save(session.nickname, session.nick_colors) end)
    end

    socket
  end

  @spec maybe_persist_highlight_words(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_highlight_words(socket, session) do
    if session.identified do
      Task.start(fn -> HighlightWords.save(session.nickname, session.highlight_words) end)
    end

    socket
  end

  @spec maybe_persist_ignore_list(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_ignore_list(socket, session) do
    if session.identified do
      Task.start(fn -> IgnoreList.save(session.nickname, session.ignore_list) end)
    end

    socket
  end

  @spec maybe_persist_perform_list(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_perform_list(socket, session) do
    if session.identified do
      Task.start(fn -> PerformList.save(session.nickname, session.perform_list) end)
    end

    socket
  end

  @spec maybe_persist_autojoin_list(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_autojoin_list(socket, session) do
    if session.identified do
      Task.start(fn -> AutoJoinList.save(session.nickname, session.autojoin_list) end)
    end

    socket
  end

  @spec maybe_persist_aliases(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_aliases(socket, session) do
    if session.identified do
      Task.start(fn -> AliasList.save(session.nickname, session.aliases) end)
    end

    socket
  end

  @spec maybe_persist_custom_menus(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_custom_menus(socket, session) do
    if session.identified do
      Task.start(fn -> CustomMenus.save(session.nickname, session.custom_menus) end)
    end

    socket
  end

  @spec maybe_persist_autorespond_rules(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_autorespond_rules(socket, session) do
    if session.identified do
      Task.start(fn ->
        AutoRespondRules.save(session.nickname, session.autorespond_rules)
      end)
    end

    socket
  end

  @spec maybe_persist_user_preferences(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_persist_user_preferences(socket, session) do
    if session.identified do
      Task.start(fn ->
        UserPreferences.save(session.nickname, session.user_preferences)
      end)
    end

    socket
  end

  @spec load_persisted_data(Session.t(), String.t()) :: Session.t()
  def load_persisted_data(session, nick) do
    session
    |> load_if_found(NotifyList.load(nick), &Session.set_notify_list/2)
    |> load_if_found(ContactList.load(nick), &Session.set_contacts/2)
    |> load_if_found(NickColors.load(nick), &Session.set_nick_colors/2)
    |> load_if_found(HighlightWords.load(nick), &Session.set_highlight_words/2)
    |> load_if_found(IgnoreList.load(nick), &Session.set_ignore_list/2)
    |> load_if_found(PerformList.load(nick), &Session.set_perform_list/2)
    |> load_if_found(AutoJoinList.load(nick), &Session.set_autojoin_list/2)
    |> load_if_found(NoticeRouting.load(nick), fn session_inner, %{routing: routing} ->
      Session.set_notice_routing(session_inner, routing)
    end)
    |> load_if_found(CtcpSettings.load(nick), &Session.set_ctcp_settings/2)
    |> load_if_found(FloodProtection.load(nick), &Session.set_flood_protection/2)
    |> load_if_found(SoundSettings.load(nick), &Session.set_sound_settings/2)
    |> load_if_found(UserBio.load(nick), &Session.set_bio/2)
    |> load_if_found(AliasList.load(nick), &Session.set_aliases/2)
    |> load_if_found(CustomMenus.load(nick), &Session.set_custom_menus/2)
    |> load_if_found(AutoRespondRules.load(nick), &Session.set_autorespond_rules/2)
    |> load_if_found(UserPreferences.load(nick), &Session.set_user_preferences/2)
    |> restore_pm_conversations(nick)
  end

  @spec restore_pm_conversations(Session.t(), String.t()) :: Session.t()
  def restore_pm_conversations(session, nick) do
    partners = Queries.list_pm_partners(nick)
    nicks = Enum.map(partners, & &1.nickname)

    Enum.each(nicks, fn partner_nick ->
      topic = "pm:#{pm_topic(nick, partner_nick)}"
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, topic)
    end)

    %{session | pm_conversations: nicks}
  end

  defp pm_topic(nick_a, nick_b) do
    [nick_a, nick_b] |> Enum.sort() |> Enum.join(":")
  end

  defp load_if_found(session, {:ok, data}, setter), do: setter.(session, data)
  defp load_if_found(session, {:error, _}, _setter), do: session
end
