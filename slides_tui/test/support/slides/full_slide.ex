defmodule SlidesTui.Test.FullSlide do
  @moduledoc false
  use SlidesTui.Slide

  alias ExRatatui.Widgets.Paragraph

  def title, do: "Full"
  def notes, do: "# Full\n\nsome notes"

  def mount(opts) do
    {:ok, %{count: Keyword.get(opts, :start, 0)}}
  end

  def handle_event(_event, %{count: c} = state) do
    {:noreply, %{state | count: c + 1}}
  end

  def subscriptions(_state), do: [:tick]

  def render(state, area) do
    [{%Paragraph{text: "count: #{state.count}"}, area}]
  end
end
