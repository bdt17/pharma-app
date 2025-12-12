class Api::V1::ShipmentEventsController < Api::BaseController
  def index
    truck = Truck.find(params[:truck_id])
    events = truck.shipment_events.recent.limit(params[:limit] || 100)

    render json: events.map { |e| serialize_event(e) }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Truck not found" }, status: :not_found
  end

  def create
    truck = Truck.find(params[:truck_id])
    event = truck.shipment_events.new(event_params)
    event.recorded_at ||= Time.current

    if event.save
      render json: serialize_event(event), status: :created
    else
      render json: { errors: event.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Truck not found" }, status: :not_found
  end

  def chain_of_custody
    truck = Truck.find(params[:truck_id])
    route_id = params[:route_id]

    events = ShipmentEvent.chain_of_custody(truck.id, route_id)

    render json: {
      truck_id: truck.id,
      truck_name: truck.name,
      route_id: route_id,
      events: events.map { |e| serialize_event(e) },
      chain_verified: ShipmentEvent.verify_chain(truck.id)
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Truck not found" }, status: :not_found
  end

  def verify_chain
    truck = Truck.find(params[:truck_id])
    result = ShipmentEvent.verify_chain(truck.id)

    render json: {
      truck_id: truck.id,
      truck_name: truck.name,
      **result
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Truck not found" }, status: :not_found
  end

  def route_history
    route = Route.find(params[:route_id])
    events = ShipmentEvent.for_route(route.id).order(:recorded_at)

    render json: {
      route_id: route.id,
      route_name: route.name,
      status: route.status,
      events: events.map { |e| serialize_event(e) },
      summary: route_summary(route, events)
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Route not found" }, status: :not_found
  end

  private

  def event_params
    params.require(:event).permit(
      :event_type, :description, :latitude, :longitude,
      :temperature_c, :recorded_at, :recorded_by, :signature,
      :route_id, :waypoint_id
    ).tap do |p|
      if params[:event][:metadata].present?
        p[:metadata] = params[:event][:metadata].to_json
      end
    end
  end

  def serialize_event(event)
    {
      id: event.id,
      truck_id: event.truck_id,
      route_id: event.route_id,
      waypoint_id: event.waypoint_id,
      event_type: event.event_type,
      description: event.description,
      latitude: event.latitude,
      longitude: event.longitude,
      temperature_c: event.temperature_c,
      recorded_at: event.recorded_at&.iso8601,
      recorded_by: event.recorded_by,
      has_signature: event.signature.present?,
      metadata: event.parsed_metadata,
      created_at: event.created_at
    }
  end

  def route_summary(route, events)
    {
      total_events: events.count,
      excursions: events.count { |e| e.event_type == 'temperature_excursion' },
      stops_completed: events.count { |e| e.event_type == 'stop_departure' },
      deliveries_confirmed: events.count { |e| e.event_type == 'delivery_confirmed' },
      signatures_captured: events.count { |e| e.event_type == 'signature_captured' },
      started_at: route.started_at,
      completed_at: route.completed_at,
      duration_minutes: route.started_at && route.completed_at ?
        ((route.completed_at - route.started_at) / 60).round : nil
    }
  end
end
