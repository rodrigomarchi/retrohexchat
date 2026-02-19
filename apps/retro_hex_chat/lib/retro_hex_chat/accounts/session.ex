defmodule RetroHexChat.Accounts.Session do
  @moduledoc """
  In-memory session struct representing a connected user's state.
  Lives in the LiveView socket assigns, not persisted to DB.
  """

  alias RetroHexChat.Accounts.ContactList
  alias RetroHexChat.Accounts.NickColors
  alias RetroHexChat.Chat.AutoJoinList
  alias RetroHexChat.Chat.CtcpSettings
  alias RetroHexChat.Chat.DisplayPreferences
  alias RetroHexChat.Chat.Favorites
  alias RetroHexChat.Chat.FloodProtection
  alias RetroHexChat.Chat.HighlightWords
  alias RetroHexChat.Chat.IgnoreList
  alias RetroHexChat.Chat.PerformList
  alias RetroHexChat.Chat.SoundSettings
  alias RetroHexChat.Chat.UserPreferences
  alias RetroHexChat.Presence.NotifyList

  @type t :: %__MODULE__{
          nickname: String.t(),
          channels: [String.t()],
          active_channel: String.t() | nil,
          pm_conversations: [String.t()],
          active_pm: String.t() | nil,
          identified: boolean(),
          connected_at: DateTime.t(),
          away: boolean(),
          away_message: String.t() | nil,
          strip_formatting: boolean(),
          notify_list: map(),
          contacts: map(),
          nick_colors: map(),
          highlight_words: map(),
          ignore_list: map(),
          log_preferences: map(),
          perform_list: map(),
          autojoin_list: map(),
          auto_join_on_invite: boolean(),
          notice_routing: :active | :status | :sender,
          ctcp_settings: map(),
          favorites: map(),
          flood_protection: map(),
          sound_settings: map(),
          aliases: map(),
          custom_menus: map(),
          autorespond_rules: map(),
          bio: String.t() | nil,
          user_preferences: map(),
          last_message_at: DateTime.t(),
          user_modes: map(),
          welcomed_channels: map()
        }

  @enforce_keys [:nickname]
  defstruct [
    :nickname,
    channels: [],
    active_channel: nil,
    pm_conversations: [],
    active_pm: nil,
    identified: false,
    connected_at: nil,
    away: false,
    away_message: nil,
    strip_formatting: false,
    notify_list: nil,
    contacts: nil,
    nick_colors: nil,
    highlight_words: nil,
    ignore_list: nil,
    log_preferences: nil,
    perform_list: nil,
    autojoin_list: nil,
    auto_join_on_invite: false,
    notice_routing: :active,
    ctcp_settings: nil,
    favorites: nil,
    flood_protection: nil,
    sound_settings: nil,
    aliases: nil,
    custom_menus: nil,
    autorespond_rules: nil,
    bio: nil,
    user_preferences: nil,
    last_message_at: nil,
    user_modes: nil,
    welcomed_channels: nil
  ]

  @spec new(String.t()) :: t()
  def new(nickname) do
    %__MODULE__{
      nickname: nickname,
      connected_at: DateTime.utc_now(),
      notify_list: NotifyList.new(),
      contacts: ContactList.new(),
      nick_colors: NickColors.new(),
      highlight_words: HighlightWords.new(),
      ignore_list: IgnoreList.new(),
      log_preferences: DisplayPreferences.new(),
      perform_list: PerformList.new(),
      autojoin_list: AutoJoinList.new(),
      ctcp_settings: CtcpSettings.new(),
      favorites: Favorites.new(),
      flood_protection: FloodProtection.new(),
      sound_settings: SoundSettings.new(),
      user_preferences: UserPreferences.new(),
      aliases: %{entries: []},
      custom_menus: %{entries: []},
      autorespond_rules: %{entries: []},
      last_message_at: DateTime.utc_now(),
      user_modes: MapSet.new(),
      welcomed_channels: MapSet.new()
    }
  end

  @spec update_nickname(t(), String.t()) :: t()
  def update_nickname(%__MODULE__{} = session, new_nickname) do
    %{session | nickname: new_nickname}
  end

  @spec add_channel(t(), String.t()) :: t()
  def add_channel(%__MODULE__{channels: channels} = session, channel_name) do
    if channel_name in channels do
      session
    else
      %{session | channels: channels ++ [channel_name]}
    end
  end

  @spec remove_channel(t(), String.t()) :: t()
  def remove_channel(
        %__MODULE__{channels: channels, active_channel: active} = session,
        channel_name
      ) do
    new_channels = List.delete(channels, channel_name)
    new_active = if active == channel_name, do: List.first(new_channels), else: active
    %{session | channels: new_channels, active_channel: new_active}
  end

  @spec set_identified(t(), boolean()) :: t()
  def set_identified(%__MODULE__{} = session, identified) do
    %{session | identified: identified}
  end

  @spec set_active_channel(t(), String.t() | nil) :: t()
  def set_active_channel(%__MODULE__{} = session, channel_name) do
    %{session | active_channel: channel_name, active_pm: nil}
  end

  @spec add_pm_conversation(t(), String.t()) :: t()
  def add_pm_conversation(%__MODULE__{pm_conversations: pms} = session, nickname) do
    %{session | pm_conversations: [nickname | List.delete(pms, nickname)]}
  end

  @spec move_pm_to_front(t(), String.t()) :: t()
  def move_pm_to_front(%__MODULE__{pm_conversations: pms} = session, nickname) do
    if nickname in pms do
      %{session | pm_conversations: [nickname | List.delete(pms, nickname)]}
    else
      session
    end
  end

  @spec remove_pm_conversation(t(), String.t()) :: t()
  def remove_pm_conversation(
        %__MODULE__{pm_conversations: pms, active_pm: active} = session,
        nickname
      ) do
    new_pms = List.delete(pms, nickname)
    new_active = if active == nickname, do: nil, else: active
    %{session | pm_conversations: new_pms, active_pm: new_active}
  end

  @spec set_active_pm(t(), String.t() | nil) :: t()
  def set_active_pm(%__MODULE__{} = session, nickname) do
    %{session | active_pm: nickname, active_channel: nil}
  end

  @spec toggle_strip_formatting(t()) :: t()
  def toggle_strip_formatting(%__MODULE__{strip_formatting: current} = session) do
    %{session | strip_formatting: !current}
  end

  @spec set_away(t(), String.t() | nil) :: t()
  def set_away(%__MODULE__{} = session, nil) do
    %{session | away: false, away_message: nil}
  end

  def set_away(%__MODULE__{} = session, message) do
    %{session | away: true, away_message: message}
  end

  @spec set_notify_list(t(), map()) :: t()
  def set_notify_list(%__MODULE__{} = session, notify_list) do
    %{session | notify_list: notify_list}
  end

  @spec get_notify_list(t()) :: map()
  def get_notify_list(%__MODULE__{notify_list: notify_list}) do
    notify_list
  end

  @spec set_contacts(t(), map()) :: t()
  def set_contacts(%__MODULE__{} = session, contacts) do
    %{session | contacts: contacts}
  end

  @spec get_contacts(t()) :: map()
  def get_contacts(%__MODULE__{contacts: contacts}) do
    contacts
  end

  @spec set_nick_colors(t(), map()) :: t()
  def set_nick_colors(%__MODULE__{} = session, nick_colors) do
    %{session | nick_colors: nick_colors}
  end

  @spec get_nick_colors(t()) :: map()
  def get_nick_colors(%__MODULE__{nick_colors: nick_colors}) do
    nick_colors
  end

  @spec set_highlight_words(t(), map()) :: t()
  def set_highlight_words(%__MODULE__{} = session, highlight_words) do
    %{session | highlight_words: highlight_words}
  end

  @spec get_highlight_words(t()) :: map()
  def get_highlight_words(%__MODULE__{highlight_words: highlight_words}) do
    highlight_words
  end

  @spec set_ignore_list(t(), map()) :: t()
  def set_ignore_list(%__MODULE__{} = session, ignore_list) do
    %{session | ignore_list: ignore_list}
  end

  @spec get_ignore_list(t()) :: map()
  def get_ignore_list(%__MODULE__{ignore_list: ignore_list}) do
    ignore_list
  end

  @spec set_log_preferences(t(), DisplayPreferences.t()) :: t()
  def set_log_preferences(%__MODULE__{} = session, %DisplayPreferences{} = prefs) do
    %{session | log_preferences: prefs}
  end

  @spec log_preferences(t()) :: DisplayPreferences.t()
  def log_preferences(%__MODULE__{log_preferences: prefs}) do
    prefs
  end

  @spec set_perform_list(t(), map()) :: t()
  def set_perform_list(%__MODULE__{} = session, perform_list) do
    %{session | perform_list: perform_list}
  end

  @spec get_perform_list(t()) :: map()
  def get_perform_list(%__MODULE__{perform_list: perform_list}) do
    perform_list
  end

  @spec set_autojoin_list(t(), map()) :: t()
  def set_autojoin_list(%__MODULE__{} = session, autojoin_list) do
    %{session | autojoin_list: autojoin_list}
  end

  @spec get_autojoin_list(t()) :: map()
  def get_autojoin_list(%__MODULE__{autojoin_list: autojoin_list}) do
    autojoin_list
  end

  @spec get_auto_join_on_invite(t()) :: boolean()
  def get_auto_join_on_invite(%__MODULE__{auto_join_on_invite: value}), do: value

  @spec set_auto_join_on_invite(t(), boolean()) :: t()
  def set_auto_join_on_invite(%__MODULE__{} = session, value) when is_boolean(value) do
    %{session | auto_join_on_invite: value}
  end

  @spec toggle_auto_join_on_invite(t()) :: t()
  def toggle_auto_join_on_invite(%__MODULE__{auto_join_on_invite: current} = session) do
    %{session | auto_join_on_invite: not current}
  end

  @spec get_notice_routing(t()) :: :active | :status | :sender
  def get_notice_routing(%__MODULE__{notice_routing: value}), do: value

  @spec set_notice_routing(t(), :active | :status | :sender) :: t()
  def set_notice_routing(%__MODULE__{} = session, routing)
      when routing in [:active, :status, :sender] do
    %{session | notice_routing: routing}
  end

  @spec get_ctcp_settings(t()) :: map()
  def get_ctcp_settings(%__MODULE__{ctcp_settings: settings}), do: settings

  @spec set_ctcp_settings(t(), map()) :: t()
  def set_ctcp_settings(%__MODULE__{} = session, settings) do
    %{session | ctcp_settings: settings}
  end

  @spec get_favorites(t()) :: map()
  def get_favorites(%__MODULE__{favorites: favorites}), do: favorites

  @spec set_favorites(t(), map()) :: t()
  def set_favorites(%__MODULE__{} = session, favorites) do
    %{session | favorites: favorites}
  end

  @spec get_flood_protection(t()) :: map()
  def get_flood_protection(%__MODULE__{flood_protection: settings}), do: settings

  @spec set_flood_protection(t(), map()) :: t()
  def set_flood_protection(%__MODULE__{} = session, settings) do
    %{session | flood_protection: settings}
  end

  @spec get_sound_settings(t()) :: map()
  def get_sound_settings(%__MODULE__{sound_settings: settings}), do: settings

  @spec set_sound_settings(t(), map()) :: t()
  def set_sound_settings(%__MODULE__{} = session, settings) do
    %{session | sound_settings: settings}
  end

  @spec get_aliases(t()) :: map()
  def get_aliases(%__MODULE__{aliases: aliases}), do: aliases

  @spec set_aliases(t(), map()) :: t()
  def set_aliases(%__MODULE__{} = session, aliases) do
    %{session | aliases: aliases}
  end

  @spec get_custom_menus(t()) :: map()
  def get_custom_menus(%__MODULE__{custom_menus: custom_menus}), do: custom_menus

  @spec set_custom_menus(t(), map()) :: t()
  def set_custom_menus(%__MODULE__{} = session, custom_menus) do
    %{session | custom_menus: custom_menus}
  end

  @spec get_autorespond_rules(t()) :: map()
  def get_autorespond_rules(%__MODULE__{autorespond_rules: rules}), do: rules

  @spec set_autorespond_rules(t(), map()) :: t()
  def set_autorespond_rules(%__MODULE__{} = session, rules) do
    %{session | autorespond_rules: rules}
  end

  @spec get_bio(t()) :: String.t() | nil
  def get_bio(%__MODULE__{bio: bio}), do: bio

  @spec set_bio(t(), String.t() | nil) :: t()
  def set_bio(%__MODULE__{} = session, bio) do
    %{session | bio: bio}
  end

  @spec get_last_message_at(t()) :: DateTime.t()
  def get_last_message_at(%__MODULE__{last_message_at: value}), do: value

  @spec set_last_message_at(t(), DateTime.t()) :: t()
  def set_last_message_at(%__MODULE__{} = session, %DateTime{} = timestamp) do
    %{session | last_message_at: timestamp}
  end

  @spec has_mode?(t(), atom()) :: boolean()
  def has_mode?(%__MODULE__{user_modes: modes}, mode) do
    MapSet.member?(modes, mode)
  end

  @spec set_mode(t(), atom()) :: t()
  def set_mode(%__MODULE__{user_modes: modes} = session, mode) do
    %{session | user_modes: MapSet.put(modes, mode)}
  end

  @spec unset_mode(t(), atom()) :: t()
  def unset_mode(%__MODULE__{user_modes: modes} = session, mode) do
    %{session | user_modes: MapSet.delete(modes, mode)}
  end

  @spec add_welcomed_channel(t(), String.t()) :: t()
  def add_welcomed_channel(%__MODULE__{welcomed_channels: channels} = session, channel_name) do
    %{session | welcomed_channels: MapSet.put(channels, channel_name)}
  end

  @spec welcomed_channel?(t(), String.t()) :: boolean()
  def welcomed_channel?(%__MODULE__{welcomed_channels: channels}, channel_name) do
    MapSet.member?(channels, channel_name)
  end

  @spec get_user_preferences(t()) :: map()
  def get_user_preferences(%__MODULE__{user_preferences: prefs}), do: prefs

  @spec set_user_preferences(t(), map()) :: t()
  def set_user_preferences(%__MODULE__{} = session, prefs) do
    %{session | user_preferences: prefs}
  end
end
