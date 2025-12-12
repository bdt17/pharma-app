class AlertMailer < ApplicationMailer
  default from: "alerts@pharmatransport.example.com"

  def truck_out_of_range(user, truck, monitoring)
    @user = user
    @truck = truck
    @monitoring = monitoring
    mail to: @user.email, subject: "Truck #{truck.name} out of range"
  end

  def telemetry_excursion(email, truck, reading)
    @truck = truck
    @reading = reading
    @site = truck.site
    @region = truck.site&.region

    subject = "[ALERT] #{truck.name} - Temperature Excursion Detected"
    mail to: email, subject: subject
  end
end
