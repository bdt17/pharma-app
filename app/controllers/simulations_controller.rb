class SimulationsController < ApplicationController
  def index
    @simulations = Simulation.order(created_at: :desc).limit(50)
    @scenarios = Simulation::SCENARIO_TYPES
  end

  def show
    @simulation = Simulation.find(params[:id])
    @events = @simulation.simulation_events.chronological.limit(200)
  end
end
