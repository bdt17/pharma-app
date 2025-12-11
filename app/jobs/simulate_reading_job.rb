class SimulateReadingJob < ApplicationJob
  queue_as :default

  def perform
    Truck.find_each do |truck|
      truck.monitorings.create!(
        temperature: rand(1.0..12.0),
        power_status: ["OK", "ON_BATTERY"].sample,
        recorded_at: Time.current
      )
    end
  end
end
