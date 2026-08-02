defmodule SlidesTui.Test.Fixtures.DeckUnsorted.B do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Widgets.Paragraph

  def render(_state, area), do: [{%Paragraph{text: "b"}, area}]
end
