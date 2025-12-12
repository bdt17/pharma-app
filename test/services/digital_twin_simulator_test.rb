require "test_helper"

class DigitalTwinSimulatorTest < ActiveSupport::TestCase
  setup do
    @region = Region.create!(name: "Test Region")
    @site = Site.create!(name: "Test Site", region: @region)
    @truck = Truck.create!(
      name: "Test Truck",
      site: @site,
      status: "active",
      min_temp: 2,
      max_temp: 8
    )
  end

  test "create_scenario returns a draft simulation" do
    simulation = DigitalTwinSimulator.create_scenario(:temperature_excursion, {
      name: "Test Excursion",
      duration_minutes: 30
    })

    assert simulation.persisted?
    assert_equal "draft", simulation.status
    assert_equal "Test Excursion", simulation.scenario_name
    assert_equal "temperature_excursion", simulation.configuration_hash["scenario_type"]
    assert_equal 30, simulation.configuration_hash["duration_minutes"]
  end

  test "create_scenario with power_failure type" do
    simulation = DigitalTwinSimulator.create_scenario(:power_failure, {
      failure_start_minute: 5,
      failure_duration_minutes: 15
    })

    config = simulation.configuration_hash
    assert_equal "power_failure", config["scenario_type"]
    assert_equal 5, config["failure_start_minute"]
    assert_equal 15, config["failure_duration_minutes"]
  end

  test "create_scenario with route_delay type" do
    simulation = DigitalTwinSimulator.create_scenario(:route_delay, {
      delay_cause: "traffic"
    })

    config = simulation.configuration_hash
    assert_equal "route_delay", config["scenario_type"]
    assert_equal "traffic", config["delay_cause"]
  end

  test "run simulation generates events" do
    simulation = DigitalTwinSimulator.create_scenario(:temperature_excursion, {
      duration_minutes: 5,
      truck_ids: [@truck.id]
    })

    result = DigitalTwinSimulator.run(simulation.id, speed_multiplier: 10000)

    assert result[:success]
    assert_equal "completed", simulation.reload.status
    assert simulation.simulation_events.count > 0
    assert simulation.results_hash["ticks_processed"] > 0
  end

  test "run simulation tracks excursions" do
    simulation = DigitalTwinSimulator.create_scenario(:temperature_excursion, {
      duration_minutes: 30,
      excursion_start_minute: 5,
      excursion_severity: "severe",
      truck_ids: [@truck.id]
    })

    result = DigitalTwinSimulator.run(simulation.id, speed_multiplier: 10000)

    assert result[:success]
    results = simulation.reload.results_hash
    assert results["excursions_detected"] > 0 || results["alerts_triggered"] > 0
  end

  test "cannot start completed simulation" do
    simulation = DigitalTwinSimulator.create_scenario(:temperature_excursion, {
      duration_minutes: 2,
      truck_ids: [@truck.id]
    })

    DigitalTwinSimulator.run(simulation.id, speed_multiplier: 10000)
    assert_equal "completed", simulation.reload.status

    result = DigitalTwinSimulator.run(simulation.id)
    assert result[:error].present?
  end

  test "replay returns timeline" do
    simulation = DigitalTwinSimulator.create_scenario(:temperature_excursion, {
      duration_minutes: 3,
      truck_ids: [@truck.id]
    })

    DigitalTwinSimulator.run(simulation.id, speed_multiplier: 10000)

    replay = DigitalTwinSimulator.replay(simulation.reload.id)

    assert_equal simulation.id, replay[:simulation_id]
    assert replay[:timeline].is_a?(Array)
    assert replay[:timeline].count > 0
  end

  test "simulation records different event types" do
    simulation = DigitalTwinSimulator.create_scenario(:temperature_excursion, {
      duration_minutes: 5,
      truck_ids: [@truck.id]
    })

    DigitalTwinSimulator.run(simulation.id, speed_multiplier: 10000)

    event_types = simulation.simulation_events.pluck(:event_type).uniq
    assert_includes event_types, "simulation_tick"
    assert_includes event_types, "temperature_reading"
  end

  test "power failure scenario generates power change events" do
    simulation = DigitalTwinSimulator.create_scenario(:power_failure, {
      duration_minutes: 15,
      failure_start_minute: 5,
      failure_duration_minutes: 5,
      truck_ids: [@truck.id]
    })

    DigitalTwinSimulator.run(simulation.id, speed_multiplier: 10000)

    power_events = simulation.simulation_events.where(event_type: "power_change")
    assert power_events.count >= 1
  end

  test "scenario types are valid" do
    Simulation::SCENARIO_TYPES.each do |type|
      simulation = DigitalTwinSimulator.create_scenario(type, { duration_minutes: 1 })
      assert simulation.persisted?, "Failed to create #{type} scenario"
    end
  end
end
