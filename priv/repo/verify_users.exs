# Script to verify user roles in the database
alias Umrahly.Repo
import Ecto.Query

IO.puts("=== User Role Verification ===\n")

# Get all users directly from the database
users = Repo.all(from u in "users", select: {u.id, u.email, u.is_admin, u.confirmed_at}, order_by: u.id)

IO.puts("All users:")
IO.puts("ID | Email                           | Role  | Status")
IO.puts("---|--------------------------------|-------|-----------")

Enum.each(users, fn {id, email, is_admin, confirmed_at} ->
  role = if is_admin, do: "ADMIN", else: "USER"
  status = if confirmed_at, do: "CONFIRMED", else: "UNCONFIRMED"

  IO.puts("#{String.pad_leading(to_string(id), 2)} | #{String.pad_trailing(email, 30)} | #{String.pad_trailing(role, 5)} | #{status}")
end)

IO.puts("\n=== Summary ===")
IO.puts("Total users: #{length(users)}")
admin_count = Enum.count(users, fn {_id, _email, is_admin, _confirmed_at} -> is_admin end)
user_count = length(users) - admin_count

IO.puts("Admin users: #{admin_count}")
IO.puts("Regular users: #{user_count}")

# Check for our seeded users specifically
seeded_emails = [
  "admin@umrahly.com",
  "superadmin@umrahly.com",
  "john@example.com",
  "jane@example.com",
  "ahmed@example.com"
]

IO.puts("\n=== Seeded Users ===")
Enum.each(seeded_emails, fn email ->
  query = from u in "users", where: u.email == ^email, select: {u.email, u.is_admin, u.confirmed_at}
  case Repo.one(query) do
    nil ->
      IO.puts("❌ #{email} - NOT FOUND")
    {_email, is_admin, confirmed_at} ->
      role = if is_admin, do: "ADMIN", else: "USER"
      status = if confirmed_at, do: "CONFIRMED", else: "UNCONFIRMED"
      IO.puts("✅ #{email} - #{role} (#{status})")
  end
end)
