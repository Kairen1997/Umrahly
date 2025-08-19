# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Umrahly.Repo.insert!(%Umrahly.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Umrahly.Accounts

# Create admin users
admin_users = [
  %{
    full_name: "Admin User",
    email: "admin@umrahly.com",
    password: "admin123456789",
    is_admin: true
  },
  %{
    full_name: "Super Admin",
    email: "superadmin@umrahly.com",
    password: "superadmin123456789",
    is_admin: true
  }
]

# Create regular users
regular_users = [
  %{
    full_name: "John Doe",
    email: "john@example.com",
    password: "user123456789",
    is_admin: false
  },
  %{
    full_name: "Jane Smith",
    email: "jane@example.com",
    password: "user123456789",
    is_admin: false
  },
  %{
    full_name: "Ahmed Hassan",
    email: "ahmed@example.com",
    password: "user123456789",
    is_admin: false
  }
]

# Insert admin users
Enum.each(admin_users, fn user_attrs ->
  case Accounts.register_user(user_attrs) do
    {:ok, user} ->
      # Confirm the user account
      {:ok, user} = Accounts.confirm_user_directly(user)
      IO.puts("Created admin user: #{user.email}")

    {:error, changeset} ->
      if String.contains?(inspect(changeset.errors), "has already been taken") do
        IO.puts("Admin user #{user_attrs.email} already exists, skipping...")
      else
        IO.puts("Failed to create admin user #{user_attrs.email}: #{inspect(changeset.errors)}")
      end
  end
end)

# Insert regular users
Enum.each(regular_users, fn user_attrs ->
  case Accounts.register_user(user_attrs) do
    {:ok, user} ->
      # Confirm the user account
      {:ok, user} = Accounts.confirm_user_directly(user)
      IO.puts("Created regular user: #{user.email}")

    {:error, changeset} ->
      if String.contains?(inspect(changeset.errors), "has already been taken") do
        IO.puts("Regular user #{user_attrs.email} already exists, skipping...")
      else
        IO.puts("Failed to create regular user #{user_attrs.email}: #{inspect(changeset.errors)}")
      end
  end
end)

IO.puts("\nSeeding completed!")
IO.puts("Admin users:")
IO.puts("- admin@umrahly.com (password: admin123456789)")
IO.puts("- superadmin@umrahly.com (password: superadmin123456789)")
IO.puts("\nRegular users:")
IO.puts("- john@example.com (password: user123456789)")
IO.puts("- jane@example.com (password: user123456789)")
IO.puts("- ahmed@example.com (password: user123456789)")
