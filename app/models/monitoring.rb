class Monitoring < ApplicationRecord
  belongs_to :truck

  after_create_commit :broadcast_update
  after_create_commit :recalculate_risk

  private

  def broadcast_update
    MonitoringBroadcaster.broadcast(self)
  end

  def recalculate_risk
    RiskScorer.for_truck(truck)
  end
end
