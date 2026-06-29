defmodule RetroHexChatWeb.ChatLive.ChatContext do
  @moduledoc """
  Minimal, stable global context for the chat UI.

  Carries exactly the identity and authorization facts a child component island
  needs to render and authorize, so islands depend on this small struct instead
  of reaching into the full `Session` or recomputing authorization checks. It is
  built once per render from the `Session` via `from_session/2`.

  The authorization booleans (`admin?`, `admin_only?`, `root_admin?`) are the
  single source of truth for those checks across the chat UI.
  """

  alias RetroHexChat.Accounts.{ServerRoles, Session}

  @type t :: %__MODULE__{
          nickname: String.t(),
          active_channel: String.t() | nil,
          active_pm: String.t() | nil,
          timezone: String.t(),
          identified: boolean(),
          admin?: boolean(),
          admin_only?: boolean(),
          root_admin?: boolean()
        }

  @enforce_keys [:nickname]
  defstruct nickname: nil,
            active_channel: nil,
            active_pm: nil,
            timezone: "Etc/UTC",
            identified: false,
            admin?: false,
            admin_only?: false,
            root_admin?: false

  @doc """
  Builds the context from a `Session` and the resolved timezone.
  """
  @spec from_session(Session.t(), String.t()) :: t()
  def from_session(%Session{} = session, timezone) when is_binary(timezone) do
    %__MODULE__{
      nickname: session.nickname,
      active_channel: session.active_channel,
      active_pm: session.active_pm,
      timezone: timezone,
      identified: session.identified,
      admin?: admin?(session),
      admin_only?: admin_only?(session),
      root_admin?: root_admin?(session)
    }
  end

  @doc """
  True when the viewer has any elevated server privilege (admin OR operator).

  This is the broad gate used to reveal admin-facing affordances.
  """
  @spec admin?(Session.t()) :: boolean()
  def admin?(%Session{} = session) do
    ServerRoles.admin?(session.nickname, session.identified) or
      ServerRoles.server_operator?(session.nickname, session.identified)
  end

  @doc """
  True only when the viewer is a full server admin (not merely an operator).
  """
  @spec admin_only?(Session.t()) :: boolean()
  def admin_only?(%Session{} = session) do
    ServerRoles.admin?(session.nickname, session.identified)
  end

  @doc """
  True when the viewer is an identified root admin (immutable `ROOT_ADMINS`).
  """
  @spec root_admin?(Session.t()) :: boolean()
  def root_admin?(%Session{} = session) do
    session.identified and ServerRoles.root_admin?(session.nickname)
  end
end
