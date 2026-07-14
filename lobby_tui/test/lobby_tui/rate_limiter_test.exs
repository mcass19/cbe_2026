defmodule LobbyTui.RateLimiterTest do
  use ExUnit.Case, async: false

  alias LobbyTui.RateLimiter

  test "allows 6 in a minute window, refuses the 7th, resets next window" do
    id = "attendee_#{System.unique_integer([:positive])}"
    now = 1_000_000

    for _ <- 1..6, do: assert(RateLimiter.within_limit?(id, now))
    refute RateLimiter.within_limit?(id, now + 30)
    assert RateLimiter.within_limit?(id, now + 60)
  end

  test "attendees are limited independently" do
    a = "a_#{System.unique_integer([:positive])}"
    b = "b_#{System.unique_integer([:positive])}"
    now = 2_000_000
    for _ <- 1..6, do: RateLimiter.within_limit?(a, now)
    refute RateLimiter.within_limit?(a, now)
    assert RateLimiter.within_limit?(b, now)
  end
end
