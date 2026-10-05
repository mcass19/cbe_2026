# Logs only show for failing tests: OTP ssh logs a debug line per
# connection in the presenter daemon test.
ExUnit.start(capture_log: true)
