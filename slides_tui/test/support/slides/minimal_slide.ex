defmodule SlidesTui.Test.MinimalSlide do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Widgets.Paragraph

  def render(_state, area) do
    [{%Paragraph{text: "minimal"}, area}]
  end
end
