defmodule RetroHexChat.Repo.Migrations.AddIrcArtContentFormat do
  use Ecto.Migration

  # A block of text art in mIRC colours is a fourth format beside IRC,
  # Markdown and plain text.
  @tables [
    messages: :messages_content_format_check,
    private_messages: :private_messages_content_format_check
  ]

  def up do
    for {table, name} <- @tables do
      drop constraint(table, name)

      create constraint(table, name,
               check: "content_format IN ('irc', 'irc_art', 'markdown', 'plain')"
             )
    end
  end

  def down do
    for {table, name} <- @tables do
      execute "UPDATE #{table} SET content_format = 'irc' WHERE content_format = 'irc_art'"
      drop constraint(table, name)
      create constraint(table, name, check: "content_format IN ('irc', 'markdown', 'plain')")
    end
  end
end
