class ConsoleChannel < ApplicationCable::Channel
  def subscribed
    stream_from "console_updates"
  end

  def unsubscribed
  end
end
