defmodule RetroHexChat.Repo.Migrations.AddMessageContentFormats do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :content_format, :string, null: false, default: "irc", size: 16
      add :plain_content, :text
    end

    create constraint(:messages, :messages_content_format_check,
             check: "content_format IN ('irc', 'markdown', 'plain')"
           )

    alter table(:private_messages) do
      add :content_format, :string, null: false, default: "irc", size: 16
      add :plain_content, :text
    end

    create constraint(:private_messages, :private_messages_content_format_check,
             check: "content_format IN ('irc', 'markdown', 'plain')"
           )
  end
end
