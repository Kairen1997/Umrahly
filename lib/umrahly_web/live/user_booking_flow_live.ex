defmodule UmrahlyWeb.UserBookingFlowLive do
@moduledoc """
LiveView for handling the user booking flow.

## Payment Gateway Integration

This module includes implementations for payment gateway integration.
The following payment methods are supported:

1. **ToyyibPay Integration** (for FPX and Credit Card payments)
  - Set environment variables: TOYYIBPAY_USER_SECRET_KEY, TOYYIBPAY_CATEGORY_CODE
  - Configure redirect and callback URIs

2. **Bank Transfer & Cash**
  - These are handled as offline payment methods
  - No immediate redirection required

## Environment Variables Required

```bash
# ToyyibPay
export TOYYIBPAY_USER_SECRET_KEY=your_secret_key
export TOYYIBPAY_CATEGORY_CODE=your_category_code
export TOYYIBPAY_REDIRECT_URI=https://yourdomain.com/payment/return
export TOYYIBPAY_CALLBACK_URI=https://yourdomain.com/payment/callback
export TOYYIBPAY_SANDBOX=true

# Generic Payment Gateway
export PAYMENT_GATEWAY_URL=https://your-gateway.com
export PAYMENT_MERCHANT_ID=your_merchant_id
export PAYMENT_API_KEY=your_api_key
```
"""

use UmrahlyWeb, :live_view

import UmrahlyWeb.SidebarComponent
alias Umrahly.Bookings
alias Umrahly.Bookings.Booking
alias Umrahly.Packages

