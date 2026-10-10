defmodule SlidesTui.DeckTest do
  use ExUnit.Case, async: true

  alias SlidesTui.Deck
  alias SlidesTui.Test.Fixtures.DeckBasic
  alias SlidesTui.Test.Fixtures.DeckUnsorted
  alias SlidesTui.Test.Fixtures.DeckWithHelper

  describe "discover/1" do
    test "returns slide modules from a fixture directory in filename order" do
      modules = Deck.discover(pattern: "test/support/fixtures/deck_basic/*.ex")
      assert modules == [DeckBasic.Intro, DeckBasic.Overview, DeckBasic.Demo]
    end

    test "skips modules that don't implement SlidesTui.Slide" do
      modules = Deck.discover(pattern: "test/support/fixtures/deck_with_helper/*.ex")
      assert modules == [DeckWithHelper.Slide]
      refute DeckWithHelper.Helper in modules
    end

    test "sorts lexicographically — zero-padding governs order" do
      modules = Deck.discover(pattern: "test/support/fixtures/deck_unsorted/*.ex")
      # "02_a.ex" sorts before "10_b.ex" — without padding the order flips
      assert modules == [DeckUnsorted.A, DeckUnsorted.B]
    end

    test "files without a defmodule declaration are silently skipped" do
      modules = Deck.discover(pattern: "test/support/fixtures/deck_no_module/*.ex")
      assert modules == []
    end

    test "returns [] when the pattern matches nothing" do
      assert Deck.discover(pattern: "test/support/fixtures/nope_does_not_exist/*.ex") == []
    end

    test "uses lib/slides/*.ex as the default pattern (finds the talk deck)" do
      modules = Deck.discover()
      assert List.first(modules) == TuisEverywhere.Slides.Title
      assert List.last(modules) == TuisEverywhere.Slides.Thanks
      # every numbered file is a slide; the unnumbered ones are helpers
      assert length(modules) == length(Path.wildcard("lib/slides/[0-9]*.ex"))
    end

    test "the helpers next to the slides are not discovered as slides" do
      modules = Deck.discover()

      for helper <- [
            TuisEverywhere.Slides.Ui,
            TuisEverywhere.Slides.Rat,
            TuisEverywhere.Slides.Rocket
          ],
          do: refute(helper in modules)
    end
  end
end
