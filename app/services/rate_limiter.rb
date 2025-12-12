class RateLimiter
  class RateLimitExceeded < StandardError
    attr_reader :retry_after

    def initialize(message, retry_after: nil)
      @retry_after = retry_after
      super(message)
    end
  end

  class << self
    # Default limits per endpoint category
    LIMITS = {
      api_general: { requests: 100, period: 1.minute },
      api_telemetry: { requests: 1000, period: 1.minute },
      api_webhooks: { requests: 50, period: 1.minute },
      api_ai: { requests: 20, period: 1.minute },
      api_export: { requests: 10, period: 1.minute },
      portal_track: { requests: 60, period: 1.minute },
      websocket: { requests: 30, period: 1.second }
    }.freeze

    # Check if request is allowed
    def check!(identifier, category: :api_general)
      limit_config = LIMITS[category] || LIMITS[:api_general]
      key = rate_limit_key(identifier, category)

      current = increment_counter(key, limit_config[:period])

      if current > limit_config[:requests]
        retry_after = time_until_reset(key, limit_config[:period])
        raise RateLimitExceeded.new(
          "Rate limit exceeded for #{category}. Limit: #{limit_config[:requests]} per #{limit_config[:period].inspect}",
          retry_after: retry_after
        )
      end

      {
        allowed: true,
        remaining: limit_config[:requests] - current,
        limit: limit_config[:requests],
        reset_at: Time.current + time_until_reset(key, limit_config[:period])
      }
    end

    # Check without raising
    def allowed?(identifier, category: :api_general)
      check!(identifier, category: category)
      true
    rescue RateLimitExceeded
      false
    end

    # Get current status
    def status(identifier, category: :api_general)
      limit_config = LIMITS[category] || LIMITS[:api_general]
      key = rate_limit_key(identifier, category)
      current = get_counter(key)

      {
        current: current,
        limit: limit_config[:requests],
        remaining: [limit_config[:requests] - current, 0].max,
        exceeded: current > limit_config[:requests],
        reset_at: Time.current + time_until_reset(key, limit_config[:period])
      }
    end

    # Reset a specific identifier
    def reset!(identifier, category: :api_general)
      key = rate_limit_key(identifier, category)
      Rails.cache.delete(key)
    end

    # Sliding window rate limiter (more accurate)
    def check_sliding!(identifier, category: :api_general)
      limit_config = LIMITS[category] || LIMITS[:api_general]
      window_key = sliding_window_key(identifier, category)
      now = Time.current.to_f

      # Clean old entries and count recent requests
      window_start = now - limit_config[:period].to_f
      requests = get_sliding_window(window_key)
      requests = requests.select { |t| t > window_start }

      if requests.size >= limit_config[:requests]
        oldest = requests.min
        retry_after = (oldest + limit_config[:period].to_f - now).ceil
        raise RateLimitExceeded.new(
          "Rate limit exceeded (sliding window)",
          retry_after: retry_after
        )
      end

      # Add current request
      requests << now
      set_sliding_window(window_key, requests, limit_config[:period])

      {
        allowed: true,
        remaining: limit_config[:requests] - requests.size,
        limit: limit_config[:requests]
      }
    end

    # Token bucket algorithm for burst handling
    def check_bucket!(identifier, category: :api_general, burst_multiplier: 2)
      limit_config = LIMITS[category] || LIMITS[:api_general]
      bucket_key = bucket_key(identifier, category)

      bucket = get_bucket(bucket_key)
      now = Time.current.to_f

      # Calculate tokens to add based on time elapsed
      rate = limit_config[:requests].to_f / limit_config[:period].to_f
      max_tokens = limit_config[:requests] * burst_multiplier

      if bucket
        elapsed = now - bucket[:last_update]
        new_tokens = elapsed * rate
        bucket[:tokens] = [bucket[:tokens] + new_tokens, max_tokens].min
        bucket[:last_update] = now
      else
        bucket = { tokens: max_tokens, last_update: now }
      end

      if bucket[:tokens] < 1
        retry_after = ((1 - bucket[:tokens]) / rate).ceil
        raise RateLimitExceeded.new(
          "Rate limit exceeded (token bucket)",
          retry_after: retry_after
        )
      end

      bucket[:tokens] -= 1
      set_bucket(bucket_key, bucket)

      {
        allowed: true,
        tokens_remaining: bucket[:tokens].floor,
        max_tokens: max_tokens
      }
    end

    # IP-based rate limiting
    def check_ip!(ip_address, category: :api_general)
      identifier = "ip:#{ip_address}"
      check!(identifier, category: category)
    end

    # API key-based rate limiting
    def check_api_key!(api_key, category: :api_general)
      identifier = "key:#{Digest::SHA256.hexdigest(api_key)[0..15]}"
      check!(identifier, category: category)
    end

    # User-based rate limiting
    def check_user!(user_id, category: :api_general)
      identifier = "user:#{user_id}"
      check!(identifier, category: category)
    end

    private

    def rate_limit_key(identifier, category)
      window = (Time.current.to_i / 60) # 1-minute windows
      "rate_limit:#{category}:#{identifier}:#{window}"
    end

    def sliding_window_key(identifier, category)
      "rate_limit_sw:#{category}:#{identifier}"
    end

    def bucket_key(identifier, category)
      "rate_limit_bucket:#{category}:#{identifier}"
    end

    def increment_counter(key, period)
      Rails.cache.increment(key, 1, expires_in: period) || begin
        Rails.cache.write(key, 1, expires_in: period)
        1
      end
    end

    def get_counter(key)
      Rails.cache.read(key) || 0
    end

    def time_until_reset(key, period)
      # Approximate time until window resets
      elapsed = Time.current.to_i % period.to_i
      period.to_i - elapsed
    end

    def get_sliding_window(key)
      Rails.cache.read(key) || []
    end

    def set_sliding_window(key, requests, period)
      Rails.cache.write(key, requests, expires_in: period * 2)
    end

    def get_bucket(key)
      Rails.cache.read(key)
    end

    def set_bucket(key, bucket)
      Rails.cache.write(key, bucket, expires_in: 1.hour)
    end
  end
end