on_mount {UmrahlyWeb.UserAuth, :mount_current_user}


  def mount(%{"package_id" => package_id, "schedule_id" => schedule_id} = params, _session, socket) do
    user_id = socket.assigns.current_user.id
    package = Packages.get_package!(package_id)
    schedule = Packages.get_package_schedule!(schedule_id)
    has_price_override = schedule.price_override && Decimal.gt?(schedule.price_override, Decimal.new(0))
    is_resume = Map.get(params, "resume") == "true"
    progress = Bookings.get_or_create_booking_flow_progress(user_id, package_id, schedule_id)
    if schedule.package_id != String.to_integer(package_id) do
      {:noreply,
       socket
       |> put_flash(:error, "Invalid package schedule selected")
       |> push_navigate(to: ~p"/packages/#{package_id}")}
    else
      base_price = package.price
      override_price = if schedule.price_override, do: Decimal.to_integer(schedule.price_override), else: 0
      schedule_price_per_person = base_price + override_price
      changeset = Bookings.change_booking(%Booking{})
      travelers = cond do
        is_resume && progress.travelers_data && length(progress.travelers_data) > 0 ->
          all_travelers = progress.travelers_data
          all_travelers
        progress.travelers_data && length(progress.travelers_data) > 0 ->
          progress.travelers_data
        progress.is_booking_for_self ->
          Enum.map(1..progress.number_of_persons, fn index ->
            if index == 1 do
              %{
                "full_name" => socket.assigns.current_user.full_name || "",
                "identity_card_number" => socket.assigns.current_user.identity_card_number || "",
                "passport_number" => socket.assigns.current_user.passport_number || "",
                "phone" => socket.assigns.current_user.phone_number || "",
                "date_of_birth" => case socket.assigns.current_user.birthdate do
                  nil -> ""
                  birthdate -> Date.to_string(birthdate)
                end,
                "address" => socket.assigns.current_user.address || "",
                "poskod" => socket.assigns.current_user.poskod || "",
                "city" => socket.assigns.current_user.city || "",
                "state" => socket.assigns.current_user.state || "",
                "citizenship" => socket.assigns.current_user.citizenship || "",
                "emergency_contact_name" => socket.assigns.current_user.emergency_contact_name || "",
                "emergency_contact_phone" => socket.assigns.current_user.emergency_contact_phone || "",
                "emergency_contact_relationship" => socket.assigns.current_user.emergency_contact_relationship || "",
                "room_type" => "standard"
              }
            else
              %{
                "full_name" => "",
                "identity_card_number" => "",
                "passport_number" => "",
                "phone" => "",
                "date_of_birth" => "",
                "address" => "",
                "poskod" => "",
                "city" => "",
                "state" => "",
                "citizenship" => "",
                "emergency_contact_name" => "",
                "emergency_contact_phone" => "",
                "emergency_contact_relationship" => "",
                "room_type" => "standard"
              }
            end
          end)
        true ->
          Enum.map(1..progress.number_of_persons, fn _ ->
            %{
              "full_name" => "",
              "identity_card_number" => "",
              "passport_number" => "",
              "phone" => "",
              "date_of_birth" => "",
              "address" => "",
              "poskod" => "",
              "city" => "",
              "state" => "",
              "citizenship" => "",
              "emergency_contact_name" => "",
              "emergency_contact_phone" => "",
              "emergency_contact_relationship" => "",
              "room_type" => "standard"
            }
          end)
        end

      actual_number_of_persons = length(travelers)

      total_amount = Decimal.mult(Decimal.new(schedule_price_per_person), Decimal.new(actual_number_of_persons))

              saved_payment_progress = has_payment_progress?(progress)
              deposit_amount = if progress.deposit_amount do
                progress.deposit_amount
              else
                total_amount
              end

              socket =
          socket
          |> assign(:package, package)
          |> assign(:schedule, schedule)
          |> assign(:has_price_override, has_price_override)
          |> assign(:price_per_person, schedule_price_per_person)
          |> assign(:total_amount, total_amount)
          |> assign(:payment_plan, progress.payment_plan || "full_payment")
          |> assign(:deposit_amount, deposit_amount)
          |> assign(:number_of_persons, actual_number_of_persons)
          |> assign(:travelers, travelers)
        |> assign(:is_booking_for_self, progress.is_booking_for_self)
        |> assign(:payment_method, progress.payment_method || "")
        |> assign(:notes, progress.notes || "")
        |> assign(:changeset, changeset)
        |> assign(:current_page, "packages")
        |> assign(:page_title, "Book Package")
        |> assign(:current_step, progress.current_step)
        |> assign(:max_steps, 5)
        |> assign(:requires_online_payment, false)
        |> assign(:payment_gateway_url, nil)
        |> assign(:payment_proof_file, nil)
        |> assign(:payment_proof_notes, "")
        |> assign(:show_payment_proof_form, false)
        |> assign(:current_booking_id, nil)  # Initialize as nil
        |> assign(:saved_package_progress, nil)
        |> assign(:saved_travelers_progress, nil)
        |> assign(:saved_payment_progress, saved_payment_progress)
        |> assign(:booking_flow_progress, progress)
        |> allow_upload(:payment_proof, accept: ~w(.pdf .jpg .jpeg .png .doc .docx), max_entries: 1, max_file_size: 5_000_000)

      # Optionally jump straight to success (payment proof) when requested
      socket = case Map.get(params, "jump_to") do
        "success" -> assign(socket, :current_step, 5)
        _ -> socket
      end

      {:ok, socket}
    end
  end

  def handle_event("validate_booking", %{"booking" => booking_params}, socket) do
    number_of_persons = String.to_integer(booking_params["number_of_persons"] || "1")
    payment_plan = booking_params["payment_plan"] || "full_payment"

    travelers = case booking_params["travelers"] do
      nil ->
        socket.assigns.travelers
      travelers_params ->
        current_count = length(travelers_params)
        if number_of_persons > current_count do
          additional_travelers = Enum.map((current_count + 1)..number_of_persons, fn _ ->
            %{
              "full_name" => "",
              "identity_card_number" => "",
              "passport_number" => "",
              "phone" => "",
              "date_of_birth" => "",
              "address" => "",
              "poskod" => "",
              "city" => "",
              "state" => "",
              "citizenship" => "",
              "emergency_contact_name" => "",
              "emergency_contact_phone" => "",
              "emergency_contact_relationship" => "",
              "room_type" => "standard"
            }
          end)
          mapped_travelers = Enum.map(travelers_params, fn traveler ->
            %{
              "full_name" => traveler["full_name"] || "",
              "identity_card_number" => traveler["identity_card_number"] || "",
              "passport_number" => traveler["passport_number"] || "",
              "phone" => traveler["phone"] || "",
              "date_of_birth" => traveler["date_of_birth"] || "",
              "address" => traveler["address"] || "",
              "poskod" => traveler["poskod"] || "",
              "city" => traveler["city"] || "",
              "state" => traveler["state"] || "",
              "citizenship" => traveler["citizenship"] || "",
              "emergency_contact_name" => traveler["emergency_contact_name"] || "",
              "emergency_contact_phone" => traveler["emergency_contact_phone"] || "",
              "emergency_contact_relationship" => traveler["emergency_contact_relationship"] || "",
              "room_type" => traveler["room_type"] || "standard"
            }
          end)

          all_travelers = mapped_travelers ++ additional_travelers

        final_travelers = if socket.assigns.is_booking_for_self and length(all_travelers) > 0 do
          first_traveler = List.first(all_travelers)
          updated_first_traveler = Map.put(first_traveler, "address", socket.assigns.current_user.address || "")
          [updated_first_traveler] ++ List.delete_at(all_travelers, 0)
        else
          all_travelers
        end

          final_travelers
        else
          taken_travelers = Enum.take(Enum.map(travelers_params, fn traveler ->
            %{
              "full_name" => traveler["full_name"] || "",
              "identity_card_number" => traveler["identity_card_number"] || "",
              "passport_number" => traveler["passport_number"] || "",
              "phone" => traveler["phone"] || "",
              "date_of_birth" => traveler["date_of_birth"] || "",
              "address" => traveler["address"] || "",
              "poskod" => traveler["poskod"] || "",
              "city" => traveler["city"] || "",
              "state" => traveler["state"] || "",
              "citizenship" => traveler["citizenship"] || "",
              "emergency_contact_name" => traveler["emergency_contact_name"] || "",
              "emergency_contact_phone" => traveler["emergency_contact_phone"] || "",
              "emergency_contact_relationship" => traveler["emergency_contact_relationship"] || "",
              "room_type" => traveler["room_type"] || "standard"
            }
          end), number_of_persons)

          final_travelers = if socket.assigns.is_booking_for_self and length(taken_travelers) > 0 do
            first_traveler = List.first(taken_travelers)
            updated_first_traveler = Map.merge(first_traveler, %{
              "full_name" => socket.assigns.current_user.full_name || "",
              "identity_card_number" => socket.assigns.current_user.identity_card_number || "",
              "passport_number" => socket.assigns.current_user.passport_number || "",
              "phone" => socket.assigns.current_user.phone_number || "",
              "date_of_birth" => case socket.assigns.current_user.birthdate do
                nil -> ""
                birthdate -> Date.to_string(birthdate)
              end,
              "address" => socket.assigns.current_user.address || "",
              "poskod" => socket.assigns.current_user.poskod || "",
              "city" => socket.assigns.current_user.city || "",
              "state" => socket.assigns.current_user.state || "",
              "citizenship" => socket.assigns.current_user.citizenship || "",
              "emergency_contact_name" => socket.assigns.current_user.emergency_contact_name || "",
              "emergency_contact_phone" => socket.assigns.current_user.emergency_contact_phone || "",
              "emergency_contact_relationship" => socket.assigns.current_user.emergency_contact_relationship || ""
            })
            [updated_first_traveler] ++ List.delete_at(taken_travelers, 0)
          else
            taken_travelers
          end

          final_travelers
        end
    end

    package_price = socket.assigns.package.price
    base_price = package_price
    override_price = if socket.assigns.schedule.price_override, do: Decimal.to_integer(socket.assigns.schedule.price_override), else: 0
    schedule_price_per_person = base_price + override_price

    total_amount = Decimal.mult(Decimal.new(schedule_price_per_person), Decimal.new(number_of_persons))

        deposit_amount = case payment_plan do
      "full_payment" -> total_amount
      "installment" ->
        deposit_input = booking_params["deposit_amount"] || "0"
        try do
          Decimal.new(deposit_input)
        rescue
          _ -> Decimal.mult(total_amount, Decimal.new("0.2"))
        end
    end


    attrs = %{
      total_amount: total_amount,
      deposit_amount: deposit_amount,
      number_of_persons: number_of_persons,
      payment_method: booking_params["payment_method"],
      payment_plan: payment_plan,
      notes: booking_params["notes"] || "",
      user_id: socket.assigns.current_user.id,
      package_schedule_id: socket.assigns.schedule.id,
      status: "pending",
      booking_date: Date.utc_today()
    }

    changeset =
      %Booking{}
      |> Bookings.change_booking(attrs)
      |> Map.put(:action, :validate)

    {_ok, progress} = Bookings.update_booking_flow_progress(
      socket.assigns.booking_flow_progress,
      %{
        payment_method: booking_params["payment_method"],
        payment_plan: payment_plan,
        deposit_amount: deposit_amount,
        notes: booking_params["notes"] || "",
        last_updated: DateTime.utc_now()
      }
    )

    socket =
      socket
      |> assign(:total_amount, total_amount)
      |> assign(:deposit_amount, deposit_amount)
      |> assign(:number_of_persons, number_of_persons)
      |> assign(:travelers, travelers)
      |> assign(:payment_method, booking_params["payment_method"])
      |> assign(:payment_plan, payment_plan)
      |> assign(:notes, booking_params["notes"] || "")
      |> assign(:changeset, changeset)
      |> assign(:booking_flow_progress, progress)

    {:noreply, socket}
  end


  def handle_event("toggle_booking_for_self", _params, socket) do
    current_is_booking_for_self = socket.assigns.is_booking_for_self
    new_is_booking_for_self = !current_is_booking_for_self
    travelers = if new_is_booking_for_self do
      [%{
        "full_name" => socket.assigns.current_user.full_name || "",
        "identity_card_number" => socket.assigns.current_user.identity_card_number || "",
        "passport_number" => socket.assigns.current_user.passport_number || "",
        "phone" => socket.assigns.current_user.phone_number || "",
        "date_of_birth" => case socket.assigns.current_user.birthdate do
          nil -> ""
          birthdate -> Date.to_string(birthdate)
        end,
        "address" => socket.assigns.current_user.address || "",
        "poskod" => socket.assigns.current_user.poskod || "",
        "city" => socket.assigns.current_user.city || "",
        "state" => socket.assigns.current_user.state || "",
          "citizenship" => socket.assigns.current_user.citizenship || "",
        "emergency_contact_name" => socket.assigns.current_user.emergency_contact_name || "",
        "emergency_contact_phone" => socket.assigns.current_user.emergency_contact_phone || "",
        "emergency_contact_relationship" => socket.assigns.current_user.emergency_contact_relationship || "",
        "room_type" => "standard"
      }]
    else
      [%{
        "full_name" => "",
        "identity_card_number" => "",
        "passport_number" => "",
        "phone" => "",
        "date_of_birth" => "",
        "address" => "",
        "poskod" => "",
        "city" => "",
        "state" => "",
        "citizenship" => "",
        "emergency_contact_name" => "",
        "emergency_contact_phone" => "",
        "emergency_contact_relationship" => "",
        "room_type" => "standard"
      }]
    end
    final_travelers = if new_is_booking_for_self and socket.assigns.number_of_persons > 1 do
      first_traveler = List.first(travelers)
      additional_travelers = Enum.map(2..socket.assigns.number_of_persons, fn _ ->
        %{
          "full_name" => "",
          "identity_card_number" => "",
          "passport_number" => "",
          "phone" => "",
          "date_of_birth" => "",
          "address" => "",
          "poskod" => "",
          "city" => "",
          "state" => "",
          "citizenship" => "",
          "emergency_contact_name" => "",
          "emergency_contact_phone" => "",
          "emergency_contact_relationship" => "",
          "room_type" => "standard"
        }
      end)
      [first_traveler] ++ additional_travelers
    else
      travelers
    end
    {_ok, progress} = Bookings.update_booking_flow_progress(
      socket.assigns.booking_flow_progress,
      %{
        travelers_data: final_travelers,
        is_booking_for_self: new_is_booking_for_self,
        last_updated: DateTime.utc_now()
      }
    )

    socket =
      socket
      |> assign(:is_booking_for_self, new_is_booking_for_self)
      |> assign(:travelers, final_travelers)
      |> assign(:booking_flow_progress, progress)

    {:noreply, socket}
  end

    def handle_event("update_number_of_persons", %{"action" => "increase"}, socket) do
    current_number = socket.assigns.number_of_persons
    new_number = min(current_number + 1, 10)

    existing_travelers = socket.assigns.travelers
    travelers = if new_number > current_number do
      additional_travelers = Enum.map((current_number + 1)..new_number, fn _index ->
        %{
          "full_name" => "",
          "identity_card_number" => "",
          "passport_number" => "",
          "phone" => "",
          "date_of_birth" => "",
          "address" => "",
          "poskod" => "",
          "city" => "",
          "state" => "",
          "citizenship" => "",
          "emergency_contact_name" => "",
          "emergency_contact_phone" => "",
          "emergency_contact_relationship" => "",
          "room_type" => "standard"
        }
      end)

      new_travelers = existing_travelers ++ additional_travelers

      final_travelers = if socket.assigns.is_booking_for_self and length(new_travelers) > 0 do
        first_traveler = List.first(new_travelers)
        updated_first_traveler = Map.merge(first_traveler, %{
          "full_name" => socket.assigns.current_user.full_name || "",
          "identity_card_number" => socket.assigns.current_user.identity_card_number || "",
          "passport_number" => socket.assigns.current_user.passport_number || "",
          "phone" => socket.assigns.current_user.phone_number || "",
          "date_of_birth" => case socket.assigns.current_user.birthdate do
            nil -> ""
            birthdate -> Date.to_string(birthdate)
          end,
          "address" => socket.assigns.current_user.address || "",
          "poskod" => socket.assigns.current_user.poskod || "",
          "city" => socket.assigns.current_user.city || "",
          "state" => socket.assigns.current_user.state || "",
          "citizenship" => socket.assigns.current_user.citizenship || "",
          "emergency_contact_name" => socket.assigns.current_user.emergency_contact_name || "",
          "emergency_contact_phone" => socket.assigns.current_user.emergency_contact_phone || "",
          "emergency_contact_relationship" => socket.assigns.current_user.emergency_contact_relationship || ""
        })
        [updated_first_traveler] ++ List.delete_at(new_travelers, 0)
      else
        new_travelers
      end



      final_travelers
    else
      existing_travelers
    end

    package_price = socket.assigns.package.price
    base_price = package_price
    override_price = if socket.assigns.schedule.price_override, do: Decimal.to_integer(socket.assigns.schedule.price_override), else: 0
    schedule_price_per_person = base_price + override_price

    total_amount = Decimal.mult(Decimal.new(schedule_price_per_person), Decimal.new(new_number))

    deposit_amount = if socket.assigns.payment_plan == "installment" do
      Decimal.mult(total_amount, Decimal.new("0.2"))
    else
      total_amount
    end

    socket =
      socket
      |> assign(:number_of_persons, new_number)
      |> assign(:travelers, travelers)
      |> assign(:total_amount, total_amount)
      |> assign(:deposit_amount, deposit_amount)

    {:noreply, socket}
  end

  def handle_event("update_number_of_persons", %{"action" => "decrease"}, socket) do
    current_number = socket.assigns.number_of_persons
    new_number = max(current_number - 1, 1)

    existing_travelers = socket.assigns.travelers
    travelers = if new_number < current_number do
      taken_travelers = Enum.take(existing_travelers, new_number)

      final_travelers = if socket.assigns.is_booking_for_self and length(taken_travelers) > 0 do
        first_traveler = List.first(taken_travelers)
        updated_first_traveler = Map.merge(first_traveler, %{
          "full_name" => socket.assigns.current_user.full_name || "",
          "identity_card_number" => socket.assigns.current_user.identity_card_number || "",
          "passport_number" => socket.assigns.current_user.passport_number || "",
          "phone" => socket.assigns.current_user.phone_number || "",
          "date_of_birth" => case socket.assigns.current_user.birthdate do
            nil -> ""
            birthdate -> Date.to_string(birthdate)
          end,
          "address" => socket.assigns.current_user.address || "",
          "poskod" => socket.assigns.current_user.poskod || "",
          "city" => socket.assigns.current_user.city || "",
          "state" => socket.assigns.current_user.state || "",
          "citizenship" => socket.assigns.current_user.citizenship || "",
          "emergency_contact_name" => socket.assigns.current_user.emergency_contact_name || "",
          "emergency_contact_phone" => socket.assigns.current_user.emergency_contact_phone || "",
          "emergency_contact_relationship" => socket.assigns.current_user.emergency_contact_relationship || ""
        })
        [updated_first_traveler] ++ List.delete_at(taken_travelers, 0)
      else
        taken_travelers
      end

      final_travelers
    else
      existing_travelers
    end

    package_price = socket.assigns.package.price
    base_price = package_price
    override_price = if socket.assigns.schedule.price_override, do: Decimal.to_integer(socket.assigns.schedule.price_override), else: 0
    schedule_price_per_person = base_price + override_price

    total_amount = Decimal.mult(Decimal.new(schedule_price_per_person), Decimal.new(new_number))

    deposit_amount = if socket.assigns.payment_plan == "installment" do
      Decimal.mult(total_amount, Decimal.new("0.2"))
    else
      total_amount
    end

    socket =
      socket
      |> assign(:number_of_persons, new_number)
      |> assign(:travelers, travelers)
      |> assign(:total_amount, total_amount)
      |> assign(:deposit_amount, deposit_amount)

    {:noreply, socket}
  end

  def handle_event("update_payment_plan", %{"payment_plan" => payment_plan}, socket) do
    deposit_amount = case payment_plan do
      "full_payment" -> socket.assigns.total_amount
      "installment" ->
        Decimal.mult(socket.assigns.total_amount, Decimal.new("0.2"))
    end

    {_ok, progress} = Bookings.update_booking_flow_progress(
      socket.assigns.booking_flow_progress,
      %{
        payment_plan: payment_plan,
        last_updated: DateTime.utc_now()
      }
    )

    socket = assign(socket, :booking_flow_progress, progress)

    socket =
      socket
      |> assign(:payment_plan, payment_plan)
      |> assign(:deposit_amount, deposit_amount)

    {:noreply, socket}
  end

  def handle_event("update_payment_method", %{"booking" => %{"payment_method" => payment_method}}, socket) do
    {_ok, progress} = Bookings.update_booking_flow_progress(
      socket.assigns.booking_flow_progress,
      %{
        payment_method: payment_method,
        last_updated: DateTime.utc_now()
      }
    )

    socket = assign(socket, :booking_flow_progress, progress)

    {:noreply, assign(socket, :payment_method, payment_method)}
  end

  def handle_event("upload_payment_proof", _params, socket) do
    # Only process if there are files to upload
    if length(socket.assigns.uploads.payment_proof.entries) > 0 do
      # Process the uploaded files immediately when this event is triggered
      filenames =
        consume_uploaded_entries(socket, :payment_proof, fn %{path: path}, entry ->
          timestamp = DateTime.utc_now() |> DateTime.to_unix()
          extension = Path.extname(entry.client_name)
          filename = "payment_proof_#{socket.assigns[:current_booking_id]}_#{timestamp}#{extension}"

          upload_path = ensure_upload_directory()
          file_path = Path.join(upload_path, filename)

          case File.cp(path, file_path) do
            :ok -> {:ok, filename}
            {:error, reason} -> {:postpone, {:error, "Failed to save file: #{inspect(reason)}"}}
          end
        end)

      # Update socket with upload results
      socket =
        case filenames do
          [filename | _] when is_binary(filename) ->
            socket
            |> put_flash(:info, "File uploaded successfully")
            |> assign(:payment_proof_file, filename)
          _ ->
            put_flash(socket, :error, "Failed to upload file. Please try again.")
        end

      {:noreply, socket}
    else
      # No files to process, just return the socket unchanged
      {:noreply, socket}
    end
  end

  def handle_event("update_notes", %{"booking" => %{"notes" => notes}}, socket) do
    socket = assign(socket, :notes, notes)

    {_ok, progress} = Bookings.update_booking_flow_progress(
      socket.assigns.booking_flow_progress,
      %{
        notes: notes,
        last_updated: DateTime.utc_now()
      }
    )

    socket = assign(socket, :booking_flow_progress, progress)

    {:noreply, socket}
  end

  def handle_event("validate_payment_proof", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("submit_payment_proof", params, socket) do
    notes = Map.get(params, "payment_proof_notes", "")

    case socket.assigns[:current_booking_id] do
      nil ->
        socket = put_flash(socket, :error, "No booking found. Please create a booking first.")
        {:noreply, socket}

      booking_id ->
        try do
          booking = Bookings.get_booking!(booking_id)

          if booking.payment_proof_status == "submitted" do
            socket = put_flash(socket, :error, "Payment proof has already been submitted for this booking.")
            {:noreply, socket}
          else
            # First, check if there are pending uploads to process
            socket = if length(socket.assigns.uploads.payment_proof.entries) > 0 and is_nil(socket.assigns.payment_proof_file) do
              # Process the uploaded files immediately
              filenames =
                consume_uploaded_entries(socket, :payment_proof, fn %{path: path}, entry ->
                  timestamp = DateTime.utc_now() |> DateTime.to_unix()
                  extension = Path.extname(entry.client_name)
                  filename = "payment_proof_#{socket.assigns[:current_booking_id]}_#{timestamp}#{extension}"

                  upload_path = ensure_upload_directory()
                  file_path = Path.join(upload_path, filename)

                  case File.cp(path, file_path) do
                    :ok -> {:ok, filename}
                    {:error, reason} -> {:postpone, {:error, "Failed to save file: #{inspect(reason)}"}}
                  end
                end)

              # Update socket with upload results
              case filenames do
                [filename | _] when is_binary(filename) ->
                  assign(socket, :payment_proof_file, filename)
                _ ->
                socket
              end
            else
              socket
            end

            # Now check if we have a file to submit
            if socket.assigns.payment_proof_file do
              attrs = %{
                "payment_proof_file" => socket.assigns.payment_proof_file,
                "payment_proof_notes" => notes || ""
              }

              case Bookings.submit_payment_proof(booking, attrs) do
                {:ok, _updated_booking} ->
                  # Reflect submission in booking flow progress for Active Bookings page
                  {_ok, updated_progress} = Bookings.update_booking_flow_progress(
                    socket.assigns.booking_flow_progress,
                    %{
                      last_updated: DateTime.utc_now()
                    }
                  )

                  socket =
                    socket
                    |> put_flash(:info, "Payment proof submitted successfully! File: #{socket.assigns.payment_proof_file}. Admin will review and approve your payment.")
                    |> assign(:show_payment_proof_form, false)
                    |> assign(:payment_proof_notes, notes || "")
                    |> assign(:booking_flow_progress, updated_progress)

                  _ = Umrahly.ActivityLogs.log_user_action(socket.assigns.current_user.id, "Payment Proof Submitted", socket.assigns.payment_proof_file, %{booking_id: booking.id})

                  {:noreply, socket}

                {:error, %Ecto.Changeset{} = _changeset} ->
                  socket = put_flash(socket, :error, "Failed to submit payment proof. Please check the form for errors.")
                  {:noreply, socket}

                {:error, _error} ->
                  socket = put_flash(socket, :error, "An unexpected error occurred while submitting payment proof.")
                  {:noreply, socket}
              end
            else
              socket = put_flash(socket, :error, "Please upload a file first.")
              {:noreply, socket}
            end
          end
        rescue
          Ecto.QueryError ->
            socket = put_flash(socket, :error, "Invalid booking ID.")
            {:noreply, socket}
          Ecto.NoResultsError ->
            socket = put_flash(socket, :error, "Booking not found.")
            {:noreply, socket}
          _error ->
            socket = put_flash(socket, :error, "An unexpected error occurred while processing the request.")
            {:noreply, socket}
        end
    end
  end

  def handle_event("toggle_payment_proof_form", _params, socket) do
    show_form = !socket.assigns.show_payment_proof_form
    socket = assign(socket, :show_payment_proof_form, show_form)
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :payment_proof, ref)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end


  def handle_event("save_progress_async", %{"value" => %{"step" => _step_str}}, socket) do
    {:noreply, socket}
  end

  def handle_event("save_progress_async", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("refresh_progress", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("page_visible", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cross_tab_sync", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("sync_progress", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save_and_navigate", %{"url" => url}, socket) do
    {:noreply, push_navigate(socket, to: url)}
  end

  def handle_event("page_refresh", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("page_loaded", _params, socket) do
    {:noreply, socket}
  end

    def handle_event("update_deposit_amount", %{"booking" => %{"deposit_amount" => deposit_amount_str}}, socket) do
    try do
      deposit_amount = Decimal.new(deposit_amount_str)
      socket = assign(socket, :deposit_amount, deposit_amount)


      {_ok, progress} = Bookings.update_booking_flow_progress(
        socket.assigns.booking_flow_progress,
        %{
          deposit_amount: deposit_amount,
          last_updated: DateTime.utc_now()
        }
      )


      socket = assign(socket, :booking_flow_progress, progress)

      {:noreply, socket}
    rescue
      _ ->
        {:noreply, socket}
    end
  end


  def handle_event("save_payment_info", _params, socket) do

    {_ok, progress} = Bookings.update_booking_flow_progress(
      socket.assigns.booking_flow_progress,
      %{
        payment_method: socket.assigns.payment_method,
        payment_plan: socket.assigns.payment_plan,
        deposit_amount: socket.assigns.deposit_amount,
        notes: socket.assigns.notes,
        last_updated: DateTime.utc_now()
      }
    )


    socket = assign(socket, :booking_flow_progress, progress)

    socket = put_flash(socket, :info, "Payment information saved successfully! ✅")

    {:noreply, socket}
  end


  def handle_event("clear_payment_info", _params, socket) do

    {_ok, progress} = Bookings.update_booking_flow_progress(
      socket.assigns.booking_flow_progress,
      %{
        payment_method: nil,
        payment_plan: "full_payment",
        deposit_amount: socket.assigns.total_amount,
        notes: "",
        last_updated: DateTime.utc_now()
      }
    )


    socket = assign(socket, :booking_flow_progress, progress)


    socket =
      socket
      |> assign(:payment_method, "")
      |> assign(:payment_plan, "full_payment")
      |> assign(:deposit_amount, socket.assigns.total_amount)
      |> assign(:notes, "")

    socket = put_flash(socket, :info, "Payment information cleared successfully! 🗑️")

    {:noreply, socket}
  end

    def handle_event("update_traveler", %{"index" => index_str, "field" => field, "value" => value}, socket) do
    index = String.to_integer(index_str)
    travelers = socket.assigns.travelers

    updated_travelers = List.update_at(travelers, index, fn traveler ->

      Map.put(traveler, field, value)
    end)


    final_travelers = if socket.assigns.is_booking_for_self and length(updated_travelers) > 0 do
      first_traveler = List.first(updated_travelers)
      updated_first_traveler = Map.merge(first_traveler, %{
        "full_name" => socket.assigns.current_user.full_name || "",
        "identity_card_number" => socket.assigns.current_user.identity_card_number || "",
        "phone" => socket.assigns.current_user.phone_number || "",
        "address" => socket.assigns.current_user.address || ""
      })
      [updated_first_traveler] ++ List.delete_at(updated_travelers, 0)
    else
      updated_travelers
    end

    socket = assign(socket, :travelers, final_travelers)

    {:noreply, socket}
  end


  def handle_event("validate_travelers", %{"booking" => booking_params}, socket) do

    travelers_params = booking_params["travelers"] || []


    updated_travelers =
      Enum.with_index(travelers_params)
      |> Enum.map(fn {traveler, idx} ->
        existing = Enum.at(socket.assigns.travelers, idx, %{})
        Map.merge(existing, %{
          "full_name" => traveler["full_name"] || existing["full_name"] || existing[:full_name] || "",
          "identity_card_number" => traveler["identity_card_number"] || existing["identity_card_number"] || existing[:identity_card_number] || "",
          "passport_number" => traveler["passport_number"] || existing["passport_number"] || existing[:passport_number] || "",
          "phone" => traveler["phone"] || existing["phone"] || existing[:phone] || ""
        })
      end)


    final_travelers = if socket.assigns.is_booking_for_self and length(updated_travelers) > 0 do
      first_traveler = List.first(updated_travelers)
      updated_first_traveler = Map.merge(first_traveler, %{
        "full_name" => socket.assigns.current_user.full_name || "",
        "identity_card_number" => socket.assigns.current_user.identity_card_number || "",
        "passport_number" => socket.assigns.current_user.passport_number || "",
        "phone" => socket.assigns.current_user.phone_number || "",
        "date_of_birth" => case socket.assigns.current_user.birthdate do
          nil -> ""
          birthdate -> Date.to_string(birthdate)
        end,
        "address" => socket.assigns.current_user.address || "",
        "poskod" => socket.assigns.current_user.poskod || "",
        "city" => socket.assigns.current_user.city || "",
        "state" => socket.assigns.current_user.state || "",
        "citizenship" => socket.assigns.current_user.citizenship || "Malaysia",
        "emergency_contact_name" => socket.assigns.current_user.emergency_contact_name || "",
        "emergency_contact_phone" => socket.assigns.current_user.emergency_contact_phone || "",
        "emergency_contact_relationship" => socket.assigns.current_user.emergency_contact_relationship || ""
      })
      [updated_first_traveler] ++ List.delete_at(updated_travelers, 0)
    else
      updated_travelers
    end

    all_travelers_complete =
      Enum.all?(final_travelers, fn traveler ->
        traveler["full_name"] != "" and
        traveler["identity_card_number"] != "" and
        traveler["phone"] != ""
      end)

    {_ok, _progress} =
      Bookings.update_booking_flow_progress(socket.assigns.booking_flow_progress, %{travelers_data: final_travelers, last_updated: DateTime.utc_now()})

    socket =
      socket
      |> assign(:travelers, final_travelers)
      |> (fn s ->
        if all_travelers_complete do
          put_flash(s, :info, "Traveler information validated successfully!")
        else
          put_flash(s, :error, "Please complete all required traveler information before proceeding.")
        end
      end).()

    {:noreply, socket}
  end

  def handle_event("validate_travelers", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("update_traveler_field", %{"value" => value} = params, socket) do
    index = String.to_integer(params["index"])
    field = params["field"]
    travelers = socket.assigns.travelers

    updated_travelers = List.update_at(travelers, index, fn traveler ->
      Map.put(traveler, field, value)
    end)

    final_travelers = if socket.assigns.is_booking_for_self and length(updated_travelers) > 0 do
      first_traveler = List.first(updated_travelers)
      updated_first_traveler = Map.merge(first_traveler, %{
        "full_name" => socket.assigns.current_user.full_name || "",
        "identity_card_number" => socket.assigns.current_user.identity_card_number || "",
        "passport_number" => socket.assigns.current_user.passport_number || "",
        "phone" => socket.assigns.current_user.phone_number || "",
        "date_of_birth" => case socket.assigns.current_user.birthdate do
          nil -> ""
          birthdate -> Date.to_string(birthdate)
        end,
        "address" => socket.assigns.current_user.address || "",
        "poskod" => socket.assigns.current_user.poskod || "",
        "city" => socket.assigns.current_user.city || "",
        "state" => socket.assigns.current_user.state || "",
        "citizenship" => socket.assigns.current_user.citizenship || "Malaysia",
        "emergency_contact_name" => socket.assigns.current_user.emergency_contact_name || "",
        "emergency_contact_phone" => socket.assigns.current_user.emergency_contact_phone || "",
        "emergency_contact_relationship" => socket.assigns.current_user.emergency_contact_relationship || ""
      })
      [updated_first_traveler] ++ List.delete_at(updated_travelers, 0)
    else
      updated_travelers
    end

    socket = assign(socket, :travelers, final_travelers)

    {:noreply, socket}
  end

  def handle_event("save_travelers", _params, socket) do
    travelers = socket.assigns.travelers

    all_travelers_complete =
      Enum.all?(travelers, fn traveler ->
        (traveler["full_name"] || traveler[:full_name] || "") != "" and
        (traveler["identity_card_number"] || traveler[:identity_card_number] || "") != "" and
        (traveler["phone"] || traveler[:phone] || "") != "" and
        (traveler["date_of_birth"] || traveler[:date_of_birth] || "") != "" and
        (traveler["address"] || traveler[:address] || "") != "" and
        (traveler["poskod"] || traveler[:poskod] || "") != "" and
        (traveler["city"] || traveler[:city] || "") != "" and
        (traveler["state"] || traveler[:state] || "") != "" and
        (traveler["emergency_contact_name"] || traveler[:emergency_contact_name] || "") != "" and
        (traveler["emergency_contact_phone"] || traveler[:emergency_contact_phone] || "") != ""
      end)

    if all_travelers_complete do
      actual_number_of_persons = length(travelers)
      {_ok, _progress} =
        Bookings.update_booking_flow_progress(socket.assigns.booking_flow_progress, %{
          travelers_data: travelers,
          number_of_persons: actual_number_of_persons,
          last_updated: DateTime.utc_now()
        })

      socket =
        socket
        |> put_flash(:info, "Traveler information saved successfully! ✅ Your data has been preserved and you can continue editing if needed.")

      {:noreply, socket}
    else
      socket = put_flash(socket, :error, "Please complete all required traveler information before saving.")
      {:noreply, socket}
    end
  end



  def handle_event("clear_traveler_field", %{"index" => index_str, "field" => field}, socket) do
    index = String.to_integer(index_str)
    travelers = socket.assigns.travelers

    updated_travelers = List.update_at(travelers, index, fn traveler ->
      if index == 0 and socket.assigns.is_booking_for_self and field in ["full_name", "identity_card_number", "passport_number", "phone", "date_of_birth", "address", "poskod", "city", "state", "citizenship", "emergency_contact_name", "emergency_contact_phone", "emergency_contact_relationship"] do
        case field do
          "full_name" -> Map.put(traveler, "full_name", socket.assigns.current_user.full_name || "")
          "identity_card_number" -> Map.put(traveler, "identity_card_number", socket.assigns.current_user.identity_card_number || "")
          "passport_number" -> Map.put(traveler, "passport_number", socket.assigns.current_user.passport_number || "")
          "phone" -> Map.put(traveler, "phone", socket.assigns.current_user.phone_number || "")
          "date_of_birth" -> case socket.assigns.current_user.birthdate do
            nil -> Map.put(traveler, "date_of_birth", "")
            birthdate -> Map.put(traveler, "date_of_birth", Date.to_string(birthdate))
          end
          "address" -> Map.put(traveler, "address", socket.assigns.current_user.address || "")
          "poskod" -> Map.put(traveler, "poskod", socket.assigns.current_user.poskod || "")
          "city" -> Map.put(traveler, "city", socket.assigns.current_user.city || "")
          "state" -> Map.put(traveler, "state", socket.assigns.current_user.state || "")
          "citizenship" -> Map.put(traveler, "citizenship", socket.assigns.current_user.citizenship || "Malaysia")
          "emergency_contact_name" -> Map.put(traveler, "emergency_contact_name", socket.assigns.current_user.emergency_contact_name || "")
          "emergency_contact_phone" -> Map.put(traveler, "emergency_contact_phone", socket.assigns.current_user.emergency_contact_phone || "")
          "emergency_contact_relationship" -> Map.put(traveler, "emergency_contact_relationship", socket.assigns.current_user.emergency_contact_relationship || "")
        end
      else
        Map.put(traveler, field, "")
      end
    end)

    socket = assign(socket, :travelers, updated_travelers)

    {:noreply, socket}
  end

  def handle_event("clear_all_traveler_fields", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    travelers = socket.assigns.travelers

    updated_travelers = List.update_at(travelers, index, fn _traveler ->
      if index == 0 and socket.assigns.is_booking_for_self do
        %{
          "full_name" => socket.assigns.current_user.full_name || "",
          "identity_card_number" => socket.assigns.current_user.identity_card_number || "",
          "passport_number" => "",
          "phone" => socket.assigns.current_user.phone_number || "",
          "date_of_birth" => "",
          "address" => socket.assigns.current_user.address || "",
          "poskod" => "",
          "city" => "",
          "state" => "",
          "citizenship" => "Malaysia",
          "emergency_contact_name" => "",
          "emergency_contact_phone" => "",
          "emergency_contact_relationship" => "",
          "room_type" => "standard"
        }
      else
        %{
          "full_name" => "",
          "identity_card_number" => "",
          "passport_number" => "",
          "phone" => "",
          "date_of_birth" => "",
          "address" => "",
          "poskod" => "",
          "city" => "",
          "state" => "",
          "citizenship" => "Malaysia",
          "emergency_contact_name" => "",
          "emergency_contact_phone" => "",
          "emergency_contact_relationship" => "",
          "room_type" => "standard"
        }
      end
    end)

    socket = assign(socket, :travelers, updated_travelers)

    {:noreply, socket}
  end

  def handle_event("clear_all_fields", _params, socket) do
    cleared_travelers = Enum.with_index(socket.assigns.travelers)
    |> Enum.map(fn {_traveler, index} ->
      if index == 0 and socket.assigns.is_booking_for_self do
        %{
          "full_name" => socket.assigns.current_user.full_name || "",
          "identity_card_number" => socket.assigns.current_user.identity_card_number || "",
          "passport_number" => "",
          "phone" => socket.assigns.current_user.phone_number || "",
          "date_of_birth" => "",
          "address" => socket.assigns.current_user.address || "",
          "poskod" => "",
          "city" => "",
          "state" => "",
          "citizenship" => "Malaysia",
          "emergency_contact_name" => "",
          "emergency_contact_phone" => "",
          "emergency_contact_relationship" => "",
          "room_type" => "standard"
        }
      else
        %{
          "full_name" => "",
          "identity_card_number" => "",
          "passport_number" => "",
          "phone" => "",
          "date_of_birth" => "",
          "address" => "",
          "poskod" => "",
          "city" => "",
          "state" => "",
          "citizenship" => "Malaysia",
          "emergency_contact_name" => "",
          "emergency_contact_phone" => "",
          "emergency_contact_relationship" => "",
          "room_type" => "standard"
        }
      end
    end)

    socket =
      socket
      |> assign(:travelers, cleared_travelers)
      |> put_flash(:info, "All fields have been cleared.")

    {:noreply, socket}
  end


  def handle_event("add_traveler", _params, socket) do
    current_travelers = socket.assigns.travelers
    new_traveler = %{
      "full_name" => "",
      "identity_card_number" => "",
      "passport_number" => "",
      "phone" => "",
      "date_of_birth" => "",
      "address" => "",
      "poskod" => "",
      "city" => "",
      "state" => "",
      "citizenship" => "Malaysia",
      "emergency_contact_name" => "",
      "emergency_contact_phone" => "",
      "emergency_contact_relationship" => "",
      "room_type" => "standard"
    }

    updated_travelers = current_travelers ++ [new_traveler]
    new_number_of_persons = length(updated_travelers)

      final_travelers = if socket.assigns.is_booking_for_self and length(updated_travelers) > 0 do
        first_traveler = List.first(updated_travelers)
        updated_first_traveler = Map.merge(first_traveler, %{
          "full_name" => socket.assigns.current_user.full_name || "",
          "identity_card_number" => socket.assigns.current_user.identity_card_number || "",
          "passport_number" => socket.assigns.current_user.passport_number || "",
          "phone" => socket.assigns.current_user.phone_number || "",
          "date_of_birth" => case socket.assigns.current_user.birthdate do
            nil -> ""
            birthdate -> Date.to_string(birthdate)
          end,
          "address" => socket.assigns.current_user.address || "",
          "poskod" => socket.assigns.current_user.poskod || "",
          "city" => socket.assigns.current_user.city || "",
          "state" => socket.assigns.current_user.state || "",
          "citizenship" => socket.assigns.current_user.citizenship || "Malaysia",
          "emergency_contact_name" => socket.assigns.current_user.emergency_contact_name || "",
          "emergency_contact_phone" => socket.assigns.current_user.emergency_contact_phone || "",
          "emergency_contact_relationship" => socket.assigns.current_user.emergency_contact_relationship || ""
        })
        [updated_first_traveler] ++ List.delete_at(updated_travelers, 0)
      else
        updated_travelers
      end

      package_price = socket.assigns.package.price
      base_price = package_price
      override_price = if socket.assigns.schedule.price_override, do: Decimal.to_integer(socket.assigns.schedule.price_override), else: 0
      schedule_price_per_person = base_price + override_price

      total_amount = Decimal.mult(Decimal.new(schedule_price_per_person), Decimal.new(new_number_of_persons))

      deposit_amount = if socket.assigns.payment_plan == "installment" do
        Decimal.mult(total_amount, Decimal.new("0.2"))
      else
        total_amount
      end

      {_ok, progress} = Bookings.update_booking_flow_progress(
        socket.assigns.booking_flow_progress,
        %{
          deposit_amount: deposit_amount,
          last_updated: DateTime.utc_now()
        }
      )

      socket =
        socket
        |> assign(:travelers, final_travelers)
        |> assign(:number_of_persons, new_number_of_persons)
        |> assign(:total_amount, total_amount)
        |> assign(:deposit_amount, deposit_amount)
        |> assign(:booking_flow_progress, progress)
        |> put_flash(:info, "New traveler added! Please fill in their details.")

    {:noreply, socket}
  end

  def handle_event("remove_traveler", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    travelers = socket.assigns.travelers

    if length(travelers) > 1 do
      updated_travelers = List.delete_at(travelers, index)
      new_number_of_persons = length(updated_travelers)

      final_travelers = if index == 0 and socket.assigns.is_booking_for_self and length(updated_travelers) > 0 do
        first_traveler = List.first(updated_travelers)
        updated_first_traveler = Map.merge(first_traveler, %{
          "full_name" => socket.assigns.current_user.full_name || "",
          "identity_card_number" => socket.assigns.current_user.identity_card_number || "",
          "passport_number" => socket.assigns.current_user.passport_number || "",
          "phone" => socket.assigns.current_user.phone_number || "",
          "date_of_birth" => case socket.assigns.current_user.birthdate do
            nil -> ""
            birthdate -> Date.to_string(birthdate)
          end,
          "address" => socket.assigns.current_user.address || "",
          "poskod" => socket.assigns.current_user.poskod || "",
          "city" => socket.assigns.current_user.city || "",
          "state" => socket.assigns.current_user.state || "",
          "citizenship" => socket.assigns.current_user.citizenship || "Malaysia",
          "emergency_contact_name" => socket.assigns.current_user.emergency_contact_name || "",
          "emergency_contact_phone" => socket.assigns.current_user.emergency_contact_phone || "",
          "emergency_contact_relationship" => socket.assigns.current_user.emergency_contact_relationship || ""
        })
        [updated_first_traveler] ++ List.delete_at(updated_travelers, 0)
      else
        updated_travelers
      end

      package_price = socket.assigns.package.price
      base_price = package_price
      override_price = if socket.assigns.schedule.price_override, do: Decimal.to_integer(socket.assigns.schedule.price_override), else: 0
      schedule_price_per_person = base_price + override_price

      total_amount = Decimal.mult(Decimal.new(schedule_price_per_person), Decimal.new(new_number_of_persons))

      deposit_amount = if socket.assigns.payment_plan == "installment" do
        Decimal.mult(total_amount, Decimal.new("0.2"))
      else
        total_amount
      end

      {_ok, progress} = Bookings.update_booking_flow_progress(
        socket.assigns.booking_flow_progress,
        %{
          deposit_amount: deposit_amount,
          last_updated: DateTime.utc_now()
        }
      )

      socket =
        socket
        |> assign(:travelers, final_travelers)
        |> assign(:number_of_persons, new_number_of_persons)
        |> assign(:total_amount, total_amount)
        |> assign(:deposit_amount, deposit_amount)
        |> assign(:booking_flow_progress, progress)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("go_to_next_step", _params, socket) do
    current_step = socket.assigns.current_step
    max_steps = socket.assigns.max_steps

    if current_step == max_steps do
      {:noreply, socket}
    else
      cond do
        current_step < 1 ->
          socket = assign(socket, :current_step, 1)
          {:noreply, socket}
        current_step > max_steps ->
          socket = assign(socket, :current_step, max_steps)
          {:noreply, socket}
        current_step == 2 ->
          travelers = socket.assigns.travelers
          all_travelers_complete = Enum.all?(travelers, fn traveler ->
            (traveler["full_name"] || traveler[:full_name] || "") != "" and
            (traveler["identity_card_number"] || traveler[:identity_card_number] || "") != "" and
            (traveler["phone"] || traveler[:phone] || "") != "" and
            (traveler["date_of_birth"] || traveler[:date_of_birth] || "") != "" and
            (traveler["address"] || traveler[:address] || "") != "" and
            (traveler["poskod"] || traveler[:poskod] || "") != "" and
            (traveler["city"] || traveler[:city] || "") != "" and
            (traveler["state"] || traveler[:state] || "") != "" and
            (traveler["emergency_contact_name"] || traveler[:emergency_contact_name] || "") != "" and
            (traveler["emergency_contact_phone"] || traveler[:emergency_contact_phone] || "") != ""
          end)

          if all_travelers_complete do
            new_step = current_step + 1
            {_ok, progress} = Bookings.update_booking_flow_progress(socket.assigns.booking_flow_progress, %{current_step: new_step})

            socket = assign(socket, :current_step, new_step)
            socket = assign(socket, :booking_flow_progress, progress)
            {:noreply, socket}
          else
            socket = put_flash(socket, :error, "Please complete all required traveler information before proceeding.")
            {:noreply, socket}
          end
        current_step < max_steps ->
          new_step = current_step + 1

          {_ok, progress} = Bookings.update_booking_flow_progress(socket.assigns.booking_flow_progress, %{current_step: new_step})

          socket = assign(socket, :current_step, new_step)
          socket = assign(socket, :booking_flow_progress, progress)

          {:noreply, socket}
        true ->
          {:noreply, socket}
      end
    end
  end

  def handle_event("next_step", _params, socket) do
    current_step = socket.assigns.current_step
    max_steps = socket.assigns.max_steps

    if current_step >= max_steps do
      {:noreply, socket}
    else
      new_step = current_step + 1

      {_ok, updated_progress} =
        Bookings.update_booking_flow_progress(socket.assigns.booking_flow_progress, %{current_step: new_step, last_updated: DateTime.utc_now()})

      socket = assign(socket, :current_step, new_step)
      socket = assign(socket, :booking_flow_progress, updated_progress)

      {:noreply, socket}
    end
  end

  def handle_event("prev_step", _params, socket) do

    current_step = socket.assigns.current_step
    prev_step = max(current_step - 1, 1)

    {_ok, updated_progress} = Bookings.update_booking_flow_progress(socket.assigns.booking_flow_progress, %{current_step: prev_step})

    socket = assign(socket, :current_step, prev_step)
    socket = assign(socket, :booking_flow_progress, updated_progress)

    {:noreply, socket}
  end

  def handle_event("create_booking", _params, socket) do
    travelers = socket.assigns.travelers

    all_travelers_complete = Enum.all?(travelers, fn traveler ->
      (traveler["full_name"] || traveler[:full_name] || "") != "" and
      (traveler["identity_card_number"] || traveler[:identity_card_number] || "") != "" and
      (traveler["phone"] || traveler[:phone] || "") != "" and
      (traveler["date_of_birth"] || traveler[:date_of_birth] || "") != "" and
      (traveler["address"] || traveler[:address] || "") != "" and
      (traveler["poskod"] || traveler[:poskod] || "") != "" and
      (traveler["city"] || traveler[:city] || "") != "" and
      (traveler["state"] || traveler[:state] || "") != "" and
      (traveler["emergency_contact_name"] || traveler[:emergency_contact_name] || "") != "" and
      (traveler["emergency_contact_phone"] || traveler[:emergency_contact_phone] || "") != ""
    end)

    cond do
      socket.assigns.payment_method == "" or is_nil(socket.assigns.payment_method) ->
        socket =
          socket
          |> put_flash(:error, "Please select a payment method before proceeding.")

        {:noreply, socket}

      !all_travelers_complete ->
        socket =
          socket
          |> put_flash(:error, "Please complete all required traveler information before proceeding.")

        {:noreply, socket}

      true ->
        attrs = %{
          total_amount: socket.assigns.total_amount,
          deposit_amount: socket.assigns.deposit_amount,
          amount: socket.assigns.total_amount, # Set amount to match total_amount
          number_of_persons: socket.assigns.number_of_persons,
          payment_method: socket.assigns.payment_method,
          payment_plan: socket.assigns.payment_plan,
          notes: socket.assigns.notes,
          user_id: socket.assigns.current_user.id,
          package_schedule_id: socket.assigns.schedule.id,
          status: "pending",
          booking_date: Date.utc_today()
        }

        try do
          case Bookings.create_booking(attrs) do
            {:ok, booking} ->
              payment_method = socket.assigns.payment_method
              requires_online_payment = payment_method in ["toyyibpay"]

              # Update the booking flow progress so Active Bookings reflects completion
              {_ok, progress_after_booking} = Bookings.update_booking_flow_progress(
                socket.assigns.booking_flow_progress,
                %{
                  # Keep within validation limits in booking_flow_progress schema
                  current_step: 4,
                  max_steps: 4,
                  status: "completed",
                  # Only update safe fields to avoid inclusion validation failures
                  deposit_amount: socket.assigns.deposit_amount,
                  total_amount: socket.assigns.total_amount,
                  last_updated: DateTime.utc_now()
                }
              )

              _ = Umrahly.ActivityLogs.log_user_action(socket.assigns.current_user.id, "Booking Created", socket.assigns.package.name, %{booking_id: booking.id, total_amount: booking.total_amount})

              socket = if requires_online_payment do
                payment_url = generate_payment_gateway_url(booking, socket.assigns)

                socket
                  |> put_flash(:info, "Booking created successfully! Redirecting to payment gateway...")
                  |> assign(:current_step, 5)
                  |> assign(:payment_gateway_url, payment_url)
                  |> assign(:requires_online_payment, true)
                  |> assign(:current_booking_id, booking.id)
                  |> assign(:booking_flow_progress, progress_after_booking)
              else
                socket
                  |> put_flash(:info, "Booking created successfully! Please complete your payment offline.")
                  |> assign(:current_step, 5)
                  |> assign(:requires_online_payment, false)
                  |> assign(:current_booking_id, booking.id)
                  |> assign(:booking_flow_progress, progress_after_booking)
              end

              {:noreply, socket}

            {:error, %Ecto.Changeset{} = changeset} ->
              socket =
                socket
                |> put_flash(:error, "Failed to create booking. Please check the form for errors.")
                |> assign(:changeset, changeset)

              {:noreply, socket}

            {:error, error} ->
              socket =
                socket
                |> put_flash(:error, "An unexpected error occurred while creating the booking: #{inspect(error)}")

              {:noreply, socket}
          end
        rescue
          error ->
            socket =
              socket
              |> put_flash(:error, "System error occurred: #{inspect(error)}")

            {:noreply, socket}
        end
    end
  end

  def handle_info({:save_progress_async, _step}, socket) do
    {:noreply, socket}
  end





  defp generate_payment_gateway_url(booking, assigns) do
    config = Application.get_env(:umrahly, :payment_gateway)

    payment_method = assigns.payment_method

    case payment_method do
      "toyyibpay" ->
        generate_toyyibpay_payment_url(booking, assigns, config[:toyyibpay])

      _ ->
        generate_generic_payment_url(booking, assigns, config[:generic])
    end
  end

  defp generate_toyyibpay_payment_url(booking, assigns, _toyyibpay_config) do
    case Umrahly.ToyyibPay.create_bill(booking, assigns) do
      {:ok, %{payment_url: payment_url}} ->
        payment_url
      {:error, reason} ->
        # Log error and fallback to demo URL
        require Logger
        Logger.error("ToyyibPay bill creation failed: #{inspect(reason)}")

        # Instead of generating a fake bill URL that returns 404,
        # redirect to ToyyibPay sandbox homepage which actually exists
        "https://dev.toyyibpay.com"
    end
  end

  defp generate_generic_payment_url(booking, _assigns, _generic_config) do
    base_url = "https://demo-generic-gateway.com"

    booking_id_str = case booking do
      %{id: id} when is_integer(id) -> Integer.to_string(id)
      %{id: id} when is_binary(id) -> id
      _ -> "demo"
    end

    id_suffix = if String.length(booking_id_str) >= 8 do
      String.slice(booking_id_str, -8..-1)
    else
      String.pad_leading(booking_id_str, 8, "0")
    end

    payment_id = "GEN-#{id_suffix}-#{:crypto.strong_rand_bytes(4) |> Base.encode16(case: :upper)}"

    "#{base_url}/pay/#{payment_id}"
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:too_many_files), do: "Too many files"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(_), do: "Invalid file"

  defp ensure_upload_directory do
    upload_path = Path.join(["priv", "static", "uploads", "payment_proof"])
    File.mkdir_p!(upload_path)
    upload_path
  end

  defp has_payment_progress?(progress) do
    progress.payment_method || progress.payment_plan || progress.notes || progress.deposit_amount
  end

  def render(assigns) do
    ~H"""
    <.sidebar page_title={@page_title}>
      <div id="booking-flow-container" class="max-w-4xl mx-auto space-y-6"

           data-step={@current_step}
           data-package-id={@package.id}
           data-schedule-id={@schedule.id}>
        <!-- Progress Steps -->
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold text-gray-900 text-center flex-1">Book Your Package</h1>
            <div class="text-sm text-gray-500">
              Step <%= @current_step %> of <%= @max_steps %>
            </div>
          </div>

          <!-- Progress Restoration Message -->
          <!-- Removed progress restoration message since progress saving is disabled -->

          <!-- Progress Bar -->
          <div class="w-full bg-gray-200 rounded-full h-2 mb-6">
            <div class="bg-blue-600 h-2 rounded-full transition-all duration-300" style={"width: #{Float.round((@current_step / @max_steps) * 100, 1)}%"}>
            </div>
          </div>

          <!-- Step Indicators -->
          <div class="flex justify-between mb-8">
            <div class="flex flex-col items-center">
              <div class={"w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium #{if @current_step >= 1, do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-600"}"}>
                1
              </div>
              <span class="text-xs text-gray-600 mt-1">Package Details</span>
            </div>
            <div class="flex flex-col items-center">
              <div class={"w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium #{if @current_step >= 2, do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-600"}"}>
                2
              </div>
              <span class="text-xs text-gray-600 mt-1">Travelers</span>
            </div>
            <div class="flex flex-col items-center">
              <div class={"w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium #{if @current_step >= 3, do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-600"}"}>
                3
              </div>
              <span class="text-xs text-gray-600 mt-1">Payment</span>
            </div>
            <div class="flex flex-col items-center">
              <div class={"w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium #{if @current_step >= 4, do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-600"}"}>
                4
              </div>
              <span class="text-xs text-gray-600 mt-1">Review & Confirm</span>
            </div>
            <div class="flex flex-col items-center">
              <div class={"w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium #{if @current_step >= 5, do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-600"}"}>
                5
              </div>
              <span class="text-xs text-gray-600 mt-1">Success</span>
            </div>
          </div>
        </div>

        <!-- Step 1: Package Details -->
        <%= if @current_step == 1 do %>
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold text-gray-900 mb-4">Package Details</h2>

            <!-- Progress Status for Step 1 -->
            <%= if @saved_package_progress || @saved_travelers_progress || @saved_payment_progress do %>
              <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
                <div class="flex items-center">
                  <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <p class="text-sm text-blue-700">
                      <strong>Progress Available!</strong> You have saved progress in later steps. You can continue to review and complete your booking.
                    </p>
                    <div class="mt-2 text-xs text-blue-600">
                      <%= if @saved_payment_progress do %>
                        <strong>Payment:</strong> Information saved ✓
                      <% end %>
                      <%= if @saved_travelers_progress do %>
                        <strong>Travelers:</strong> Information saved ✓
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <!-- Package Information -->
              <div class="space-y-4">
                <div class="border rounded-lg p-4">
                  <h3 class="font-medium text-gray-900 mb-2"><%= @package.name %></h3>
                  <p class="text-sm text-gray-600 mb-3"><%= @package.description %></p>

                  <div class="space-y-2 text-sm">
                    <div class="flex justify-between">
                      <span class="text-gray-600">Duration:</span>
                      <span class="font-medium"><%= @package.duration_days %> days, <%= @package.duration_nights %> nights</span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-gray-600">Accommodation:</span>
                      <span class="font-medium"><%= @package.accommodation_type %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-gray-600">Transport:</span>
                      <span class="font-medium"><%= @package.transport_type %></span>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Schedule Information -->
              <div class="space-y-4">
                <div class="border rounded-lg p-4">
                  <h3 class="font-medium text-gray-900 mb-2">Selected Schedule</h3>

                  <div class="space-y-2 text-sm">
                    <div class="flex justify-between">
                      <span class="text-gray-600">Departure:</span>
                      <span class="font-medium"><%= Calendar.strftime(@schedule.departure_date, "%B %d, %Y") %></span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-gray-600">Return:</span>
                      <span class="font-medium"><%= Calendar.strftime(@schedule.return_date, "%B %d, %Y") %></span>
                    </div>
                    <div class="flex justify-between border-t pt-2">
                      <span class="text-gray-600 font-medium">Total price per person:</span>
                      <span class="font-bold text-green-600">RM <%= @price_per_person %></span>
                    </div>

                    <div class="flex justify-between">
                      <span class="text-gray-600">Available slots:</span>
                      <span class="font-medium"><%= @schedule.quota %></span>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div class="mt-6 flex justify-between">
              <a
                href={~p"/packages/#{@package.id}"}
                class="bg-gray-300 text-gray-700 px-6 py-2 rounded-lg hover:bg-gray-400 transition-colors font-medium"
              >
                Back
              </a>
              <button
                type="button"
                phx-click="go_to_next_step"
                class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium"
              >
                Continue
              </button>
            </div>
          </div>
        <% end %>

        <!-- Step 2: Travelers -->
        <%= if @current_step == 2 do %>
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold text-gray-900 mb-4">Travelers</h2>
            <div class="space-y-6">
              <!-- Progress Status -->
              <%= if @saved_travelers_progress do %>
                <div class="bg-green-50 border border-green-200 rounded-lg p-4">
                  <div class="flex items-center">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <p class="text-sm text-green-700">
                        <strong>Progress Saved!</strong> Your travelers information has been saved. You can continue or go back to make changes.
                      </p>
                    </div>
                  </div>
                </div>
              <% end %>

              <!-- Payment Progress Status -->
              <%= if @saved_payment_progress do %>
                <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
                  <div class="flex items-center">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <p class="text-sm text-blue-700">
                        <strong>Payment Progress Available!</strong> You have saved payment information. You can continue to step 3 to review or modify it.
                      </p>
                    </div>
                  </div>
                </div>
              <% end %>

              <!-- Auto-clear Information -->
              <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
                <div class="flex items-center">
                  <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <p class="text-sm text-blue-700">
                      <strong>Auto-clear Feature:</strong> After saving traveler information, the form will automatically clear to prepare for the next entry. You can also manually clear fields using the "Clear All" buttons.
                    </p>
                  </div>
                </div>
              </div>

              <!-- Number of Persons -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Number of Travelers
                </label>
                <div class="flex items-center space-x-2">
                  <div class="flex border border-gray-300 rounded-lg">
                    <button
                      type="button"
                      phx-click="update_number_of_persons"
                      phx-value-action="decrease"
                      disabled={@number_of_persons <= 1}
                      class="px-3 py-2 text-gray-600 hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      -
                    </button>
                    <span class="px-4 py-2 bg-gray-50 text-center min-w-[3rem]">
                      <%= @number_of_persons %>
                    </span>
                    <button
                      type="button"
                      phx-click="update_number_of_persons"
                      phx-value-action="increase"
                      disabled={@number_of_persons >= 10}
                      class="px-3 py-2 text-gray-600 hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      +
                    </button>
                  </div>
                </div>
                <!-- Debug info -->
                <div class="mt-2 text-xs text-gray-500">
                  Current travelers in list: <%= length(@travelers) %> |
                  Number of persons: <%= @number_of_persons %>
                </div>
              </div>

              <!-- Travelers Details -->
              <div class="bg-gray-50 rounded-lg p-4">
                <div class="flex items-center justify-between mb-3">
                  <h3 class="font-medium text-gray-900">Travelers Details</h3>
                  <span class="text-sm text-gray-600 bg-blue-100 px-2 py-1 rounded">
                    Total: <%= @number_of_persons %> traveler(s)
                  </span>
                </div>

                <!-- Toggle for single traveler -->
                <%= if @number_of_persons == 1 do %>
                  <div class="mb-4">
                    <div class="flex items-center justify-between p-3 bg-white border border-gray-200 rounded-lg">
                      <div class="flex items-center">
                        <span class="text-sm font-medium text-gray-700 mr-3">Who is traveling?</span>
                      </div>
                      <div class="flex items-center space-x-3">
                        <button
                          type="button"
                          phx-click="toggle_booking_for_self"
                          class={"px-4 py-2 rounded-lg text-sm font-medium transition-colors #{if @is_booking_for_self, do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-700"}"}
                        >
                          I am traveling
                        </button>
                        <button
                          type="button"
                          phx-click="toggle_booking_for_self"
                          class={"px-4 py-2 rounded-lg text-sm font-medium transition-colors #{if !@is_booking_for_self, do: "bg-blue-600 text-white", else: "bg-gray-200 text-gray-700"}"}
                        >
                          Someone else is traveling
                        </button>
                      </div>
                    </div>
                  </div>
                <% end %>

                <%= if @number_of_persons > 1 do %>
                  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
                    <div class="flex">
                      <div class="flex-shrink-0">
                        <svg class="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
                          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                        </svg>
                      </div>
                      <div class="ml-3">
                        <p class="text-sm text-blue-700">
                          <strong>Important:</strong> When selecting more than 1 traveler, you must provide complete details for each person including full name, identity card number, phone number, date of birth, address details, and emergency contact information. Passport number is optional.
                        </p>
                      </div>
                    </div>
                  </div>
                  <p class="text-sm text-gray-600 mb-4">Please provide details for all travelers.</p>
                <% else %>
                  <p class="text-sm text-gray-600 mb-4">
                    <%= if @is_booking_for_self do %>
                      Please provide your travel details. Your profile information has been pre-filled. Date of birth, address details, and emergency contact information are required. Passport number is optional.
                    <% else %>
                      Please provide the traveler's details. Date of birth, address details, and emergency contact information are required. Passport number is optional.
                    <% end %>
                  </p>
                <% end %>

                <div class="space-y-4">
                  <%= for {traveler, index} <- Enum.with_index(@travelers) do %>
                    <div class="border border-gray-200 rounded-lg p-4">
                      <div class="flex items-center justify-between mb-3">
                        <h4 class="font-medium text-gray-800">
                          <%= if(@number_of_persons == 1 and @is_booking_for_self, do: "Your Details", else: if(@number_of_persons == 1, do: "Traveler Details", else: if(index == 0, do: "Traveler #{index + 1} (Person In Charge)", else: "Traveler #{index + 1}"))) %>
                        </h4>
                        <div class="flex space-x-2">
                          <button
                            type="button"
                            phx-click="clear_all_traveler_fields"
                            phx-value-index={index}
                            class="text-orange-500 hover:text-orange-700 text-sm font-medium"
                            title="Clear all fields for this traveler"
                          >
                            Clear All
                          </button>
                          <%= if @number_of_persons > 1 do %>
                            <button
                              type="button"
                              phx-click="remove_traveler"
                              phx-value-index={index}
                              class="text-red-500 hover:text-red-700 text-sm font-medium"
                              title="Remove traveler"
                            >
                              Remove
                            </button>
                          <% end %>
                        </div>
                      </div>

                      <div class="space-y-6">
                        <!-- Section 1: Traveler's Information -->
                        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
                          <h5 class="font-medium text-blue-900 mb-3">Section 1: Traveler's Information</h5>
                          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                            <div>
                              <label class="block text-sm font-medium text-gray-700 mb-1">
                                Full Name <span class="text-red-500">*</span>
                              </label>
                              <div class="relative">
                                <input
                                  type="text"
                                  name={"travelers[#{index}][full_name]"}
                                  value={traveler["full_name"] || traveler[:full_name] || ""}
                                  phx-blur="update_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="full_name"
                                  class={"w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors #{if (traveler["full_name"] || traveler[:full_name] || "") != "", do: "border-green-500 bg-green-50", else: "border-gray-300"}"}
                                  placeholder="Enter full name"
                                  required
                                />
                                <%= if (traveler["full_name"] || traveler[:full_name] || "") != "" do %>
                                  <div class="absolute right-2 top-1/2 transform -translate-y-1/2 text-green-500">
                                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                                    </svg>
                                  </div>
                                <% end %>
                              </div>
                              <%= if (traveler["full_name"] || traveler[:full_name] || "") != "" do %>
                                <button
                                  type="button"
                                  phx-click="clear_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="full_name"
                                  class="mt-1 text-xs text-red-500 hover:text-red-700 hover:bg-red-50 px-2 py-1 rounded transition-colors"
                                  title="Clear field"
                                >
                                  Clear field
                                </button>
                              <% end %>
                            </div>

                            <div>
                              <label class="block text-sm font-medium text-gray-700 mb-1">
                                Identity Card Number <span class="text-red-500">*</span>
                              </label>
                              <div class="relative">
                                <input
                                  type="text"
                                  name={"travelers[#{index}][identity_card_number]"}
                                  value={traveler["identity_card_number"] || traveler[:identity_card_number] || ""}
                                  phx-blur="update_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="identity_card_number"
                                  class={"w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors #{if (traveler["identity_card_number"] || traveler[:identity_card_number] || "") != "", do: "border-green-500 bg-green-50", else: "border-gray-300"}"}
                                  placeholder="Enter identity card number"
                                  required
                                />
                                <%= if (traveler["identity_card_number"] || traveler[:identity_card_number] || "") != "" do %>
                                  <div class="absolute right-2 top-1/2 transform -translate-y-1/2 text-green-500">
                                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                                    </svg>
                                  </div>
                                <% end %>
                              </div>
                              <%= if (traveler["identity_card_number"] || traveler[:identity_card_number] || "") != "" do %>
                                <button
                                  type="button"
                                  phx-click="clear_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="identity_card_number"
                                  class="mt-1 text-xs text-red-500 hover:text-red-700 hover:bg-red-50 px-2 py-1 rounded transition-colors"
                                  title="Clear field"
                                >
                                  Clear field
                                </button>
                              <% end %>
                            </div>

                            <div>
                              <label class="block text-sm font-medium text-gray-700 mb-1">
                                Phone Number <span class="text-red-500">*</span>
                              </label>
                              <div class="relative">
                                <input
                                  type="text"
                                  name={"travelers[#{index}][phone]"}
                                  value={traveler["phone"] || traveler[:phone] || ""}
                                  phx-blur="update_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="phone"
                                  class={"w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors #{if (traveler["phone"] || traveler[:phone] || "") != "", do: "border-green-500 bg-green-50", else: "border-gray-300"}"}
                                  placeholder="Enter phone number"
                                  required
                                />
                                <%= if (traveler["phone"] || traveler[:phone] || "") != "" do %>
                                  <div class="absolute right-2 top-1/2 transform -translate-y-1/2 text-green-500">
                                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                                    </svg>
                                  </div>
                                <% end %>
                              </div>
                              <%= if (traveler["phone"] || traveler[:phone] || "") != "" do %>
                                <button
                                  type="button"
                                  phx-click="clear_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="phone"
                                  class="mt-1 text-xs text-red-500 hover:text-red-700 hover:bg-red-50 px-2 py-1 rounded transition-colors"
                                  title="Clear field"
                                >
                                  Clear field
                                </button>
                              <% end %>
                            </div>

                            <div>
                              <label class="block text-sm font-medium text-gray-700 mb-1">
                                Date of Birth <span class="text-red-500">*</span>
                              </label>
                              <div class="relative">
                                <input
                                  type="date"
                                  id={"traveler_#{index}_date_of_birth"}
                                  name={"travelers[#{index}][date_of_birth]"}
                                  value={traveler["date_of_birth"] || traveler[:date_of_birth] || ""}
                                  phx-hook="DateFieldUpdate"
                                  data-index={index}
                                  data-field="date_of_birth"
                                  class={"w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors #{if (traveler["date_of_birth"] || traveler[:date_of_birth] || "") != "", do: "border-green-500 bg-green-50", else: "border-gray-300"}"}
                                  required
                                />
                                <%= if (traveler["date_of_birth"] || traveler[:date_of_birth] || "") != "" do %>
                                  <div class="absolute right-2 top-1/2 transform -translate-y-1/2 text-green-500">
                                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                                    </svg>
                                  </div>
                                <% end %>
                              </div>
                              <%= if (traveler["date_of_birth"] || traveler[:date_of_birth] || "") != "" do %>
                                <button
                                  type="button"
                                  phx-click="clear_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="date_of_birth"
                                  class="mt-1 text-xs text-red-500 hover:text-red-700 hover:bg-red-50 px-2 py-1 rounded transition-colors"
                                  title="Clear field"
                                >
                                  Clear field
                                </button>
                              <% end %>
                            </div>

                            <div>
                              <label class="block text-sm font-medium text-gray-700 mb-1">
                                Passport Number
                              </label>
                              <div class="relative">
                                <input
                                  type="text"
                                  name={"travelers[#{index}][passport_number]"}
                                  value={traveler["passport_number"] || traveler[:passport_number] || ""}
                                  phx-blur="update_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="passport_number"
                                  class={"w-full border rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 transition-colors #{if (traveler["passport_number"] || traveler[:passport_number] || "") != "", do: "border-blue-500 bg-blue-50", else: "border-gray-300"}"}
                                  placeholder="Enter passport number (optional)"
                                />
                                <%= if (traveler["passport_number"] || traveler[:passport_number] || "") != "" do %>
                                  <div class="absolute right-2 top-1/2 transform -translate-y-1/2 text-blue-500">
                                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                                    </svg>
                                  </div>
                                <% end %>
                              </div>
                              <%= if (traveler["passport_number"] || traveler[:passport_number] || "") != "" do %>
                                <button
                                  type="button"
                                  phx-click="clear_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="passport_number"
                                  class="mt-1 text-xs text-blue-500 hover:text-blue-700 hover:bg-blue-50 px-2 py-1 rounded transition-colors"
                                  title="Clear field"
                                >
                                  Clear field
                                </button>
                              <% end %>
                            </div>
                          </div>
                        </div>

                        <!-- Section 2: Address Information -->
                        <div class="bg-green-50 border border-green-200 rounded-lg p-4">
                          <h5 class="font-medium text-green-900 mb-3">Section 2: Address Information</h5>
                          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                            <div class="md:col-span-2">
                              <label class="block text-sm font-medium text-gray-700 mb-1">
                                Address <span class="text-red-500">*</span>
                              </label>
                              <div class="relative">
                                <textarea
                                  name={"travelers[#{index}][address]"}
                                  rows="2"
                                  phx-blur="update_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="address"
                                  class={"w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors #{if (traveler["address"] || traveler[:address] || "") != "", do: "border-green-500 bg-green-50", else: "border-gray-300"}"}
                                  placeholder="Enter full address"
                                  required
                                ><%= traveler["address"] || traveler[:address] || "" %></textarea>
                                <%= if (traveler["address"] || traveler[:address] || "") != "" do %>
                                  <div class="absolute right-2 top-2 text-green-500">
                                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                                    </svg>
                                  </div>
                                <% end %>
                              </div>
                              <%= if (traveler["address"] || traveler[:address] || "") != "" do %>
                                <button
                                  type="button"
                                  phx-click="clear_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="address"
                                  class="mt-1 text-xs text-red-500 hover:text-red-700 hover:bg-red-50 px-2 py-1 rounded transition-colors"
                                  title="Clear field"
                                >
                                  Clear field
                                </button>
                              <% end %>
                            </div>

                            <div>
                              <label class="block text-sm font-medium text-gray-700 mb-1">
                                Poskod <span class="text-red-500">*</span>
                              </label>
                              <div class="relative">
                                <input
                                  type="text"
                                  name={"travelers[#{index}][poskod]"}
                                  value={traveler["poskod"] || traveler[:poskod] || ""}
                                  phx-blur="update_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="poskod"
                                  class={"w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors #{if (traveler["poskod"] || traveler[:poskod] || "") != "", do: "border-green-500 bg-green-50", else: "border-gray-300"}"}
                                  placeholder="Enter poskod"
                                  required
                                />
                                <%= if (traveler["poskod"] || traveler[:poskod] || "") != "" do %>
                                  <div class="absolute right-2 top-1/2 transform -translate-y-1/2 text-green-500">
                                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                                    </svg>
                                  </div>
                                <% end %>
                              </div>
                              <%= if (traveler["poskod"] || traveler[:poskod] || "") != "" do %>
                                <button
                                  type="button"
                                  phx-click="clear_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="poskod"
                                  class="mt-1 text-xs text-red-500 hover:text-red-700 hover:bg-red-50 px-2 py-1 rounded transition-colors"
                                  title="Clear field"
                                >
                                  Clear field
                                </button>
                              <% end %>
                            </div>

                            <div>
                              <label class="block text-sm font-medium text-gray-700 mb-1">
                                City <span class="text-red-500">*</span>
                              </label>
                              <div class="relative">
                                <input
                                  type="text"
                                  name={"travelers[#{index}][city]"}
                                  value={traveler["city"] || traveler[:city] || ""}
                                  phx-blur="update_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="city"
                                  class={"w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors #{if (traveler["city"] || traveler[:city] || "") != "", do: "border-green-500 bg-green-50", else: "border-gray-300"}"}
                                  placeholder="Enter city"
                                  required
                                />
                                <%= if (traveler["city"] || traveler[:city] || "") != "" do %>
                                  <div class="absolute right-2 top-1/2 transform -translate-y-1/2 text-green-500">
                                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                                    </svg>
                                  </div>
                                <% end %>
                              </div>
                              <%= if (traveler["city"] || traveler[:city] || "") != "" do %>
                                <button
                                  type="button"
                                  phx-click="clear_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="city"
                                  class="mt-1 text-xs text-red-500 hover:text-red-700 hover:bg-red-50 px-2 py-1 rounded transition-colors"
                                  title="Clear field"
                                >
                                  Clear field
                                </button>
                              <% end %>
                            </div>

                            <div>
                              <label class="block text-sm font-medium text-gray-700 mb-1">
                                State <span class="text-red-500">*</span>
                              </label>
                              <div class="relative">
                                <select
                                  name={"travelers[#{index}][state]"}
                                  phx-blur="update_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="state"
                                  class={"w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors #{if (traveler["state"] || traveler[:state] || "") != "", do: "border-green-500 bg-green-50", else: "border-gray-300"}"}
                                  required
                                >
                                  <option value="">Select state</option>
                                  <option value="Johor" selected={traveler["state"] == "Johor" || traveler[:state] == "Johor"}>Johor</option>
                                  <option value="Kedah" selected={traveler["state"] == "Kedah" || traveler[:state] == "Kedah"}>Kedah</option>
                                  <option value="Kelantan" selected={traveler["state"] == "Kelantan" || traveler[:state] == "Kelantan"}>Kelantan</option>
                                  <option value="Melaka" selected={traveler["state"] == "Melaka" || traveler[:state] == "Melaka"}>Melaka</option>
                                  <option value="Negeri Sembilan" selected={traveler["state"] == "Negeri Sembilan" || traveler[:state] == "Negeri Sembilan"}>Negeri Sembilan</option>
                                  <option value="Pahang" selected={traveler["state"] == "Pahang" || traveler[:state] == "Pahang"}>Pahang</option>
                                  <option value="Perak" selected={traveler["state"] == "Perak" || traveler[:state] == "Perak"}>Perak</option>
                                  <option value="Perlis" selected={traveler["state"] == "Perlis" || traveler[:state] == "Perlis"}>Perlis</option>
                                  <option value="Pulau Pinang" selected={traveler["state"] == "Pulau Pinang" || traveler[:state] == "Pulau Pinang"}>Pulau Pinang</option>
                                  <option value="Sabah" selected={traveler["state"] == "Sabah" || traveler[:state] == "Sabah"}>Sabah</option>
                                  <option value="Sarawak" selected={traveler["state"] == "Sarawak" || traveler[:state] == "Sarawak"}>Sarawak</option>
                                  <option value="Selangor" selected={traveler["state"] == "Selangor" || traveler[:state] == "Selangor"}>Selangor</option>
                                  <option value="Terengganu" selected={traveler["state"] == "Terengganu" || traveler[:state] == "Terengganu"}>Terengganu</option>
                                  <option value="Kuala Lumpur" selected={traveler["state"] == "Kuala Lumpur" || traveler[:state] == "Kuala Lumpur"}>Kuala Lumpur</option>
                                  <option value="Labuan" selected={traveler["state"] == "Labuan" || traveler[:state] == "Labuan"}>Labuan</option>
                                  <option value="Putrajaya" selected={traveler["state"] == "Putrajaya" || traveler[:state] == "Putrajaya"}>Putrajaya</option>
                                </select>
                                <%= if (traveler["state"] || traveler[:state] || "") != "" do %>
                                  <div class="absolute right-2 top-1/2 transform -translate-y-1/2 text-green-500">
                                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                                    </svg>
                                  </div>
                                <% end %>
                              </div>
                              <%= if (traveler["state"] || traveler[:state] || "") != "" do %>
                                <button
                                  type="button"
                                  phx-click="clear_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="state"
                                  class="mt-1 text-xs text-red-500 hover:text-red-700 hover:bg-red-50 px-2 py-1 rounded transition-colors"
                                  title="Clear field"
                                >
                                  Clear field
                                </button>
                              <% end %>
                            </div>

                            <div>
                              <label class="block text-sm font-medium text-gray-700 mb-1">
                                Citizenship <span class="text-red-500">*</span>
                              </label>
                              <div class="relative">
                                <select
                                  name={"travelers[#{index}][citizenship]"}
                                  phx-blur="update_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="citizenship"
                                  class={"w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors #{if (traveler["citizenship"] || traveler[:citizenship] || "") != "", do: "border-green-500 bg-green-50", else: "border-gray-300"}"}
                                  required
                                >
                                  <option value="Malaysia" selected={traveler["citizenship"] == "Malaysia" || traveler[:citizenship] == "Malaysia"}>Malaysia</option>
                                  <option value="Other" selected={traveler["citizenship"] == "Other" || traveler[:citizenship] == "Other"}>Other</option>
                                </select>
                                <%= if (traveler["citizenship"] || traveler[:citizenship] || "") != "" do %>
                                  <div class="absolute right-2 top-1/2 transform -translate-y-1/2 text-green-500">
                                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                                    </svg>
                                  </div>
                                <% end %>
                              </div>
                            </div>
                          </div>
                        </div>

                        <!-- Section 3: Emergency Contact and Room Type -->
                        <div class="bg-purple-50 border border-purple-200 rounded-lg p-4">
                          <h5 class="font-medium text-purple-900 mb-3">Section 3: Emergency Contact and Room Type</h5>
                          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                            <div>
                              <label class="block text-sm font-medium text-gray-700 mb-1">
                                Emergency Contact Name <span class="text-red-500">*</span>
                              </label>
                              <div class="relative">
                                <input
                                  type="text"
                                  name={"travelers[#{index}][emergency_contact_name]"}
                                  value={traveler["emergency_contact_name"] || traveler[:emergency_contact_name] || ""}
                                  phx-blur="update_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="emergency_contact_name"
                                  class={"w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors #{if (traveler["emergency_contact_name"] || traveler[:emergency_contact_name] || "") != "", do: "border-green-500 bg-green-50", else: "border-gray-300"}"}
                                  placeholder="Enter emergency contact name"
                                  required
                                />
                                <%= if (traveler["emergency_contact_name"] || traveler[:emergency_contact_name] || "") != "" do %>
                                  <div class="absolute right-2 top-1/2 transform -translate-y-1/2 text-green-500">
                                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                                    </svg>
                                  </div>
                                <% end %>
                              </div>
                              <%= if (traveler["emergency_contact_name"] || traveler[:emergency_contact_name] || "") != "" do %>
                                <button
                                  type="button"
                                  phx-click="clear_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="emergency_contact_name"
                                  class="mt-1 text-xs text-red-500 hover:text-red-700 hover:bg-red-50 px-2 py-1 rounded transition-colors"
                                  title="Clear field"
                                >
                                  Clear field
                                </button>
                              <% end %>
                            </div>

                            <div>
                              <label class="block text-sm font-medium text-gray-700 mb-1">
                                Emergency Contact Phone <span class="text-red-500">*</span>
                              </label>
                              <div class="relative">
                                <input
                                  type="text"
                                  name={"travelers[#{index}][emergency_contact_phone]"}
                                  value={traveler["emergency_contact_phone"] || traveler[:emergency_contact_phone] || ""}
                                  phx-blur="update_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="emergency_contact_phone"
                                  class={"w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors #{if (traveler["emergency_contact_phone"] || traveler[:emergency_contact_phone] || "") != "", do: "border-green-500 bg-green-50", else: "border-gray-300"}"}
                                  placeholder="Enter emergency contact phone"
                                  required
                                />
                                <%= if (traveler["emergency_contact_phone"] || traveler[:emergency_contact_phone] || "") != "" do %>
                                  <div class="absolute right-2 top-1/2 transform -translate-y-1/2 text-green-500">
                                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                                    </svg>
                                  </div>
                                <% end %>
                              </div>
                              <%= if (traveler["emergency_contact_phone"] || traveler[:emergency_contact_phone] || "") != "" do %>
                                <button
                                  type="button"
                                  phx-click="clear_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="emergency_contact_phone"
                                  class="mt-1 text-xs text-red-500 hover:text-red-700 hover:bg-red-50 px-2 py-1 rounded transition-colors"
                                  title="Clear field"
                                >
                                  Clear field
                                </button>
                              <% end %>
                            </div>

                            <div>
                              <label class="block text-sm font-medium text-gray-700 mb-1">
                                Emergency Contact Relationship <span class="text-red-500">*</span>
                              </label>
                              <div class="relative">
                                <select
                                  name={"travelers[#{index}][emergency_contact_relationship]"}
                                  phx-blur="update_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="emergency_contact_relationship"
                                  class={"w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors #{if (traveler["emergency_contact_relationship"] || traveler[:emergency_contact_relationship] || "") != "", do: "border-green-500 bg-green-50", else: "border-gray-300"}"}
                                  required
                                >
                                  <option value="">Select relationship</option>
                                  <option value="Spouse" selected={traveler["emergency_contact_relationship"] == "Spouse" || traveler[:emergency_contact_relationship] == "Spouse"}>Spouse</option>
                                  <option value="Parent" selected={traveler["emergency_contact_relationship"] == "Parent" || traveler[:emergency_contact_relationship] == "Parent"}>Parent</option>
                                  <option value="Child" selected={traveler["emergency_contact_relationship"] == "Child" || traveler[:emergency_contact_relationship] == "Child"}>Child</option>
                                  <option value="Sibling" selected={traveler["emergency_contact_relationship"] == "Sibling" || traveler[:emergency_contact_relationship] == "Sibling"}>Sibling</option>
                                  <option value="Friend" selected={traveler["emergency_contact_relationship"] == "Friend" || traveler[:emergency_contact_relationship] == "Friend"}>Friend</option>
                                  <option value="Other" selected={traveler["emergency_contact_relationship"] == "Other" || traveler[:emergency_contact_relationship] == "Other"}>Other</option>
                                </select>
                                <%= if (traveler["emergency_contact_relationship"] || traveler[:emergency_contact_relationship] || "") != "" do %>
                                  <div class="absolute right-2 top-1/2 transform -translate-y-1/2 text-green-500">
                                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                                    </svg>
                                  </div>
                                <% end %>
                              </div>
                              <%= if (traveler["emergency_contact_relationship"] || traveler[:emergency_contact_relationship] || "") != "" do %>
                                <button
                                  type="button"
                                  phx-click="clear_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="emergency_contact_relationship"
                                  class="mt-1 text-xs text-red-500 hover:text-red-700 hover:bg-red-50 px-2 py-1 rounded transition-colors"
                                  title="Clear field"
                                >
                                  Clear field
                                </button>
                              <% end %>
                            </div>

                            <div>
                              <label class="block text-sm font-medium text-gray-700 mb-1">
                                Room Type <span class="text-red-500">*</span>
                              </label>
                              <div class="relative">
                                <select
                                  name={"travelers[#{index}][room_type]"}
                                  phx-blur="update_traveler_field"
                                  phx-value-index={index}
                                  phx-value-field="room_type"
                                  class={"w-full border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors #{if (traveler["room_type"] || traveler[:room_type] || "") != "", do: "border-green-500 bg-green-50", else: "border-gray-300"}"}
                                  required
                                >
                                  <option value="standard" selected={traveler["room_type"] == "standard" || traveler[:room_type] == "standard"}>Standard</option>
                                  <option value="deluxe" selected={traveler["room_type"] == "deluxe" || traveler[:room_type] == "deluxe"}>Deluxe</option>
                                  <option value="suite" selected={traveler["room_type"] == "suite" || traveler[:room_type] == "suite"}>Suite</option>
                                  <option value="family" selected={traveler["room_type"] == "family" || traveler[:room_type] == "family"}>Family</option>
                                </select>
                                <%= if (traveler["room_type"] || traveler[:room_type] || "") != "" do %>
                                  <div class="absolute right-2 top-1/2 transform -translate-y-1/2 text-green-500">
                                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                                    </svg>
                                  </div>
                                <% end %>
                              </div>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>

                <!-- Add Traveler Button -->
                <div class="mt-6 flex justify-center">
                  <button
                    type="button"
                    phx-click="add_traveler"
                    class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium mr-4"
                  >
                    + Add New Traveler
                  </button>
                </div>

                <!-- Action Buttons -->
                <div class="mt-6 flex justify-center space-x-4">
                  <button
                    type="button"
                    phx-click="save_travelers"
                    class="bg-green-600 text-white px-6 py-2 rounded-lg hover:bg-green-700 transition-colors font-medium"
                  >
                    Save Traveler Information
                  </button>
                  <button
                    type="button"
                    phx-click="clear_all_fields"
                    class="bg-red-500 text-white px-6 py-2 rounded-lg hover:bg-red-600 transition-colors font-medium"
                  >
                    Clear All Fields
                  </button>
                </div>
              </div>

              <!-- Summary -->
              <div class="bg-gray-50 rounded-lg p-4">
                <h3 class="font-medium text-gray-900 mb-3">Travelers Summary</h3>
                <div class="space-y-2 text-sm">
                  <div class="flex justify-between">
                    <span class="text-gray-600">Number of persons:</span>
                    <span><%= @number_of_persons %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Traveler details required:</span>
                    <span class="text-blue-600 font-medium">Yes</span>
                  </div>
                  <%= if @number_of_persons == 1 do %>
                    <div class="flex justify-between">
                      <span class="text-gray-600">Booking type:</span>
                      <span class={if @is_booking_for_self, do: "text-blue-600 font-medium", else: "text-purple-600 font-medium"}>
                        <%= if @is_booking_for_self, do: "For yourself", else: "For someone else" %>
                      </span>
                    </div>
                  <% end %>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Details filled:</span>
                    <span class={if Enum.all?(@travelers, fn t -> (t["full_name"] || t[:full_name] || "") != "" and (t["identity_card_number"] || t[:identity_card_number] || "") != "" and (t["phone"] || t[:phone] || "") != "" and (t["date_of_birth"] || t[:date_of_birth] || "") != "" and (t["address"] || t[:address] || "") != "" and (t["poskod"] || t[:poskod] || "") != "" and (t["city"] || t[:city] || "") != "" and (t["state"] || t[:state] || "") != "" and (t["emergency_contact_name"] || t[:emergency_contact_name] || "") != "" and (t["emergency_contact_phone"] || t[:emergency_contact_phone] || "") != "" end), do: "text-green-600 font-medium", else: "text-red-600 font-medium"}>
                      <%= if Enum.all?(@travelers, fn t -> (t["full_name"] || t[:full_name] || "") != "" and (t["identity_card_number"] || t[:identity_card_number] || "") != "" and (t["phone"] || t[:phone] || "") != "" and (t["date_of_birth"] || t[:date_of_birth] || "") != "" and (t["address"] || t[:address] || "") != "" and (t["poskod"] || t[:poskod] || "") != "" and (t["city"] || t[:city] || "") != "" and (t["state"] || t[:state] || "") != "" and (t["emergency_contact_name"] || t[:emergency_contact_name] || "") != "" and (t["emergency_contact_phone"] || t[:emergency_contact_phone] || "") != "" end), do: "Complete", else: "Incomplete" %>
                    </span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Form status:</span>
                    <span class={if Enum.all?(@travelers, fn t -> (t["full_name"] || t[:full_name] || "") == "" and (t["identity_card_number"] || t[:identity_card_number] || "") == "" and (t["phone"] || t[:phone] || "") == "" end), do: "text-blue-600 font-medium", else: "text-gray-600 font-medium"}>
                      <%= if Enum.all?(@travelers, fn t -> (t["full_name"] || t[:full_name] || "") == "" and (t["identity_card_number"] || t[:identity_card_number] || "") == "" and (t["phone"] || t[:phone] || "") == "" end), do: "Ready for new entry", else: "Has data" %>
                    </span>
                  </div>
                </div>
              </div>

              <div class="flex justify-between">
                <button
                  type="button"
                  phx-click="prev_step"
                  class="bg-gray-300 text-gray-700 px-6 py-2 rounded-lg hover:bg-gray-400 transition-colors font-medium"
                >
                  Back
                </button>
                <div class="flex space-x-3">

                  <button
                    type="button"
                    phx-click="go_to_next_step"
                    class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium"
                  >
                    Continue
                  </button>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Step 3: Payment -->
        <%= if @current_step == 3 do %>
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold text-gray-900 mb-4">Payment Details</h2>

            <form phx-submit="validate_booking" class="space-y-6" novalidate>
                                      <!-- Progress Status -->
            <%= if @saved_payment_progress do %>
              <div class="bg-green-50 border border-green-200 rounded-lg p-4">
                <div class="flex items-center">
                  <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <p class="text-sm text-green-700">
                      <strong>Progress Saved!</strong> Your payment information has been saved. You can continue or go back to make changes.
                    </p>
                    <div class="mt-2 text-xs text-green-600">
                      <strong>Saved:</strong>
                      <%= if @payment_method != "", do: "Payment Method: #{String.replace(@payment_method, "_", " ") |> String.capitalize()}" %>
                      <%= if @payment_plan != "full_payment", do: ", Payment Plan: #{String.replace(@payment_plan, "_", " ")}" %>
                      <%= if @notes != "", do: ", Notes: #{String.slice(@notes, 0, 50)}#{if String.length(@notes) > 50, do: "...", else: ""}" %>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>

            <!-- Payment Progress Summary -->
            <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
              <h3 class="font-medium text-blue-900 mb-3">Payment Progress Summary</h3>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                <div class="space-y-2">
                  <div class="flex items-center">
                    <span class="text-blue-700">Payment Method:</span>
                    <span class="ml-2 font-medium">
                      <%= if @payment_method != "", do: String.replace(@payment_method, "_", " ") |> String.capitalize(), else: "Not selected" %>
                    </span>
                    <%= if @payment_method != "" do %>
                      <svg class="w-4 h-4 text-green-500 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                      </svg>
                    <% end %>
                  </div>
                  <div class="flex items-center">
                    <span class="text-blue-700">Payment Plan:</span>
                    <span class="ml-2 font-medium">
                      <%= String.replace(@payment_plan, "_", " ") |> String.capitalize() %>
                    </span>
                    <svg class="w-4 h-4 text-green-500 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                    </svg>
                  </div>
                </div>
                <div class="space-y-2">
                  <div class="flex items-center">
                    <span class="text-blue-700">Notes:</span>
                    <span class="ml-2 font-medium">
                      <%= if @notes != "", do: "Added", else: "None" %>
                    </span>
                    <%= if @notes != "" do %>
                      <svg class="w-4 h-4 text-green-500 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                      </svg>
                    <% end %>
                  </div>
                  <div class="flex items-center">
                    <span class="text-blue-700">Deposit Amount:</span>
                    <span class="ml-2 font-medium">RM <%= @deposit_amount %></span>
                    <svg class="w-4 h-4 text-green-500 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                    </svg>
                  </div>
                </div>
              </div>
            </div>

              <!-- Payment Plan -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Payment Plan
                </label>
                <div class="space-y-2">
                  <label class="flex items-center">
                    <input
                      type="radio"
                      name="booking[payment_plan]"
                      value="full_payment"
                      checked={@payment_plan == "full_payment"}
                      phx-click="update_payment_plan"
                      phx-value-payment_plan="full_payment"
                      class="mr-2"
                    />
                    <span class="text-sm">Full Payment (RM <%= @total_amount %>)</span>
                  </label>
                  <label class="flex items-center">
                    <input
                      type="radio"
                      name="booking[payment_plan]"
                      value="installment"
                      checked={@payment_plan == "installment"}
                      phx-click="update_payment_plan"
                      phx-value-payment_plan="installment"
                      class="mr-2"
                    />
                    <span class="text-sm">Installment Plan</span>
                  </label>
                </div>
              </div>

              <!-- Deposit Amount (for installment) -->
              <%= if @payment_plan == "installment" do %>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    Deposit Amount (Minimum: RM <%= Decimal.mult(@total_amount, Decimal.new("0.2")) %>)
                  </label>
                  <input
                    type="number"
                    name="booking[deposit_amount]"
                    value={@deposit_amount}
                    min={Decimal.mult(@total_amount, Decimal.new("0.2"))}
                    max={@total_amount}
                    step="0.01"
                    phx-change="update_deposit_amount"
                    class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="Enter deposit amount"
                  />
                </div>
              <% end %>

              <!-- Payment Method -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Payment Method
                </label>
                <select
                  name="booking[payment_method]"
                  phx-change="update_payment_method"
                  class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  value={@payment_method}
                  phx-debounce="100"
                >
                  <option value="">Select payment method</option>
                  <option value="toyyibpay">ToyyibPay (FPX & Credit Card)</option>
                  <option value="bank_transfer">Bank Transfer</option>
                  <option value="cash">Cash</option>
                </select>
              </div>

              <!-- Notes -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Special Requests or Notes
                </label>
                <textarea
                  name="booking[notes]"
                  rows="3"
                  phx-change="update_notes"
                  class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Any special requests or notes for the admin..."
                ><%= @notes %></textarea>
              </div>

              <!-- Summary -->
              <div class="bg-gray-50 rounded-lg p-4">
                <h3 class="font-medium text-gray-900 mb-3">Payment Summary</h3>
                <div class="space-y-2 text-sm">
                  <div class="flex justify-between">
                    <span class="text-gray-600">Number of persons:</span>
                    <span><%= @number_of_persons %></span>
                  </div>
                  <div class="flex justify-between border-t pt-2">
                    <span class="text-gray-600 font-medium">Total amount:</span>
                    <span class="font-bold text-green-600">RM <%= @total_amount %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Deposit amount:</span>
                    <span class="font-medium">RM <%= @deposit_amount %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Payment plan:</span>
                    <span class="capitalize"><%= String.replace(@payment_plan, "_", " ") %></span>
                  </div>
                </div>
              </div>

              <div class="flex justify-between">
                <button
                  type="button"
                  phx-click="prev_step"
                  class="bg-gray-700 text-white px-6 py-2 rounded-lg hover:bg-gray-800 transition-colors font-medium"
                >
                  Back
                </button>
                <div class="flex space-x-3">
                  <button
                    type="button"
                    phx-click="clear_payment_info"
                    class="bg-red-500 text-white px-6 py-2 rounded-lg hover:bg-red-600 transition-colors font-medium"
                  >
                    Clear All
                  </button>
                  <button
                    type="button"
                    phx-click="save_payment_info"
                    class="bg-green-600 text-white px-6 py-2 rounded-lg hover:bg-green-700 transition-colors font-medium"
                  >
                    Save Payment Info
                  </button>
                  <button
                    type="button"
                    phx-click="go_to_next_step"
                    class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium"
                  >
                    Continue
                  </button>
                </div>
              </div>
            </form>
          </div>
        <% end %>

        <!-- Step 4: Review & Confirm -->
        <%= if @current_step == 4 do %>
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold text-gray-900 mb-4">Review & Confirm Booking</h2>

            <div class="space-y-6">

              <!-- Progress Status for Step 4 -->
              <%= if @saved_package_progress || @saved_travelers_progress || @saved_payment_progress do %>
                <div class="bg-green-50 border border-green-200 rounded-lg p-4">
                  <div class="flex items-center">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <p class="text-sm text-green-700">
                        <strong>Progress Saved!</strong> Your booking information has been saved. You can now review and confirm your booking.
                      </p>
                      <div class="mt-2 text-xs text-green-600">
                        <%= if @saved_payment_progress do %>
                          <strong>Payment:</strong> Method, plan, and notes saved ✓
                        <% end %>
                        <%= if @saved_travelers_progress do %>
                          <strong>Travelers:</strong> All details saved ✓
                        <% end %>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>

              <!-- Package Summary -->
              <div class="border rounded-lg p-4">
                <h3 class="font-medium text-gray-900 mb-3">Package Details</h3>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                  <div>
                    <span class="text-gray-600">Package:</span>
                    <span class="font-medium ml-2"><%= @package.name %></span>
                  </div>
                  <div>
                    <span class="text-gray-600">Schedule:</span>
                    <span class="font-medium ml-2">
                      <%= Calendar.strftime(@schedule.departure_date, "%B %d, %Y") %> -
                      <%= Calendar.strftime(@schedule.return_date, "%B %d, %Y") %>
                    </span>
                  </div>
                  <div>
                    <span class="text-gray-600">Travelers:</span>
                    <span class="font-medium ml-2"><%= @number_of_persons %></span>
                  </div>
                  <div>
                    <span class="text-gray-600">Payment Method:</span>
                    <span class="font-medium ml-2 capitalize"><%= String.replace(@payment_method, "_", " ") %></span>
                  </div>
                </div>
              </div>

              <!-- Travelers Details -->
              <div class="border rounded-lg p-4">
                <h3 class="font-medium text-gray-900 mb-3">Travelers Details</h3>

                <!-- Table for larger screens -->
                <div class="hidden lg:block overflow-x-auto">
                  <table class="min-w-full bg-white border border-gray-200 rounded-lg">
                    <thead class="bg-gray-50">
                      <tr class="text-xs font-medium text-gray-700 uppercase tracking-wider">
                        <th class="px-3 py-3 text-left border-r border-gray-200">Traveler</th>
                        <th class="px-3 py-3 text-left border-r border-gray-200">Full Name</th>
                        <th class="px-3 py-3 text-left border-r border-gray-200">Identity Card</th>
                        <th class="px-3 py-3 text-left border-r border-gray-200">Passport</th>
                        <th class="px-3 py-3 text-left border-r border-gray-200">Phone</th>
                        <th class="px-3 py-3 text-left border-r border-gray-200">Date of Birth</th>
                        <th class="px-3 py-3 text-left border-r border-gray-200">Address</th>
                        <th class="px-3 py-3 text-left border-r border-gray-200">Poskod</th>
                        <th class="px-3 py-3 text-left border-r border-gray-200">City</th>
                        <th class="px-3 py-3 text-left border-r border-gray-200">State</th>
                        <th class="px-3 py-3 text-left border-r border-gray-200">Citizenship</th>
                        <th class="px-3 py-3 text-left border-r border-gray-200">Emergency Contact</th>
                        <th class="px-3 py-3 text-left border-r border-gray-200">Emergency Phone</th>
                        <th class="px-3 py-3 text-left border-r border-gray-200">Emergency Relationship</th>
                        <th class="px-3 py-3 text-left">Room Type</th>
                      </tr>
                    </thead>
                    <tbody class="bg-white divide-y divide-gray-200">
                  <%= for {traveler, index} <- Enum.with_index(@travelers) do %>
                        <tr class="hover:bg-gray-50">
                          <td class="px-3 py-4 text-sm font-medium text-gray-900 border-r border-gray-200">
                            <div class="flex items-center">
                              <%= if @number_of_persons == 1 and @is_booking_for_self do %>
                                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">You</span>
                              <% else %>
                                <%= if @number_of_persons == 1 do %>
                                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">Traveler</span>
                                <% else %>
                                  <%= if index == 0 do %>
                                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800">Lead (<%= index + 1 %>)</span>
                                  <% else %>
                                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800"><%= index + 1 %></span>
                                  <% end %>
                                <% end %>
                              <% end %>
                            </div>
                          </td>
                          <td class="px-3 py-4 text-sm text-gray-900 border-r border-gray-200 max-w-xs">
                            <div>
                              <%= traveler[:full_name] || traveler["full_name"] || "" %>
                            </div>
                          </td>
                          <td class="px-3 py-4 text-sm text-gray-900 border-r border-gray-200">
                            <div class="font-mono text-xs">
                              <%= traveler[:identity_card_number] || traveler["identity_card_number"] || "" %>
                            </div>
                          </td>
                          <td class="px-3 py-4 text-sm text-gray-900 border-r border-gray-200">
                            <div class="font-mono text-xs">
                              <%= if (traveler[:passport_number] || traveler["passport_number"] || "") != "" do %>
                                <%= traveler[:passport_number] || traveler["passport_number"] || "" %>
                              <% else %>
                                <span class="text-gray-400 italic">Not provided</span>
                              <% end %>
                            </div>
                          </td>
                          <td class="px-3 py-4 text-sm text-gray-900 border-r border-gray-200">
                            <div class="font-mono text-xs">
                              <%= traveler[:phone] || traveler["phone"] || "" %>
                            </div>
                          </td>
                          <td class="px-3 py-4 text-sm text-gray-900 border-r border-gray-200">
                            <div class="text-xs">
                              <%= traveler[:date_of_birth] || traveler["date_of_birth"] || "" %>
                            </div>
                          </td>
                          <td class="px-3 py-4 text-sm text-gray-900 border-r border-gray-200 max-w-xs">
                            <div>
                              <%= traveler[:address] || traveler["address"] || "" %>
                            </div>
                          </td>
                          <td class="px-3 py-4 text-sm text-gray-900 border-r border-gray-200">
                            <div class="text-xs">
                              <%= traveler[:poskod] || traveler["poskod"] || "" %>
                            </div>
                          </td>
                          <td class="px-3 py-4 text-sm text-gray-900 border-r border-gray-200">
                            <div class="text-xs">
                              <%= traveler[:city] || traveler["city"] || "" %>
                            </div>
                          </td>
                          <td class="px-3 py-4 text-sm text-gray-900 border-r border-gray-200">
                            <div class="text-xs">
                              <%= traveler[:state] || traveler["state"] || "" %>
                            </div>
                          </td>
                          <td class="px-3 py-4 text-sm text-gray-900 border-r border-gray-200">
                            <div class="text-xs">
                              <%= traveler[:citizenship] || traveler["citizenship"] || "" %>
                            </div>
                          </td>
                          <td class="px-3 py-4 text-sm text-gray-900 border-r border-gray-200 max-w-xs">
                            <div>
                              <%= traveler[:emergency_contact_name] || traveler["emergency_contact_name"] || "" %>
                            </div>
                          </td>
                          <td class="px-3 py-4 text-sm text-gray-900 border-r border-gray-200">
                            <div class="font-mono text-xs">
                              <%= traveler[:emergency_contact_phone] || traveler["emergency_contact_phone"] || "" %>
                            </div>
                          </td>
                          <td class="px-3 py-4 text-sm text-gray-900 border-r border-gray-200">
                            <div class="text-xs">
                              <%= traveler[:emergency_contact_relationship] || traveler["emergency_contact_relationship"] || "" %>
                            </div>
                          </td>
                          <td class="px-3 py-4 text-sm text-gray-900">
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800 capitalize">
                              <%= traveler[:room_type] || traveler["room_type"] || "" %>
                            </span>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>

                <!-- Cards for mobile/tablet screens -->
                <div class="lg:hidden space-y-4">
                  <%= for {traveler, index} <- Enum.with_index(@travelers) do %>
                    <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
                      <div class="flex items-center justify-between mb-3">
                        <h4 class="font-medium text-gray-800">
                        <%= if(@number_of_persons == 1 and @is_booking_for_self, do: "Your Details", else: if(@number_of_persons == 1, do: "Traveler Details", else: if(index == 0, do: "Traveler #{index + 1} (Person In Charge)", else: "Traveler #{index + 1}"))) %>
                      </h4>
                        <%= if @number_of_persons == 1 and @is_booking_for_self do %>
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">You</span>
                        <% else %>
                          <%= if index == 0 and @number_of_persons > 1 do %>
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800">Lead</span>
                          <% end %>
                        <% end %>
                        </div>

                      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
                        <div>
                          <span class="text-gray-600 font-medium">Full Name:</span>
                          <div class="mt-1 text-gray-900"><%= traveler[:full_name] || traveler["full_name"] || "" %></div>
                        </div>
                        <div>
                          <span class="text-gray-600 font-medium">Identity Card:</span>
                          <div class="mt-1 text-gray-900 font-mono text-xs"><%= traveler[:identity_card_number] || traveler["identity_card_number"] || "" %></div>
                        </div>
                        <div>
                          <span class="text-gray-600 font-medium">Passport:</span>
                          <div class="mt-1 text-gray-900 font-mono text-xs">
                            <%= if (traveler[:passport_number] || traveler["passport_number"] || "") != "" do %>
                              <%= traveler[:passport_number] || traveler["passport_number"] || "" %>
                            <% else %>
                              <span class="text-gray-400 italic">Not provided</span>
                            <% end %>
                          </div>
                        </div>
                        <div>
                          <span class="text-gray-600 font-medium">Phone:</span>
                          <div class="mt-1 text-gray-900 font-mono text-xs"><%= traveler[:phone] || traveler["phone"] || "" %></div>
                        </div>
                        <div>
                          <span class="text-gray-600 font-medium">Date of Birth:</span>
                          <div class="mt-1 text-gray-900"><%= traveler[:date_of_birth] || traveler["date_of_birth"] || "" %></div>
                        </div>
                        <div class="sm:col-span-2">
                          <span class="text-gray-600 font-medium">Address:</span>
                          <div class="mt-1 text-gray-900"><%= traveler[:address] || traveler["address"] || "" %></div>
                        </div>
                        <div>
                          <span class="text-gray-600 font-medium">Poskod:</span>
                          <div class="mt-1 text-gray-900"><%= traveler[:poskod] || traveler["poskod"] || "" %></div>
                        </div>
                        <div>
                          <span class="text-gray-600 font-medium">City:</span>
                          <div class="mt-1 text-gray-900"><%= traveler[:city] || traveler["city"] || "" %></div>
                        </div>
                        <div>
                          <span class="text-gray-600 font-medium">State:</span>
                          <div class="mt-1 text-gray-900"><%= traveler[:state] || traveler["state"] || "" %></div>
                        </div>
                        <div>
                          <span class="text-gray-600 font-medium">Citizenship:</span>
                          <div class="mt-1 text-gray-900"><%= traveler[:citizenship] || traveler["citizenship"] || "" %></div>
                        </div>
                        <div>
                          <span class="text-gray-600 font-medium">Emergency Contact:</span>
                          <div class="mt-1 text-gray-900"><%= traveler[:emergency_contact_name] || traveler["emergency_contact_name"] || "" %></div>
                        </div>
                        <div>
                          <span class="text-gray-600 font-medium">Emergency Phone:</span>
                          <div class="mt-1 text-gray-900 font-mono text-xs"><%= traveler[:emergency_contact_phone] || traveler["emergency_contact_phone"] || "" %></div>
                        </div>
                        <div>
                          <span class="text-gray-600 font-medium">Emergency Relationship:</span>
                          <div class="mt-1 text-gray-900"><%= traveler[:emergency_contact_relationship] || traveler["emergency_contact_relationship"] || "" %></div>
                        </div>
                        <div>
                          <span class="text-gray-600 font-medium">Room Type:</span>
                          <div class="mt-1">
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800 capitalize">
                              <%= traveler[:room_type] || traveler["room_type"] || "" %>
                            </span>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>

              <!-- Payment Summary -->
              <div class="border rounded-lg p-4">
                <h3 class="font-medium text-gray-900 mb-3">Payment Summary</h3>
                <div class="space-y-2 text-sm">
                  <div class="flex justify-between">
                    <span class="text-gray-600">Number of persons:</span>
                    <span><%= @number_of_persons %></span>
                  </div>
                  <div class="flex justify-between border-t pt-2">
                    <span class="text-gray-900 font-medium">Total amount:</span>
                    <span class="text-gray-900 font-bold text-green-600">RM <%= @total_amount %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Deposit amount:</span>
                    <span class="font-medium">RM <%= @deposit_amount %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Payment plan:</span>
                    <span class="capitalize"><%= String.replace(@payment_plan, "_", " ") %></span>
                  </div>
                </div>
              </div>

              <!-- Notes -->
              <%= if @notes != "" do %>
                <div class="border rounded-lg p-4">
                  <h3 class="font-medium text-gray-900 mb-2">Special Requests</h3>
                  <p class="text-sm text-gray-600"><%= @notes %></p>
                </div>
              <% end %>

              <!-- Terms and Conditions -->
              <div class="border rounded-lg p-4">
                <div class="flex items-start">
                  <input
                    type="checkbox"
                    id="terms"
                    class="mt-1 mr-3"
                    required
                    phx-hook="TermsValidation"
                  />
                  <label for="terms" class="text-sm text-gray-600">
                    I agree to the terms and conditions and understand that this booking is subject to confirmation by Umrahly.
                  </label>
                </div>
              </div>

              <div class="flex justify-between">
                <button
                  type="button"
                  phx-click="prev_step"
                  class="bg-gray-300 text-gray-700 px-6 py-2 rounded-lg hover:bg-gray-400 transition-colors font-medium"
                >
                  Back
                </button>
                <button
                  type="button"
                  phx-click="create_booking"
                  class="bg-green-600 text-white px-8 py-2 rounded-lg hover:bg-green-700 transition-colors font-medium opacity-50 cursor-not-allowed"
                  id="confirm-booking-btn"
                  disabled
                >
                  Confirm & Proceed to Payment
                </button>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Step 5: Success -->
        <%= if @current_step == 5 do %>
          <%= if @requires_online_payment do %>
            <!-- Online Payment Success -->
            <div
              id="payment-gateway-container"
              class="bg-white rounded-lg shadow p-6 text-center"
              phx-hook="PaymentGatewayRedirect"
              data-requires-online-payment={@requires_online_payment}
              data-payment-gateway-url={@payment_gateway_url}>
              <div class="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg class="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
                </svg>
              </div>

              <h2 class="text-2xl font-bold text-gray-900 mb-2">Booking Confirmed!</h2>
              <p class="text-gray-600 mb-6">
                Your booking has been created successfully. You are being redirected to the payment gateway to complete your payment.
              </p>

              <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
                <div class="flex">
                  <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <p class="text-sm text-blue-700">
                      <strong>Payment Gateway:</strong> <%= String.replace(@payment_method, "_", " ") |> String.capitalize() %>
                    </p>
                    <p class="text-sm text-blue-700 mt-1">
                      Complete your payment securely on the external payment gateway.
                    </p>
                  </div>
                </div>
              </div>
                <div class="space-y-3">
                <button
                  type="button"
                  onclick={"window.open('#{@payment_gateway_url}', '_blank')"}
                  class="inline-block bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium"
                >
                  Go to Payment Gateway Now
                </button>
                <button
                  type="button"
                  onclick={"window.location.href='#{@payment_gateway_url}'"}
                  class="inline-block bg-green-600 text-white px-6 py-2 rounded-lg hover:bg-green-700 transition-colors font-medium ml-3"
                >
                  Redirect to Payment Gateway
                </button>
                <a
                  href={~p"/dashboard"}
                  class="inline-block bg-gray-300 text-gray-700 px-6 py-2 rounded-lg hover:bg-gray-400 transition-colors font-medium ml-3"
                >
                  Go to Dashboard
                </a>
              </div>
            </div>
          <% else %>
            <!-- Offline Payment Success -->
            <div class="bg-white rounded-lg shadow p-6 text-center">
              <div class="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg class="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                </svg>
              </div>

              <h2 class="text-2xl font-bold text-gray-900 mb-2">Booking Confirmed!</h2>
              <p class="text-gray-600 mb-6">
                Your booking has been created successfully. Please complete your payment using the selected payment method.
              </p>

              <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
                <div class="flex">
                  <div class="flex-shrink-0">
                    <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
                      <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <p class="text-sm text-yellow-700">
                      <strong>Payment Method:</strong> <%= String.replace(@payment_method, "_", " ") |> String.capitalize() %>
                    </p>
                    <p class="text-sm text-yellow-700 mt-1">
                      Please contact our team to arrange payment completion.
                    </p>
                  </div>
                </div>
              </div>

              <!-- Payment Proof Submission Section -->
              <%= if !@payment_proof_file do %>
                <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
                  <div class="flex items-center justify-between mb-3">
                    <h3 class="text-lg font-medium text-blue-900">Submit Payment Proof</h3>
                    <button
                  type="button"
                  phx-click="toggle_payment_proof_form"
                  phx-prevent-default
                  class="text-blue-600 hover:text-blue-800 text-sm font-medium"
                >
                  <%= if @show_payment_proof_form, do: "Hide Form", else: "Show Form" %>
                </button>
                  </div>

                  <p class="text-sm text-blue-700 mb-3">
                    After completing your payment, please upload proof of payment (receipt, bank transfer slip, etc.) for admin approval.
                  </p>

                  <%= if @show_payment_proof_form do %>
                    <form phx-submit="submit_payment_proof" phx-change="validate_payment_proof" class="space-y-4 text-left" id="payment-proof-form">
                     <div>
                        <label class="block text-sm font-medium text-blue-900 mb-2">
                          Payment Proof File <span class="text-red-500">*</span>
                        </label>
                        <div class="w-full border border-blue-300 rounded-lg px-3 py-2 focus-within:ring-2 focus-within:ring-blue-500">
                        <.live_file_input
                          upload={@uploads.payment_proof}
                          class="w-full border-0 focus:outline-none"
                        />
                        </div>
                        <p class="text-xs text-blue-600 mt-1">
                          Accepted formats: PDF, JPG, PNG, DOC, DOCX (Max 5MB)
                        </p>

                        <!-- Show selected file info -->
                        <%= for entry <- @uploads.payment_proof.entries do %>
                          <div class="mt-2 p-2 bg-blue-50 border border-blue-200 rounded">
                            <div class="flex items-center justify-between">
                              <span class="text-sm text-blue-700"><%= entry.client_name %></span>
                              <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} class="text-red-500 hover:text-red-700">
                                Remove
                              </button>
                            </div>
                            <%= for err <- upload_errors(@uploads.payment_proof, entry) do %>
                              <div class="text-red-500 text-xs mt-1"><%= error_to_string(err) %></div>
                            <% end %>
                          </div>
                        <% end %>
                        <!-- Show upload progress -->
                        <%= for entry <- @uploads.payment_proof.entries do %>
                          <div class="mt-2">
                            <div class="text-xs text-blue-600">
                              <%= if entry.done?, do: "Uploaded: #{entry.client_name}", else: "Uploading: #{entry.client_name}" %>
                            </div>
                            <%= if !entry.done? do %>
                              <div class="w-full bg-gray-200 rounded-full h-2">
                                <div class="bg-blue-600 h-2 rounded-full transition-all duration-300" style={"width: #{entry.progress}%"}></div>
                              </div>
                            <% end %>
                          </div>
                        <% end %>

                      </div>
                      <div>
                        <label class="block text-sm font-medium text-blue-900 mb-2">
                          Additional Notes
                        </label>
                        <textarea
                          rows="3"
                          name="payment_proof_notes"
                          placeholder="Any additional information about your payment..."
                          class="w-full border border-blue-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                        ><%= @payment_proof_notes %></textarea>
                      </div>
                      <button
                        type="submit"
                        class="w-full bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium"
                      >
                        Submit Payment Proof
                      </button>
                    </form>
                  <% end %>
                </div>
              <% end %>

              <!-- Display Submitted Payment Proof -->
              <%= if @payment_proof_file do %>
                <div class="bg-green-50 border border-green-200 rounded-lg p-4 mb-6">
                  <div class="flex items-center mb-3">
                    <div class="flex-shrink-0">
                      <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <h3 class="text-lg font-medium text-green-900">Payment Proof Submitted</h3>
                      <p class="text-sm text-green-700">Your payment proof has been submitted and is pending admin review.</p>
                    </div>
                  </div>

                  <div class="bg-white border border-green-200 rounded-lg p-3">
                    <div class="flex items-center justify-between">
                      <div class="flex items-center">
                        <svg class="h-4 w-4 text-green-500 mr-2" viewBox="0 0 20 20" fill="currentColor">
                          <path fill-rule="evenodd" d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z" clip-rule="evenodd" />
                        </svg>
                        <span class="text-sm font-medium text-green-900"><%= @payment_proof_file %></span>
                      </div>
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                        Pending Review
                      </span>
                    </div>
                    <%= if @payment_proof_notes && @payment_proof_notes != "" do %>
                      <div class="mt-2 text-sm text-green-700">
                        <strong>Notes:</strong> <%= @payment_proof_notes %>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <div class="space-y-3">
                <a
                  href={~p"/packages"}
                  class="inline-block bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium"
                >
                  Browse More Packages
                </a>
                <a
                  href={~p"/dashboard"}
                  class="inline-block bg-gray-300 text-gray-700 px-6 py-2 rounded-lg hover:bg-gray-400 transition-colors font-medium ml-3"
                >
                  Go to Dashboard
                </a>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </.sidebar>
    """
  end
end
