defmodule RetroHexChat.Accounts.NicknameValidator do
  @moduledoc """
  Validates IRC nicknames per RFC 2812 rules adapted for RetroHexChat.
  Max 16 chars, starts with letter or special, no spaces.
  """
  use Gettext, backend: RetroHexChat.Gettext

  @max_length 16
  # IRC first-character specials: [ ] \ ^ _ { | }
  @first_char_specials ~c"[]\\^_{|}"
  @valid_nick_pattern ~r/^[a-zA-Z\[\]\\^_\{|\}][a-zA-Z0-9\[\]\\^_`\{|\}\-]*$/

  @spec valid?(String.t()) :: boolean()
  def valid?(nickname) when is_binary(nickname) do
    byte_size(nickname) >= 1 and
      byte_size(nickname) <= @max_length and
      valid_first_char?(nickname) and
      no_spaces?(nickname) and
      valid_characters?(nickname)
  end

  def valid?(_), do: false

  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(nickname) do
    cond do
      not is_binary(nickname) ->
        {:error, dgettext("accounts", "Nickname must be a string")}

      byte_size(nickname) == 0 ->
        {:error, dgettext("accounts", "Nickname cannot be empty")}

      byte_size(nickname) > @max_length ->
        {:error, "Nickname must be at most #{@max_length} characters"}

      not valid_first_char?(nickname) ->
        {:error, dgettext("accounts", "Nickname must start with a letter or special character")}

      not no_spaces?(nickname) ->
        {:error, dgettext("accounts", "Nickname cannot contain spaces")}

      not valid_characters?(nickname) ->
        {:error, dgettext("accounts", "Nickname contains invalid characters")}

      true ->
        :ok
    end
  end

  @spec valid_first_char?(String.t()) :: boolean()
  defp valid_first_char?(<<char, _rest::binary>>) do
    char in ?a..?z or char in ?A..?Z or char in @first_char_specials
  end

  @spec no_spaces?(String.t()) :: boolean()
  defp no_spaces?(nickname), do: not String.contains?(nickname, " ")

  @spec valid_characters?(String.t()) :: boolean()
  defp valid_characters?(nickname), do: Regex.match?(@valid_nick_pattern, nickname)
end
