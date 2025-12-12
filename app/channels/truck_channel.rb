class TruckChannel < ApplicationCable::Channel
  def subscribed
    stream_from "truck_#{params[:truck_id]}"
  end

  def unsubscribed
  end
end
