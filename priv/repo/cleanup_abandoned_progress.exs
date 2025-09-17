# Run with: mix run priv/repo/cleanup_abandoned_progress.exs

Mix.Task.run("app.start")

{count, _} = Umrahly.Bookings.delete_abandoned_booking_progress()

IO.puts("Deleted #{count} abandoned booking progress record(s).")
