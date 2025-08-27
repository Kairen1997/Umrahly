defmodule UmrahlyWeb.TravelerDetailsLive do
  use UmrahlyWeb, :live_view

  import UmrahlyWeb.SidebarComponent
  alias Umrahly.Bookings
  alias Umrahly.Bookings.TravelerDetail

  on_mount {UmrahlyWeb.UserAuth, :mount_current_user}

  def mount(%{"booking_id" => booking_id}, _session, socket) do
    booking = Bookings.get_booking!(booking_id)

    # Check if user owns this booking
    if booking.user_id != socket.assigns.current_user.id do
      {:noreply,
       socket
       |> put_flash(:error, "You are not authorized to view this booking")
       |> push_navigate(to: ~p"/bookings")}
    else
      # Get existing traveler details
      existing_travelers = Bookings.list_traveler_details_by_booking(booking_id)

      # Initialize travelers data
      travelers = if Enum.empty?(existing_travelers) do
        # Create empty travelers based on booking number_of_persons
        Enum.map(1..booking.number_of_persons, fn _ ->
          %{
            full_name: "",
            identity_card_number: "",
            passport_number: "",
            passport_expiry_date: "",
            phone_number: "",
            email_address: "",
            gender: "",
            date_of_birth: "",
            nationality: "",
            emergency_contact_name: "",
            emergency_contact_phone: "",
            emergency_contact_relationship: "",
            room_preference: "",
            vaccination_record: "",
            medical_conditions: "",
            mahram_info: "",
            special_needs_requests: ""
          }
        end)
      else
        # Use existing traveler details
        Enum.map(existing_travelers, fn td ->
          %{
            id: td.id,
            full_name: td.full_name,
            identity_card_number: td.identity_card_number,
            passport_number: td.passport_number || "",
            passport_expiry_date: if(td.passport_expiry_date, do: Date.to_string(td.passport_expiry_date), else: ""),
            phone_number: td.phone_number,
            email_address: td.email_address,
            gender: td.gender,
            date_of_birth: if(td.date_of_birth, do: Date.to_string(td.date_of_birth), else: ""),
            nationality: td.nationality || "",
            emergency_contact_name: td.emergency_contact_name || "",
            emergency_contact_phone: td.emergency_contact_phone || "",
            emergency_contact_relationship: td.emergency_contact_relationship || "",
            room_preference: td.room_preference || "",
            vaccination_record: td.vaccination_record || "",
            medical_conditions: td.medical_conditions || "",
            mahram_info: td.mahram_info || "",
            special_needs_requests: td.special_needs_requests || ""
          }
        end)
      end

      socket = assign(socket, %{
        booking: booking,
        travelers: travelers,
        current_phase: 1,
        show_phase2: false,
        show_phase3: false,
        saved_travelers: existing_travelers,
        page_title: "Traveler Details"
      })

      {:ok, socket}
    end
  end

  def handle_event("save_travelers", _params, socket) do
    case save_travelers(socket.assigns.booking.id, socket.assigns.current_user.id, socket.assigns.travelers) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Traveler details saved successfully!")
         |> assign(saved_travelers: Bookings.list_traveler_details_by_booking(socket.assigns.booking.id))}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to save traveler details. Please check the form and try again.")}
    end
  end

  def handle_event("update_traveler", %{"index" => index, "field" => field, "value" => value}, socket) do
    travelers = socket.assigns.travelers
    updated_travelers = List.update_at(travelers, String.to_integer(index), fn traveler ->
      Map.put(traveler, String.to_atom(field), value)
    end)

    {:noreply, assign(socket, travelers: updated_travelers)}
  end

  def handle_event("toggle_phase2", _params, socket) do
    {:noreply, assign(socket, show_phase2: !socket.assigns.show_phase2)}
  end

  def handle_event("toggle_phase3", _params, socket) do
    {:noreply, assign(socket, show_phase3: !socket.assigns.show_phase3)}
  end

  def handle_event("update_phase2", %{"index" => index} = params, socket) do
    travelers = socket.assigns.travelers
    traveler_index = String.to_integer(index)

    updated_travelers = List.update_at(travelers, traveler_index, fn traveler ->
      traveler
      |> Map.put(:nationality, params["nationality"] || "")
      |> Map.put(:emergency_contact_name, params["emergency_contact_name"] || "")
      |> Map.put(:emergency_contact_phone, params["emergency_contact_phone"] || "")
      |> Map.put(:emergency_contact_relationship, params["emergency_contact_relationship"] || "")
      |> Map.put(:room_preference, params["room_preference"] || "")
      |> Map.put(:vaccination_record, params["vaccination_record"] || "")
      |> Map.put(:medical_conditions, params["medical_conditions"] || "")
    end)

    {:noreply, assign(socket, travelers: updated_travelers)}
  end

  def handle_event("update_phase3", %{"index" => index} = params, socket) do
    travelers = socket.assigns.travelers
    traveler_index = String.to_integer(index)

    updated_travelers = List.update_at(travelers, traveler_index, fn traveler ->
      traveler
      |> Map.put(:mahram_info, params["mahram_info"] || "")
      |> Map.put(:special_needs_requests, params["special_needs_requests"] || "")
    end)

    {:noreply, assign(socket, travelers: updated_travelers)}
  end

  defp save_travelers(booking_id, user_id, travelers) do
    # Delete existing traveler details first
    existing_travelers = Bookings.list_traveler_details_by_booking(booking_id)
    Enum.each(existing_travelers, &Bookings.delete_traveler_detail/1)

    # Create new traveler details
    Enum.reduce_while(travelers, {:ok, []}, fn traveler, {:ok, acc} ->
      case create_traveler_detail(traveler, booking_id, user_id) do
        {:ok, traveler_detail} -> {:cont, {:ok, [traveler_detail | acc]}}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
  end

  defp create_traveler_detail(traveler, booking_id, user_id) do
    attrs = %{
      "full_name" => traveler.full_name,
      "identity_card_number" => traveler.identity_card_number,
      "passport_number" => traveler.passport_number,
      "passport_expiry_date" => parse_date(traveler.passport_expiry_date),
      "phone_number" => traveler.phone_number,
      "email_address" => traveler.email_address,
      "gender" => traveler.gender,
      "date_of_birth" => parse_date(traveler.date_of_birth),
      "nationality" => traveler.nationality,
      "emergency_contact_name" => traveler.emergency_contact_name,
      "emergency_contact_phone" => traveler.emergency_contact_phone,
      "emergency_contact_relationship" => traveler.emergency_contact_relationship,
      "room_preference" => traveler.room_preference,
      "vaccination_record" => traveler.vaccination_record,
      "medical_conditions" => traveler.medical_conditions,
      "mahram_info" => traveler.mahram_info,
      "special_needs_requests" => traveler.special_needs_requests,
      "booking_id" => booking_id,
      "user_id" => user_id
    }

    Bookings.create_traveler_detail(attrs)
  end

  defp parse_date(date_string) when is_binary(date_string) and date_string != "" do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_date(_), do: nil

  defp has_required_fields?(traveler) do
    traveler.full_name != "" and
    traveler.identity_card_number != "" and
    traveler.phone_number != "" and
    traveler.email_address != "" and
    traveler.gender != "" and
    traveler.date_of_birth != ""
  end

  defp all_travelers_complete?(travelers) do
    Enum.all?(travelers, &has_required_fields?/1)
  end

    defp all_travelers_phase1_complete?(travelers) do
    Enum.all?(travelers, fn t ->
      t.full_name != "" and
      t.identity_card_number != "" and
      t.phone_number != "" and
      t.email_address != "" and
      t.gender != "" and
      t.date_of_birth != ""
    end)
  end

  defp any_travelers_phase2_complete?(travelers) do
    Enum.any?(travelers, fn t -> t.nationality != "" end)
  end

  defp any_travelers_phase3_complete?(travelers) do
    Enum.any?(travelers, fn t -> t.mahram_info != "" or t.special_needs_requests != "" end)
  end
end
