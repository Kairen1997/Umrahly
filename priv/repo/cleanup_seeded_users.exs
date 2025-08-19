# Script to cleanup incorrectly seeded users
alias Umrahly.Repo
import Ecto.Query

IO.puts("=== Cleaning up seeded users ===\n")

# List of emails to remove
emails_to_remove = [
  "admin@umrahly.com",
  "superadmin@umrahly.com",
  "john@example.com",
  "jane@example.com",
  "ahmed@example.com"
]

Enum.each(emails_to_remove, fn email ->
  query = from u in "users", where: u.email == ^email
  case Repo.delete_all(query) do
    {count, _} when count > 0 ->
      IO.puts("✅ Deleted #{count} user(s) with email: #{email}")
    {0, _} ->
      IO.puts("ℹ️  No users found with email: #{email}")
  end
end)

IO.puts("\nCleanup completed!")
