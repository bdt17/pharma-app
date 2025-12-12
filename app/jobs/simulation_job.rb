class SimulationJob < ApplicationJob
  queue_as :simulations

  def perform(simulation_id, options = {})
    DigitalTwinSimulator.run(simulation_id, options)
  end
end
