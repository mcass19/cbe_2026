defmodule SlidesTui.ThemeTest do
  use ExUnit.Case, async: true

  alias SlidesTui.Theme

  describe "lookup" do
    test "dracula is the default and comes first" do
      assert Theme.default() == :dracula
      assert hd(Theme.names()) == :dracula
      assert Theme.names() == [:dracula, :midnight, :daylight]
    end

    test "fetch!/1 returns the named struct and raises on anything else" do
      assert %Theme{name: :daylight, code_theme: :base16_ocean_light} = Theme.fetch!(:daylight)
      assert_raise ArgumentError, ~r/unknown theme :neon/, fn -> Theme.fetch!(:neon) end
    end

    test "next/1 cycles through every theme and wraps" do
      assert Theme.next(:dracula) == :midnight
      assert Theme.next(:midnight) == :daylight
      assert Theme.next(:daylight) == :dracula
      # an unknown name restarts the cycle rather than crashing
      assert Theme.next(:neon) == :dracula
    end

    test "parse/1 accepts theme names only" do
      assert Theme.parse("midnight") == {:ok, :midnight}
      assert Theme.parse("neon") == :error
    end
  end

  describe "the active theme" do
    test "falls back to the default outside a host, follows put/1 inside one" do
      Process.delete({Theme, :current})
      assert Theme.current().name == :dracula

      assert :ok = Theme.put(:daylight)
      assert Theme.current().name == :daylight
    end
  end

  describe "contrast/2" do
    test "spans 1.0 for identical colours to 21.0 for black on white" do
      black = {:rgb, 0, 0, 0}
      white = {:rgb, 255, 255, 255}

      assert_in_delta Theme.contrast(white, white), 1.0, 0.001
      assert_in_delta Theme.contrast(black, white), 21.0, 0.001
      assert Theme.contrast(black, white) == Theme.contrast(white, black)
    end
  end

  # WCAG: 4.5 for text people read, 3.0 for chrome and the quietest
  # secondary text. Every theme has to clear both on its own ground, so
  # a palette tweak can't quietly ship something the back row can't read.
  for name <- Theme.names() do
    test "#{name} keeps readable contrast on its ground" do
      theme = Theme.fetch!(unquote(name))

      for role <- [:text, :subtle, :violet, :cyan] do
        ratio = Theme.contrast(Map.fetch!(theme, role), theme.ground)
        assert ratio >= 4.5, "#{role} on ground is #{Float.round(ratio, 2)}:1"
      end

      for role <- [:accent, :muted] do
        ratio = Theme.contrast(Map.fetch!(theme, role), theme.ground)
        assert ratio >= 3.0, "#{role} on ground is #{Float.round(ratio, 2)}:1"
      end

      assert Theme.contrast(theme.chip_fg, theme.chip_bg) >= 4.5
    end
  end
end
