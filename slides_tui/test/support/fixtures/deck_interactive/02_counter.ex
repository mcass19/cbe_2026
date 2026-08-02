defmodule SlidesTui.Test.Fixtures.DeckInteractive.Counter do
  @moduledoc "Reads `:start` from host opts on mount, then increments on every event."
  use SlidesTui.Slide

  alias ExRatatui.Widgets.Paragraph

  def mount(opts), do: {:ok, %{count: Keyword.get(opts, :start, 0)}}

  def handle_event(_event, %{count: c} = state), do: {:noreply, %{state | count: c + 1}}

  def render(state, area), do: [{%Paragraph{text: "count: #{state.count}"}, area}]
end
