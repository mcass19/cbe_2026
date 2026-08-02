defmodule SlidesTui.Test.Fixtures.DeckUnsorted.A do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Widgets.Paragraph

  def render(_state, area), do: [{%Paragraph{text: "a"}, area}]
end
