class CacheService
  class << self
    # Cache keys prefix
    PREFIX = 'pharma'.freeze

    # Default TTLs
    TTLS = {
      dashboard: 5.minutes,
      analytics: 15.minutes,
      truck_status: 1.minute,
      route_risk: 5.minutes,
      compliance: 10.minutes,
      warehouse: 2.minutes
    }.freeze

    # Dashboard caching
    def dashboard_summary(region_id: nil, site_id: nil, &block)
      key = cache_key('dashboard', 'summary', region_id, site_id)
      fetch(key, expires_in: TTLS[:dashboard], &block)
    end

    def analytics_summary(period: '30d', &block)
      key = cache_key('analytics', 'summary', period)
      fetch(key, expires_in: TTLS[:analytics], &block)
    end

    # Truck caching
    def truck_status(truck_id, &block)
      key = cache_key('truck', truck_id, 'status')
      fetch(key, expires_in: TTLS[:truck_status], &block)
    end

    def truck_telemetry(truck_id, &block)
      key = cache_key('truck', truck_id, 'telemetry')
      fetch(key, expires_in: 30.seconds, &block)
    end

    def trucks_by_risk(&block)
      key = cache_key('trucks', 'by_risk')
      fetch(key, expires_in: TTLS[:route_risk], &block)
    end

    # Route caching
    def route_risk(route_id, &block)
      key = cache_key('route', route_id, 'risk')
      fetch(key, expires_in: TTLS[:route_risk], &block)
    end

    def route_forecast(route_id, &block)
      key = cache_key('route', route_id, 'forecast')
      fetch(key, expires_in: TTLS[:route_risk], &block)
    end

    # Compliance caching
    def compliance_status(route_id, &block)
      key = cache_key('compliance', route_id)
      fetch(key, expires_in: TTLS[:compliance], &block)
    end

    # Warehouse caching
    def warehouse_status(warehouse_id, &block)
      key = cache_key('warehouse', warehouse_id, 'status')
      fetch(key, expires_in: TTLS[:warehouse], &block)
    end

    def storage_zones(warehouse_id, &block)
      key = cache_key('warehouse', warehouse_id, 'zones')
      fetch(key, expires_in: TTLS[:warehouse], &block)
    end

    # Cache invalidation
    def invalidate_truck(truck_id)
      delete_pattern("truck:#{truck_id}:*")
      delete_pattern('trucks:*')
      delete_pattern('dashboard:*')
    end

    def invalidate_route(route_id)
      delete_pattern("route:#{route_id}:*")
      delete_pattern("compliance:#{route_id}")
      delete_pattern('dashboard:*')
    end

    def invalidate_warehouse(warehouse_id)
      delete_pattern("warehouse:#{warehouse_id}:*")
    end

    def invalidate_all
      delete_pattern('*')
    end

    # Counter for rate limiting and metrics
    def increment(key, amount: 1, expires_in: 1.hour)
      full_key = cache_key('counter', key)
      Rails.cache.increment(full_key, amount, expires_in: expires_in) || begin
        Rails.cache.write(full_key, amount, expires_in: expires_in)
        amount
      end
    end

    def get_counter(key)
      full_key = cache_key('counter', key)
      Rails.cache.read(full_key) || 0
    end

    # Generic methods
    def fetch(key, options = {}, &block)
      Rails.cache.fetch(key, options, &block)
    end

    def read(key)
      Rails.cache.read(key)
    end

    def write(key, value, options = {})
      Rails.cache.write(key, value, options)
    end

    def delete(key)
      Rails.cache.delete(key)
    end

    def exist?(key)
      Rails.cache.exist?(key)
    end

    private

    def cache_key(*parts)
      ([PREFIX] + parts.compact.map(&:to_s)).join(':')
    end

    def delete_pattern(pattern)
      full_pattern = cache_key(pattern)
      # For file/memory store, iterate keys
      # For Redis, use SCAN + DELETE
      if Rails.cache.respond_to?(:delete_matched)
        Rails.cache.delete_matched(full_pattern)
      end
    end
  end
end
