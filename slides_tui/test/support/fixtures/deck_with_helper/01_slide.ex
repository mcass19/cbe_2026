defmodule SlidesTui.Test.Fixtures.DeckWithHelper.Slide do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Widgets.Paragraph

  def render(_state, area), do: [{%Paragraph{text: "slide"}, area}]
end
