defmodule RetroHexChat.Repo.Migrations.CreateHighlightWords do
  use Ecto.Migration

  def change do
    create table(:highlight_words) do
      add :owner_nickname,
          references(:registered_nicks, column: :nickname, type: :string, on_delete: :delete_all),
          null: false,
          size: 16

      add :word, :string, null: false, size: 50
      add :bg_color, :integer
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(
             :highlight_words,
             ["lower(owner_nickname)", "lower(word)"],
             name: :idx_highlight_words_owner_word
           )

    create index(:highlight_words, [:owner_nickname], name: :idx_highlight_words_owner)

    create constraint(:highlight_words, :bg_color_range,
             check: "bg_color >= 0 AND bg_color <= 15"
           )
  end
end
