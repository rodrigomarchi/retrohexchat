defmodule RetroHexChat.Nickname.Uniqueness do
  @moduledoc """
  The database's half of `RetroHexChat.Nickname`: every unique index that names a
  person by nickname, and the rows that would break it.

  Each index compares `lower(column)`, so `Alice` and `alice` cannot both hold a
  registration, an access entry, a ban or a role. Before such an index can be
  built, no two rows may differ by case alone; `duplicates/1` lists any that do,
  and the migration that builds the indexes refuses to run while there are some.

      bin/retro_hex_chat eval "RetroHexChat.Release.check_nickname_duplicates()"
  """

  @typedoc "One unique index: its table, the columns beside the nickname, and its name."
  @type index :: %{
          table: String.t(),
          scope: [String.t()],
          nickname: String.t(),
          name: String.t(),
          where: String.t() | nil
        }

  @indexes [
    %{
      table: "registered_nicks",
      scope: [],
      nickname: "nickname",
      name: "idx_registered_nicks_nickname_lower",
      where: nil
    },
    %{
      table: "access_list_entries",
      scope: ["channel_name"],
      nickname: "nickname",
      name: "idx_access_list_channel_nickname_lower",
      where: nil
    },
    %{
      table: "bans",
      scope: ["channel_name"],
      nickname: "banned_nickname",
      name: "idx_bans_channel_nickname_lower",
      where: nil
    },
    %{
      table: "ban_exceptions",
      scope: ["channel_name"],
      nickname: "nickname",
      name: "idx_ban_exceptions_channel_nickname_lower",
      where: nil
    },
    %{
      table: "invite_exceptions",
      scope: ["channel_name"],
      nickname: "nickname",
      name: "idx_invite_exceptions_channel_nickname_lower",
      where: nil
    },
    %{
      table: "server_bans",
      scope: [],
      nickname: "nickname",
      name: "idx_server_bans_active_nickname_lower",
      where: "active = true"
    },
    %{
      table: "admin_roles",
      scope: ["role"],
      nickname: "nickname",
      name: "idx_admin_roles_nickname_role_lower",
      where: nil
    },
    %{
      table: "channel_event_attendees",
      scope: ["event_id"],
      nickname: "nickname",
      name: "idx_channel_event_attendees_event_nickname_lower",
      where: nil
    }
  ]

  @doc "Every unique index that names a person by nickname."
  @spec indexes() :: [index()]
  def indexes, do: @indexes

  @doc "The index named `name`; raises for a name this module does not own."
  @spec index!(String.t()) :: index()
  def index!(name), do: Enum.find(@indexes, &(&1.name == name)) || raise(ArgumentError, name)

  @doc """
  Rows that differ by nickname case alone, per index, as
  `{table, [scope values ..., [spellings]]}`. Empty means every index can be built.
  """
  @spec duplicates(Ecto.Repo.t()) :: [{String.t(), list()}]
  def duplicates(repo) do
    Enum.flat_map(@indexes, fn index ->
      %{rows: rows} = repo.query!(duplicates_sql(index))
      Enum.map(rows, &{index.table, &1})
    end)
  end

  @doc "The SQL that lists one index's duplicates."
  @spec duplicates_sql(index()) :: String.t()
  def duplicates_sql(%{table: table, scope: scope, nickname: nick, where: where}) do
    group = Enum.join(scope ++ ["lower(#{nick})"], ", ")
    select = Enum.join(scope ++ ["array_agg(#{nick} ORDER BY #{nick})"], ", ")
    filter = if where, do: " WHERE #{where}", else: ""

    "SELECT #{select} FROM #{table}#{filter} GROUP BY #{group} HAVING count(*) > 1"
  end
end
