class DigitalTwinSimulator
  TICK_INTERVAL_SECONDS = 60 # Simulated time between ticks

  class << self
    def create_scenario(scenario_type, params = {})
      new.create_scenario(scenario_type, params)
    end

    def run(simulation_id, options = {})
      new.run(Simulation.find(simulation_id), options)
    end

    def replay(simulation_id)
      new.replay(Simulation.find(simulation_id))
    end
  end

  def create_scenario(scenario_type, params = {})
    config = build_configuration(scenario_type, params)

    Simulation.create!(
      scenario_name: params[:name] || "#{scenario_type.to_s.titleize} Scenario",
      description: params[:description] || default_description(scenario_type),
      status: 'draft',
      configuration: config,
      created_by: params[:created_by] || 'system'
    )
  end

  def run(simulation, options = {})
    return { error: "Simulation cannot be started" } unless simulation.can_start?

    simulation.update!(status: 'running', started_at: Time.current)

    begin
      config = simulation.configuration_hash.with_indifferent_access
      duration_minutes = config[:duration_minutes] || 60
      speed_multiplier = options[:speed_multiplier] || config[:speed_multiplier] || 1

      results = execute_simulation(simulation, config, duration_minutes, speed_multiplier)

      simulation.update!(
        status: 'completed',
        completed_at: Time.current,
        results: results
      )

      { success: true, simulation: simulation, results: results }
    rescue => e
      simulation.update!(status: 'failed', results: { error: e.message })
      { success: false, error: e.message }
    end
  end

  def replay(simulation)
    events = simulation.simulation_events.chronological

    {
      simulation_id: simulation.id,
      scenario_name: simulation.scenario_name,
      event_count: events.count,
      timeline: events.map do |event|
        {
          timestamp: event.timestamp,
          event_type: event.event_type,
          truck_id: event.truck_id,
          route_id: event.route_id,
          data: event.data_hash
        }
      end,
      results: simulation.results_hash
    }
  end

  private

  def build_configuration(scenario_type, params)
    base_config = {
      scenario_type: scenario_type,
      duration_minutes: params[:duration_minutes] || 60,
      speed_multiplier: params[:speed_multiplier] || 10,
      truck_ids: params[:truck_ids] || [],
      route_ids: params[:route_ids] || []
    }

    case scenario_type.to_s
    when 'temperature_excursion'
      base_config.merge(
        excursion_start_minute: params[:excursion_start_minute] || 15,
        excursion_severity: params[:excursion_severity] || 'moderate',
        recovery_enabled: params[:recovery_enabled] != false
      )
    when 'power_failure'
      base_config.merge(
        failure_start_minute: params[:failure_start_minute] || 10,
        failure_duration_minutes: params[:failure_duration_minutes] || 20,
        temperature_rise_rate: params[:temperature_rise_rate] || 0.5
      )
    when 'route_delay'
      base_config.merge(
        delay_start_minute: params[:delay_start_minute] || 20,
        delay_duration_minutes: params[:delay_duration_minutes] || 30,
        delay_cause: params[:delay_cause] || 'traffic'
      )
    when 'multi_truck_stress'
      base_config.merge(
        affected_percentage: params[:affected_percentage] || 30,
        stress_type: params[:stress_type] || 'mixed'
      )
    when 'weather_event'
      base_config.merge(
        weather_type: params[:weather_type] || 'heat_wave',
        ambient_temp_change: params[:ambient_temp_change] || 15,
        event_start_minute: params[:event_start_minute] || 5
      )
    when 'equipment_degradation'
      base_config.merge(
        degradation_rate: params[:degradation_rate] || 0.1,
        initial_efficiency: params[:initial_efficiency] || 100
      )
    else
      base_config.merge(params.except(:name, :description, :created_by))
    end
  end

  def default_description(scenario_type)
    descriptions = {
      'temperature_excursion' => 'Simulates temperature going out of acceptable range',
      'power_failure' => 'Simulates refrigeration unit power loss and temperature rise',
      'route_delay' => 'Simulates delays affecting delivery schedule',
      'multi_truck_stress' => 'Simulates multiple trucks experiencing issues simultaneously',
      'weather_event' => 'Simulates external weather affecting cold chain',
      'equipment_degradation' => 'Simulates gradual equipment efficiency loss',
      'custom' => 'Custom simulation scenario'
    }
    descriptions[scenario_type.to_s] || descriptions['custom']
  end

  def execute_simulation(simulation, config, duration_minutes, speed_multiplier)
    scenario_type = config[:scenario_type]
    truck_ids = resolve_truck_ids(config)
    route_ids = resolve_route_ids(config)

    stats = {
      ticks_processed: 0,
      events_generated: 0,
      excursions_detected: 0,
      alerts_triggered: 0,
      trucks_affected: [],
      routes_affected: []
    }

    sim_time = simulation.started_at

    (0..duration_minutes).each do |minute|
      sim_time = simulation.started_at + minute.minutes

      # Record simulation tick
      record_event(simulation, 'simulation_tick', sim_time, {
        minute: minute,
        simulated_time: sim_time
      })
      stats[:ticks_processed] += 1

      # Generate scenario-specific events
      case scenario_type.to_s
      when 'temperature_excursion'
        events = simulate_temperature_excursion(simulation, config, truck_ids, minute, sim_time)
      when 'power_failure'
        events = simulate_power_failure(simulation, config, truck_ids, minute, sim_time)
      when 'route_delay'
        events = simulate_route_delay(simulation, config, route_ids, minute, sim_time)
      when 'multi_truck_stress'
        events = simulate_multi_truck_stress(simulation, config, truck_ids, minute, sim_time)
      when 'weather_event'
        events = simulate_weather_event(simulation, config, truck_ids, minute, sim_time)
      when 'equipment_degradation'
        events = simulate_equipment_degradation(simulation, config, truck_ids, minute, sim_time)
      else
        events = { events: 0 }
      end

      stats[:events_generated] += events[:events] || 0
      stats[:excursions_detected] += events[:excursions] || 0
      stats[:alerts_triggered] += events[:alerts] || 0
      stats[:trucks_affected] |= events[:trucks] || []
      stats[:routes_affected] |= events[:routes] || []

      # Real-time delay for visualization (if not running in fast mode)
      sleep(TICK_INTERVAL_SECONDS.to_f / speed_multiplier / 60) if speed_multiplier < 1000
    end

    stats[:trucks_affected] = stats[:trucks_affected].uniq
    stats[:routes_affected] = stats[:routes_affected].uniq
    stats[:duration_simulated_minutes] = duration_minutes
    stats[:simulation_ended_at] = Time.current

    stats
  end

  def simulate_temperature_excursion(simulation, config, truck_ids, minute, sim_time)
    excursion_start = config[:excursion_start_minute] || 15
    severity = config[:excursion_severity] || 'moderate'
    recovery = config[:recovery_enabled] != false

    severity_offsets = { 'mild' => 2, 'moderate' => 5, 'severe' => 10 }
    offset = severity_offsets[severity.to_s] || 5

    stats = { events: 0, excursions: 0, alerts: 0, trucks: [] }

    truck_ids.each do |truck_id|
      truck = Truck.find_by(id: truck_id)
      next unless truck

      base_temp = (truck.min_temp.to_f + truck.max_temp.to_f) / 2
      max_temp = truck.max_temp || 8

      if minute < excursion_start
        temp = base_temp + rand(-0.5..0.5)
      elsif minute < excursion_start + 20
        progress = (minute - excursion_start) / 20.0
        temp = base_temp + (offset * progress) + rand(-0.3..0.3)
      elsif recovery && minute < excursion_start + 40
        recovery_progress = (minute - excursion_start - 20) / 20.0
        temp = (base_temp + offset) - (offset * recovery_progress) + rand(-0.3..0.3)
      else
        temp = recovery ? base_temp + rand(-0.5..0.5) : base_temp + offset + rand(-0.3..0.3)
      end

      record_event(simulation, 'temperature_reading', sim_time, {
        truck_id: truck_id,
        temperature: temp.round(1),
        min_temp: truck.min_temp,
        max_temp: truck.max_temp
      }, truck_id: truck_id)
      stats[:events] += 1
      stats[:trucks] << truck_id

      if temp > max_temp
        unless @excursion_active&.dig(truck_id)
          record_event(simulation, 'excursion_start', sim_time, {
            truck_id: truck_id,
            temperature: temp.round(1),
            threshold: max_temp
          }, truck_id: truck_id)
          stats[:excursions] += 1
          @excursion_active ||= {}
          @excursion_active[truck_id] = true
        end

        record_event(simulation, 'alert_triggered', sim_time, {
          truck_id: truck_id,
          alert_type: 'temperature_excursion',
          temperature: temp.round(1)
        }, truck_id: truck_id)
        stats[:alerts] += 1
      elsif @excursion_active&.dig(truck_id) && temp <= max_temp
        record_event(simulation, 'excursion_end', sim_time, {
          truck_id: truck_id,
          temperature: temp.round(1),
          recovery_time_minutes: minute - excursion_start
        }, truck_id: truck_id)
        @excursion_active[truck_id] = false
      end
    end

    stats
  end

  def simulate_power_failure(simulation, config, truck_ids, minute, sim_time)
    failure_start = config[:failure_start_minute] || 10
    failure_duration = config[:failure_duration_minutes] || 20
    rise_rate = config[:temperature_rise_rate] || 0.5

    stats = { events: 0, excursions: 0, alerts: 0, trucks: [] }

    truck_ids.each do |truck_id|
      truck = Truck.find_by(id: truck_id)
      next unless truck

      base_temp = (truck.min_temp.to_f + truck.max_temp.to_f) / 2
      max_temp = truck.max_temp || 8

      in_failure = minute >= failure_start && minute < failure_start + failure_duration
      power_status = in_failure ? 'off' : 'on'

      if in_failure
        minutes_into_failure = minute - failure_start
        temp = base_temp + (minutes_into_failure * rise_rate) + rand(-0.2..0.2)
      elsif minute >= failure_start + failure_duration
        minutes_after = minute - failure_start - failure_duration
        peak_temp = base_temp + (failure_duration * rise_rate)
        temp = [peak_temp - (minutes_after * rise_rate * 1.5), base_temp].max + rand(-0.2..0.2)
      else
        temp = base_temp + rand(-0.3..0.3)
      end

      record_event(simulation, 'temperature_reading', sim_time, {
        truck_id: truck_id,
        temperature: temp.round(1),
        power_status: power_status
      }, truck_id: truck_id)
      stats[:events] += 1
      stats[:trucks] << truck_id

      if minute == failure_start
        record_event(simulation, 'power_change', sim_time, {
          truck_id: truck_id,
          power_status: 'off',
          event: 'power_failure'
        }, truck_id: truck_id)
        stats[:alerts] += 1
      elsif minute == failure_start + failure_duration
        record_event(simulation, 'power_change', sim_time, {
          truck_id: truck_id,
          power_status: 'on',
          event: 'power_restored'
        }, truck_id: truck_id)
      end

      if temp > max_temp
        stats[:excursions] += 1
      end
    end

    stats
  end

  def simulate_route_delay(simulation, config, route_ids, minute, sim_time)
    delay_start = config[:delay_start_minute] || 20
    delay_duration = config[:delay_duration_minutes] || 30
    delay_cause = config[:delay_cause] || 'traffic'

    stats = { events: 0, routes: [] }

    route_ids.each do |route_id|
      route = Route.find_by(id: route_id)
      next unless route

      in_delay = minute >= delay_start && minute < delay_start + delay_duration

      expected_progress = (minute.to_f / 60 * 100).clamp(0, 100)
      if in_delay
        delay_factor = 0.3
        actual_progress = (expected_progress * delay_factor).round(1)
      else
        actual_progress = expected_progress.round(1)
      end

      record_event(simulation, 'route_progress', sim_time, {
        route_id: route_id,
        expected_progress: expected_progress.round(1),
        actual_progress: actual_progress,
        delayed: in_delay,
        delay_cause: in_delay ? delay_cause : nil
      }, route_id: route_id)
      stats[:events] += 1
      stats[:routes] << route_id
    end

    stats
  end

  def simulate_multi_truck_stress(simulation, config, truck_ids, minute, sim_time)
    affected_pct = config[:affected_percentage] || 30
    stress_type = config[:stress_type] || 'mixed'

    affected_count = (truck_ids.size * affected_pct / 100.0).ceil
    affected_trucks = truck_ids.first(affected_count)

    stats = { events: 0, excursions: 0, alerts: 0, trucks: [] }

    truck_ids.each do |truck_id|
      truck = Truck.find_by(id: truck_id)
      next unless truck

      is_affected = affected_trucks.include?(truck_id)
      base_temp = (truck.min_temp.to_f + truck.max_temp.to_f) / 2
      max_temp = truck.max_temp || 8

      if is_affected
        case stress_type.to_s
        when 'temperature'
          temp = base_temp + rand(3..7)
        when 'power'
          temp = base_temp + (minute > 10 ? rand(2..5) : rand(-0.5..0.5))
        else
          temp = base_temp + rand(2..6)
        end
      else
        temp = base_temp + rand(-0.5..0.5)
      end

      record_event(simulation, 'temperature_reading', sim_time, {
        truck_id: truck_id,
        temperature: temp.round(1),
        stressed: is_affected
      }, truck_id: truck_id)
      stats[:events] += 1
      stats[:trucks] << truck_id

      if temp > max_temp
        stats[:excursions] += 1
        stats[:alerts] += 1
      end
    end

    stats
  end

  def simulate_weather_event(simulation, config, truck_ids, minute, sim_time)
    weather_type = config[:weather_type] || 'heat_wave'
    ambient_change = config[:ambient_temp_change] || 15
    event_start = config[:event_start_minute] || 5

    stats = { events: 0, excursions: 0, alerts: 0, trucks: [] }

    weather_active = minute >= event_start

    truck_ids.each do |truck_id|
      truck = Truck.find_by(id: truck_id)
      next unless truck

      base_temp = (truck.min_temp.to_f + truck.max_temp.to_f) / 2
      max_temp = truck.max_temp || 8

      if weather_active
        # External temperature affects refrigeration efficiency
        efficiency_loss = ambient_change * 0.1
        temp = base_temp + efficiency_loss + rand(-0.5..1.0)
      else
        temp = base_temp + rand(-0.3..0.3)
      end

      record_event(simulation, 'temperature_reading', sim_time, {
        truck_id: truck_id,
        temperature: temp.round(1),
        weather_event: weather_active ? weather_type : nil,
        ambient_temp_effect: weather_active ? ambient_change : 0
      }, truck_id: truck_id)
      stats[:events] += 1
      stats[:trucks] << truck_id

      if temp > max_temp
        stats[:excursions] += 1
        stats[:alerts] += 1
      end
    end

    stats
  end

  def simulate_equipment_degradation(simulation, config, truck_ids, minute, sim_time)
    degradation_rate = config[:degradation_rate] || 0.1
    initial_efficiency = config[:initial_efficiency] || 100

    stats = { events: 0, excursions: 0, alerts: 0, trucks: [] }

    truck_ids.each do |truck_id|
      truck = Truck.find_by(id: truck_id)
      next unless truck

      base_temp = (truck.min_temp.to_f + truck.max_temp.to_f) / 2
      max_temp = truck.max_temp || 8

      efficiency = [initial_efficiency - (minute * degradation_rate), 50].max
      efficiency_impact = (100 - efficiency) / 100.0 * 5

      temp = base_temp + efficiency_impact + rand(-0.3..0.3)

      record_event(simulation, 'temperature_reading', sim_time, {
        truck_id: truck_id,
        temperature: temp.round(1),
        equipment_efficiency: efficiency.round(1)
      }, truck_id: truck_id)
      stats[:events] += 1
      stats[:trucks] << truck_id

      if temp > max_temp
        stats[:excursions] += 1
        stats[:alerts] += 1
      end
    end

    stats
  end

  def resolve_truck_ids(config)
    truck_ids = config[:truck_ids] || []
    return Truck.limit(5).pluck(:id) if truck_ids.empty?
    truck_ids
  end

  def resolve_route_ids(config)
    route_ids = config[:route_ids] || []
    return Route.where(status: 'in_progress').limit(3).pluck(:id) if route_ids.empty?
    route_ids
  end

  def record_event(simulation, event_type, timestamp, data, extra = {})
    simulation.simulation_events.create!(
      event_type: event_type,
      timestamp: timestamp,
      data: data,
      truck_id: extra[:truck_id],
      route_id: extra[:route_id]
    )
  end
end
