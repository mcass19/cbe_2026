defmodule SlidesTui.Test.Fixtures.DeckBasic.Demo do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Widgets.Paragraph

  def render(_state, area), do: [{%Paragraph{text: "demo"}, area}]
end
