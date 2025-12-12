class Api::V1::SimulationsController < Api::BaseController
  def index
    simulations = Simulation.order(created_at: :desc).limit(params[:limit] || 20)
    render json: simulations.map { |s| serialize_simulation(s) }
  end

  def show
    simulation = Simulation.find(params[:id])
    render json: serialize_simulation(simulation, include_events: params[:include_events] == 'true')
  end

  def create
    scenario_type = params[:scenario_type] || 'custom'
    simulation = DigitalTwinSimulator.create_scenario(scenario_type, simulation_params)

    render json: serialize_simulation(simulation), status: :created
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def start
    simulation = Simulation.find(params[:id])

    unless simulation.can_start?
      return render json: { error: "Simulation cannot be started from #{simulation.status} status" }, status: :unprocessable_entity
    end

    # Run in background for long simulations
    if params[:async] == 'true'
      SimulationJob.perform_later(simulation.id, speed_multiplier: params[:speed_multiplier]&.to_i || 100)
      render json: { message: "Simulation started asynchronously", simulation: serialize_simulation(simulation.reload) }
    else
      result = DigitalTwinSimulator.run(simulation.id, speed_multiplier: params[:speed_multiplier]&.to_i || 1000)

      if result[:success]
        render json: { message: "Simulation completed", simulation: serialize_simulation(result[:simulation]), results: result[:results] }
      else
        render json: { error: result[:error] }, status: :unprocessable_entity
      end
    end
  end

  def pause
    simulation = Simulation.find(params[:id])

    unless simulation.can_pause?
      return render json: { error: "Simulation cannot be paused" }, status: :unprocessable_entity
    end

    simulation.update!(status: 'paused')
    render json: { message: "Simulation paused", simulation: serialize_simulation(simulation) }
  end

  def replay
    simulation = Simulation.find(params[:id])

    unless simulation.status == 'completed'
      return render json: { error: "Only completed simulations can be replayed" }, status: :unprocessable_entity
    end

    replay_data = DigitalTwinSimulator.replay(simulation)
    render json: replay_data
  end

  def events
    simulation = Simulation.find(params[:id])
    events = simulation.simulation_events.chronological

    events = events.by_type(params[:event_type]) if params[:event_type].present?
    events = events.for_truck(params[:truck_id]) if params[:truck_id].present?
    events = events.for_route(params[:route_id]) if params[:route_id].present?
    events = events.limit(params[:limit] || 100)
    events = events.offset(params[:offset]) if params[:offset].present?

    render json: {
      simulation_id: simulation.id,
      total_events: simulation.simulation_events.count,
      events: events.map { |e| serialize_event(e) }
    }
  end

  def scenarios
    render json: {
      available_scenarios: Simulation::SCENARIO_TYPES.map do |type|
        {
          type: type,
          description: scenario_description(type),
          default_params: default_scenario_params(type)
        }
      end
    }
  end

  private

  def simulation_params
    params.permit(
      :name, :description, :created_by, :duration_minutes, :speed_multiplier,
      :excursion_start_minute, :excursion_severity, :recovery_enabled,
      :failure_start_minute, :failure_duration_minutes, :temperature_rise_rate,
      :delay_start_minute, :delay_duration_minutes, :delay_cause,
      :affected_percentage, :stress_type,
      :weather_type, :ambient_temp_change, :event_start_minute,
      :degradation_rate, :initial_efficiency,
      truck_ids: [], route_ids: []
    ).to_h.symbolize_keys
  end

  def serialize_simulation(simulation, include_events: false)
    data = {
      id: simulation.id,
      scenario_name: simulation.scenario_name,
      description: simulation.description,
      status: simulation.status,
      created_by: simulation.created_by,
      started_at: simulation.started_at,
      completed_at: simulation.completed_at,
      duration_seconds: simulation.duration_seconds,
      event_count: simulation.event_count,
      configuration: simulation.configuration_hash,
      results: simulation.results_hash,
      created_at: simulation.created_at,
      updated_at: simulation.updated_at
    }

    if include_events
      data[:events] = simulation.simulation_events.chronological.limit(500).map { |e| serialize_event(e) }
    end

    data
  end

  def serialize_event(event)
    {
      id: event.id,
      event_type: event.event_type,
      timestamp: event.timestamp,
      truck_id: event.truck_id,
      route_id: event.route_id,
      data: event.data_hash
    }
  end

  def scenario_description(type)
    {
      'temperature_excursion' => 'Simulates temperature going out of acceptable range and optional recovery',
      'power_failure' => 'Simulates refrigeration unit power loss and gradual temperature rise',
      'route_delay' => 'Simulates delays affecting delivery schedule and progress',
      'multi_truck_stress' => 'Simulates multiple trucks experiencing issues simultaneously',
      'weather_event' => 'Simulates external weather (heat wave, cold snap) affecting cold chain',
      'equipment_degradation' => 'Simulates gradual equipment efficiency loss over time',
      'custom' => 'Custom simulation with user-defined parameters'
    }[type] || 'Custom scenario'
  end

  def default_scenario_params(type)
    case type
    when 'temperature_excursion'
      { duration_minutes: 60, excursion_start_minute: 15, excursion_severity: 'moderate', recovery_enabled: true }
    when 'power_failure'
      { duration_minutes: 60, failure_start_minute: 10, failure_duration_minutes: 20, temperature_rise_rate: 0.5 }
    when 'route_delay'
      { duration_minutes: 90, delay_start_minute: 20, delay_duration_minutes: 30, delay_cause: 'traffic' }
    when 'multi_truck_stress'
      { duration_minutes: 60, affected_percentage: 30, stress_type: 'mixed' }
    when 'weather_event'
      { duration_minutes: 120, weather_type: 'heat_wave', ambient_temp_change: 15, event_start_minute: 5 }
    when 'equipment_degradation'
      { duration_minutes: 180, degradation_rate: 0.1, initial_efficiency: 100 }
    else
      { duration_minutes: 60 }
    end
  end
end
