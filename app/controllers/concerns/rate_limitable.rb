module RateLimitable
  extend ActiveSupport::Concern

  included do
    before_action :check_rate_limit
  end

  class_methods do
    def rate_limit(requests_per_minute: 60, key_proc: nil)
      @rate_limit_config = {
        requests_per_minute: requests_per_minute,
        key_proc: key_proc
      }
    end

    def rate_limit_config
      @rate_limit_config || { requests_per_minute: 60, key_proc: nil }
    end
  end

  private

  def check_rate_limit
    return unless Rails.cache.respond_to?(:increment)

    config = self.class.rate_limit_config
    key = rate_limit_key(config[:key_proc])
    limit = config[:requests_per_minute]

    count = Rails.cache.increment(key, 1, expires_in: 1.minute, initial: 1)

    if count > limit
      render json: {
        error: "Rate limit exceeded",
        retry_after: 60
      }, status: :too_many_requests
    end
  end

  def rate_limit_key(key_proc)
    base_key = if key_proc
                 instance_exec(&key_proc)
               else
                 request.remote_ip
               end

    "rate_limit:#{controller_name}:#{base_key}"
  end
end
