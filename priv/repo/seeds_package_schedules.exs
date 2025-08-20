# Seeds for Package Schedules
alias Umrahly.Repo
alias Umrahly.Packages.PackageSchedule

# Get existing packages
packages = Repo.all(Umrahly.Packages.Package)

if length(packages) > 0 do
  # Create sample schedules for the first package
  first_package = List.first(packages)

  # Spring schedule
  %PackageSchedule{}
  |> PackageSchedule.changeset(%{
    package_id: first_package.id,
    departure_date: ~D[2026-03-15],
    return_date: ~D[2026-03-25],
    quota: 20,
    status: "active",
    notes: "Spring Umrah package"
  })
  |> Repo.insert!()

  # Summer schedule with price override
  %PackageSchedule{}
  |> PackageSchedule.changeset(%{
    package_id: first_package.id,
    departure_date: ~D[2026-06-20],
    return_date: ~D[2026-06-30],
    quota: 25,
    status: "active",
    price_override: 3500,
    notes: "Summer Umrah package with price adjustment"
  })
  |> Repo.insert!()

  # Autumn schedule
  %PackageSchedule{}
  |> PackageSchedule.changeset(%{
    package_id: first_package.id,
    departure_date: ~D[2026-09-10],
    return_date: ~D[2026-09-20],
    quota: 15,
    status: "active",
    notes: "Autumn Umrah package"
  })
  |> Repo.insert!()

  # If there's a second package, create schedules for it too
  if length(packages) > 1 do
    second_package = Enum.at(packages, 1)

    # April schedule
    %PackageSchedule{}
    |> PackageSchedule.changeset(%{
      package_id: second_package.id,
      departure_date: ~D[2026-04-01],
      return_date: ~D[2026-04-08],
      quota: 30,
      status: "active",
      notes: "Standard package April departure"
    })
    |> Repo.insert!()

    # July schedule
    %PackageSchedule{}
    |> PackageSchedule.changeset(%{
      package_id: second_package.id,
      departure_date: ~D[2026-07-15],
      return_date: ~D[2026-07-22],
      quota: 35,
      status: "active",
      notes: "Standard package July departure"
    })
    |> Repo.insert!()

    # October schedule (inactive)
    %PackageSchedule{}
    |> PackageSchedule.changeset(%{
      package_id: second_package.id,
      departure_date: ~D[2026-10-05],
      return_date: ~D[2026-10-12],
      quota: 25,
      status: "inactive",
      notes: "Standard package October departure - temporarily inactive"
    })
    |> Repo.insert!()
  end

  IO.puts("✅ Created sample package schedules!")
else
  IO.puts("⚠️  No packages found. Please run the main seeds first.")
end
