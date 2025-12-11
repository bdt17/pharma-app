class AlertMailer < ApplicationMailer
  default from: "alerts@example.com"

  def truck_out_of_range(user, truck, monitoring)
    @user = user
    @truck = truck
    @monitoring = monitoring
    mail to: @user.email, subject: "Truck #{truck.name} out of range"
  end
end
