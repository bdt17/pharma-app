class Api::V1::TrucksController < Api::BaseController
  def index
    trucks = Truck.all.includes(:monitorings)
    render json: trucks.map { |t| serialize_truck(t) }
  end

  def show
    truck = Truck.includes(:monitorings).find(params[:id])
    render json: serialize_truck(truck)
  end

  def by_risk
    trucks = Truck.where.not(risk_score: nil)
                  .order(risk_score: :desc)
                  .includes(:monitorings)
    render json: trucks.map { |t| serialize_truck_with_risk(t) }
  end

  private

  def serialize_truck(truck)
    last = truck.monitorings.order(recorded_at: :desc).first
    {
      id: truck.id,
      name: truck.name,
      status: truck.status,
      last_temperature: last&.temperature,
      last_power_status: last&.power_status,
      last_recorded_at: last&.recorded_at
    }
  end

  def serialize_truck_with_risk(truck)
    serialize_truck(truck).merge(
      risk_score: truck.risk_score,
      risk_level: truck.risk_level,
      min_temp: truck.min_temp,
      max_temp: truck.max_temp
    )
  end
end
