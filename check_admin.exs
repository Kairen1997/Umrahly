# Check admin user
alias Umrahly.Repo
alias Umrahly.Accounts.User

admin_user = Repo.get_by(User, email: "admin@umrahly.com")
IO.inspect(admin_user, label: "Admin user")

if admin_user do
  IO.puts("Admin user found:")
  IO.puts("Email: #{admin_user.email}")
  IO.puts("Full name: #{admin_user.full_name}")
  IO.puts("Is admin: #{admin_user.is_admin}")
  IO.puts("Admin check result: #{Umrahly.Accounts.is_admin?(admin_user)}")
else
  IO.puts("Admin user not found!")
end
