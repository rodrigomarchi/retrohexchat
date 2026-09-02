defmodule RetroHexChatWeb.ChatLive.WindowRegistryTest do
  @moduledoc """
  The invariants that used to be nobody's job.

  A window was previously described in five unconnected places, so it could be
  fully functional and still have no taskbar button — which is how the runtime
  windows shipped. These tests assert the connections that no code path
  enforced, so the same class of omission fails here instead of in front of a
  user.
  """

  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChatWeb.ChatLive.WindowRegistry, as: Registry

  describe "the registry itself" do
    test "every window has an id, a title and an icon" do
      for window <- Registry.windows() do
        assert is_binary(window.id) and window.id != ""
        assert is_binary(window.title) and window.title != ""
        assert is_atom(window.icon) and not is_nil(window.icon)
      end
    end

    test "ids are unique" do
      ids = Enum.map(Registry.windows(), & &1.id)

      assert ids == Enum.uniq(ids)
    end

    test "every icon is a real function on the Icons facade" do
      # `function_exported?/3` answers false for a module that has not been
      # loaded yet, which under lazy loading is every module the test has not
      # touched — so the check has to force the load first or it passes and
      # fails for reasons that have nothing to do with the registry.
      Code.ensure_loaded!(RetroHexChatWeb.Icons)

      for window <- Registry.windows() do
        assert function_exported?(RetroHexChatWeb.Icons, window.icon, 1),
               "#{window.id} names icon #{window.icon}, which the facade does not delegate"
      end
    end

    test "geometry never asks for less room than the window's own minimum" do
      for window <- Registry.windows() do
        %{width: width, height: height, min_width: min_width, min_height: min_height} =
          window.geometry

        assert width >= min_width, "#{window.id} opens narrower than it can be resized to"

        assert is_nil(height) or height >= min_height,
               "#{window.id} opens shorter than it can be resized to"
      end
    end
  end

  describe "the connections that used to be unchecked" do
    test "every window that can be opened by an event is reachable on the taskbar" do
      # This is the one that would have caught the runtime windows: they had
      # openers, they rendered, they focused — and no button existed to restore
      # them once minimised.
      for window <- Registry.windows(), window.opener do
        refute window.taskbar_when == :never,
               "#{window.id} can be opened but never appears on the taskbar"
      end
    end

    test "every opener is unique to one window" do
      openers = Registry.openers()

      assert map_size(openers) == openers |> Map.values() |> Enum.uniq() |> length()
    end

    test "an admin-gated window is admin-gated on the taskbar too" do
      # A privileged window listed on a non-admin's taskbar would leak both its
      # existence and its title.
      for window <- Registry.windows(), window.render_when == :admin do
        assert window.taskbar_when == :admin,
               "#{window.id} renders behind the admin gate but is listed without it"
      end
    end

    test "managed_ids covers exactly the windows the server owns" do
      expected = for window <- Registry.windows(), window.managed?, do: window.id

      assert Enum.sort(Registry.managed_ids()) == Enum.sort(expected)
    end

    test "a window the server does not manage is always rendered or driven by an assign" do
      # An unmanaged window is always in the DOM, so gating it on `:open` would
      # mean it renders while closed and never opens.
      for window <- Registry.windows(), not window.managed? do
        assert window.render_when in [:always] or match?({:present, _}, window.render_when),
               "#{window.id} is unmanaged but gated on being open"
      end
    end
  end

  describe "attrs/1" do
    test "carries everything desktop_window needs" do
      attrs = Registry.attrs("admin-users")

      assert attrs.id == "admin-users"
      assert attrs.managed == true
      assert attrs.width > 0
      assert attrs.min_width > 0
    end

    test "arcade opens large enough for game details" do
      attrs = Registry.attrs("arcade-games")

      assert attrs.width >= 960
      assert attrs.height >= 640
      assert attrs.min_width >= 720
      assert attrs.min_height >= 500
    end

    test "refuses an unknown id loudly rather than rendering a blank window" do
      assert_raise ArgumentError, fn -> Registry.attrs("no-such-window") end
    end
  end

  describe "on_taskbar?/2" do
    test "an always-listed window needs nothing" do
      chat = Registry.fetch("chat")

      assert Registry.on_taskbar?(chat, %{open_windows: MapSet.new()})
    end

    test "an open-gated window is listed only while open" do
      timers = Registry.fetch("timers")

      refute Registry.on_taskbar?(timers, %{open_windows: MapSet.new()})
      assert Registry.on_taskbar?(timers, %{open_windows: MapSet.new(["timers"])})
    end

    test "an admin window needs both the role and the window open" do
      users = Registry.fetch("admin-users")
      open = MapSet.new(["admin-users"])

      refute Registry.on_taskbar?(users, %{admin?: false, open_windows: open})
      refute Registry.on_taskbar?(users, %{admin?: true, open_windows: MapSet.new()})
      assert Registry.on_taskbar?(users, %{admin?: true, open_windows: open})
    end

    test "a session window is listed on the session alone, with no open flag" do
      arcade = Registry.fetch("arcade-games")

      refute Registry.on_taskbar?(arcade, %{
               arcade_session: nil,
               open_windows: MapSet.new(["arcade-games"])
             })

      assert Registry.on_taskbar?(arcade, %{
               arcade_session: %{},
               open_windows: MapSet.new(["arcade-games"])
             })
    end
  end

  describe "translation" do
    test "titles resolve against the caller's locale, not the compiler's" do
      # A dgettext evaluated inside a module attribute is executed at compile
      # time and freezes whatever locale built the release. That had happened
      # to the admin taskbar labels, which read English in all thirteen
      # locales. Reading the list twice under different locales is what proves
      # the list is a function and stays one.
      Gettext.put_locale(RetroHexChatWeb.Gettext, "en")
      english = Enum.map(Registry.windows(), & &1.title)

      Gettext.put_locale(RetroHexChatWeb.Gettext, "pt_BR")
      portuguese = Enum.map(Registry.windows(), & &1.title)

      Gettext.put_locale(RetroHexChatWeb.Gettext, "en")

      assert english != portuguese,
             "no title changed with the locale — the registry has been frozen at compile time"
    end
  end
end
