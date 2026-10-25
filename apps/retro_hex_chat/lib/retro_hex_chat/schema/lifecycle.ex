defmodule RetroHexChat.Schema.Lifecycle do
  @moduledoc """
  A schema whose records move through a set of statuses and end in one of a
  few terminal ones — a call room, a track, a lobby session.

      use RetroHexChat.Schema.Lifecycle,
        statuses: ~w(pending open closed expired),
        terminal: ~w(closed expired),
        terminal_fields: [:closed_at, :closed_reason]

  sets `@status_values` and `@terminal_statuses` for the schema's own
  changesets, and defines `status_values/0`, `terminal_statuses/0` and
  `terminal?/1`. With `terminal_fields` it also defines the private
  `validate_terminal_fields/1`, which requires those fields once the status
  is terminal. Use it before the changesets that read the attributes.
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @status_values Keyword.fetch!(opts, :statuses)
      @terminal_statuses Keyword.fetch!(opts, :terminal)
      @terminal_fields Keyword.get(opts, :terminal_fields, [])

      @spec status_values() :: [String.t()]
      def status_values, do: @status_values

      @spec terminal_statuses() :: [String.t()]
      def terminal_statuses, do: @terminal_statuses

      @spec terminal?(String.t()) :: boolean()
      def terminal?(status), do: status in @terminal_statuses

      if @terminal_fields != [] do
        defp validate_terminal_fields(changeset) do
          if Ecto.Changeset.get_field(changeset, :status) in @terminal_statuses do
            Ecto.Changeset.validate_required(changeset, @terminal_fields)
          else
            changeset
          end
        end
      end
    end
  end
end
