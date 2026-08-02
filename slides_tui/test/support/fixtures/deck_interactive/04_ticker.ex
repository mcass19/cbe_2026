defmodule SlidesTui.Test.Fixtures.DeckInteractive.Ticker do
  @moduledoc "Subscribes to a 50ms tick and counts firings."
  use SlidesTui.Slide

  alias ExRatatui.Subscription
  alias ExRatatui.Widgets.Paragraph

  def mount(_opts), do: {:ok, %{ticks: 0}}

  def subscriptions(_state), do: [Subscription.interval(:tick, 50, :tick)]

  def handle_info(:tick, %{ticks: t} = state), do: {:noreply, %{state | ticks: t + 1}}

  def render(state, area), do: [{%Paragraph{text: "ticks: #{state.ticks}"}, area}]
end
