defmodule RetroHexChat.Accounts.Contact do
  @moduledoc """
  In-memory runtime struct for a single address book contact entry.
  The `first_contact_date` records when the contact was first added.
  """

  @type t :: %__MODULE__{
          contact_nickname: String.t(),
          note: String.t() | nil,
          first_contact_date: DateTime.t()
        }

  @enforce_keys [:contact_nickname, :first_contact_date]
  defstruct [
    :contact_nickname,
    :note,
    :first_contact_date
  ]

  @spec new(keyword() | map()) :: t()
  def new(attrs) when is_list(attrs) do
    attrs = Keyword.put_new_lazy(attrs, :first_contact_date, &DateTime.utc_now/0)
    attrs = Keyword.put_new(attrs, :note, nil)
    struct!(__MODULE__, attrs)
  end

  def new(attrs) when is_map(attrs) do
    attrs = Map.put_new_lazy(attrs, :first_contact_date, &DateTime.utc_now/0)
    attrs = Map.put_new(attrs, :note, nil)
    new(Map.to_list(attrs))
  end
end
