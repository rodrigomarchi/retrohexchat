defmodule RetroHexChat.Repo.Migrations.UniqueNicknamesIgnoreCase do
  @moduledoc """
  A nickname names one person whatever its case (`RetroHexChat.Nickname`), so
  every unique index on a nickname compares `lower(...)`.

  Refuses to run while rows differ by case alone — building the index would fail
  half-way, and which spelling to keep is a decision, not a migration's.
  `RetroHexChat.Release.check_nickname_duplicates/0` lists them beforehand.

  `registered_nicks` keeps its exact unique index beside the new one: per-user
  tables reference `registered_nicks.nickname`, and a foreign key needs it.
  """
  use Ecto.Migration

  alias RetroHexChat.Nickname.Uniqueness

  # The exact indexes each lower() index replaces.
  @replaced %{
    "access_list_entries" => :idx_access_list_channel_nickname,
    "bans" => :idx_bans_channel_nickname,
    "ban_exceptions" => :idx_ban_exceptions_channel_nickname,
    "invite_exceptions" => :idx_invite_exceptions_channel_nickname,
    "server_bans" => :idx_server_bans_active_nickname,
    "admin_roles" => :admin_roles_nickname_role_index,
    "channel_event_attendees" => :channel_event_attendees_event_id_nickname_index
  }

  def up do
    case Uniqueness.duplicates(repo()) do
      [] ->
        :ok

      found ->
        raise "nicknames that differ only by case must be resolved first: #{inspect(found)}"
    end

    for index <- Uniqueness.indexes() do
      if old = @replaced[index.table], do: drop_if_exists(index(index.table, [], name: old))

      create unique_index(index.table, index.scope ++ ["lower(#{index.nickname})"],
               name: index.name,
               where: index.where
             )
    end

    create index(:private_messages, ["lower(sender_nickname)"],
             name: :idx_private_messages_sender_lower
           )

    create index(:private_messages, ["lower(recipient_nickname)"],
             name: :idx_private_messages_recipient_lower
           )
  end

  def down do
    drop index(:private_messages, [], name: :idx_private_messages_recipient_lower)
    drop index(:private_messages, [], name: :idx_private_messages_sender_lower)

    for index <- Uniqueness.indexes() do
      drop index(index.table, [], name: index.name)

      if old = @replaced[index.table] do
        create unique_index(index.table, index.scope ++ [index.nickname],
                 name: old,
                 where: index.where
               )
      end
    end
  end
end
