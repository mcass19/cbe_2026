defmodule SlidesTui.LayoutTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Layout.Rect
  alias SlidesTui.Layout

  @area %Rect{x: 0, y: 0, width: 80, height: 24}

  describe "center/2" do
    test "no opts returns the original area" do
      assert Layout.center(@area) == @area
    end

    test "centers vertically when only :height is given (full width preserved)" do
      assert Layout.center(@area, height: 4) == %Rect{x: 0, y: 10, width: 80, height: 4}
    end

    test "centers horizontally when only :width is given (full height preserved)" do
      assert Layout.center(@area, width: 40) == %Rect{x: 20, y: 0, width: 40, height: 24}
    end

    test "centers on both axes when :width and :height are given" do
      assert Layout.center(@area, width: 40, height: 4) ==
               %Rect{x: 20, y: 10, width: 40, height: 4}
    end

    test "clamps oversized dimensions to the area's own dims" do
      assert Layout.center(@area, width: 200, height: 200) == @area
    end

    test "preserves the area's origin offset" do
      offset = %Rect{x: 5, y: 7, width: 20, height: 10}

      assert Layout.center(offset, width: 10, height: 4) ==
               %Rect{x: 5 + 5, y: 7 + 3, width: 10, height: 4}
    end

    test "zero-sized requests collapse cleanly" do
      assert Layout.center(@area, width: 0, height: 0) == %Rect{x: 40, y: 12, width: 0, height: 0}
    end
  end
end
