class MasterDashboardController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @trucks = current_user.trucks
    @inventory_items = InventoryItem.where(truck: @trucks)
    @anomalies = Anomaly.where(truck: @trucks).where('created_at > ?', 1.day.ago)
    @slas = SLA.last(5)
    @rules = Rule.where(active: true)
  end
end
