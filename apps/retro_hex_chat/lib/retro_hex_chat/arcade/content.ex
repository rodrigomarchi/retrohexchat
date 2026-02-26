defmodule RetroHexChat.Arcade.Content do
  @moduledoc """
  Facade for rich game content (descriptions, controls, tips).
  Each game's content lives in a separate module under `Content.*`.
  Returns structured data for HEEx rendering — no HTML generation.
  """

  alias RetroHexChat.Arcade.Content

  @type content :: %{
          about: [String.t()],
          controls: [{String.t(), String.t()}],
          tips: [String.t()]
        }

  @content_modules %{
    "doom_shareware" => Content.DoomShareware,
    "freedoom1" => Content.Freedoom1,
    "freedoom2" => Content.Freedoom2,
    "freedm" => Content.Freedm,
    "chex_quest" => Content.ChexQuest,
    "hacx" => Content.Hacx,
    "rekkr" => Content.Rekkr,
    "quake_shareware" => Content.QuakeShareware,
    "librequake" => Content.Librequake,
    "quake2_shareware" => Content.Quake2Shareware,
    "wolfenstein_3d" => Content.Wolfenstein3d,
    "halflife_uplink" => Content.HalflifeUplink,
    "scummvm_bass" => Content.ScummvmBass,
    "scummvm_drascula" => Content.ScummvmDrascula,
    "scummvm_dreamweb" => Content.ScummvmDreamweb,
    "scummvm_fotaq" => Content.ScummvmFotaq,
    "scummvm_lure" => Content.ScummvmLure,
    "scummvm_soltys" => Content.ScummvmSoltys
  }

  @spec get_content(String.t()) :: {:ok, content()} | {:error, :not_found}
  def get_content(game_id) do
    case Map.get(@content_modules, game_id) do
      nil -> {:error, :not_found}
      module -> {:ok, module.data()}
    end
  end

  @spec has_content?(String.t()) :: boolean()
  def has_content?(game_id), do: Map.has_key?(@content_modules, game_id)
end
