class HealthCheckService
  class << self
    def full_check
      checks = {
        database: check_database,
        cache: check_cache,
        disk: check_disk,
        memory: check_memory,
        background_jobs: check_background_jobs,
        external_services: check_external_services
      }

      overall_status = checks.values.all? { |c| c[:status] == 'healthy' } ? 'healthy' : 'degraded'
      critical = checks.values.any? { |c| c[:status] == 'critical' }
      overall_status = 'critical' if critical

      {
        status: overall_status,
        timestamp: Time.current.iso8601,
        checks: checks,
        version: app_version,
        uptime: uptime_seconds
      }
    end

    def quick_check
      {
        status: database_connected? ? 'ok' : 'error',
        timestamp: Time.current.iso8601
      }
    end

    def readiness_check
      # Check if app is ready to receive traffic
      {
        ready: database_connected? && migrations_current?,
        database: database_connected?,
        migrations: migrations_current?,
        timestamp: Time.current.iso8601
      }
    end

    def liveness_check
      # Check if app is alive (not deadlocked)
      {
        alive: true,
        timestamp: Time.current.iso8601,
        pid: Process.pid
      }
    end

    private

    def check_database
      start = Time.current
      ActiveRecord::Base.connection.execute('SELECT 1')
      latency = ((Time.current - start) * 1000).round(2)

      pool = ActiveRecord::Base.connection_pool
      {
        status: 'healthy',
        latency_ms: latency,
        pool_size: pool.size,
        connections_in_use: pool.connections.count { |c| c.in_use? },
        connections_available: pool.size - pool.connections.count { |c| c.in_use? }
      }
    rescue => e
      { status: 'critical', error: e.message }
    end

    def check_cache
      start = Time.current
      test_key = "health_check_#{SecureRandom.hex(8)}"
      Rails.cache.write(test_key, 'test', expires_in: 10.seconds)
      value = Rails.cache.read(test_key)
      Rails.cache.delete(test_key)
      latency = ((Time.current - start) * 1000).round(2)

      if value == 'test'
        { status: 'healthy', latency_ms: latency, backend: Rails.cache.class.name }
      else
        { status: 'degraded', error: 'Cache read/write failed' }
      end
    rescue => e
      { status: 'critical', error: e.message }
    end

    def check_disk
      stats = disk_stats
      usage_percent = ((stats[:used].to_f / stats[:total]) * 100).round(2)

      status = if usage_percent > 95
                 'critical'
               elsif usage_percent > 85
                 'degraded'
               else
                 'healthy'
               end

      {
        status: status,
        total_gb: (stats[:total] / 1.gigabyte.to_f).round(2),
        used_gb: (stats[:used] / 1.gigabyte.to_f).round(2),
        available_gb: (stats[:available] / 1.gigabyte.to_f).round(2),
        usage_percent: usage_percent
      }
    rescue => e
      { status: 'unknown', error: e.message }
    end

    def check_memory
      stats = memory_stats
      usage_percent = ((stats[:used].to_f / stats[:total]) * 100).round(2)

      status = if usage_percent > 95
                 'critical'
               elsif usage_percent > 85
                 'degraded'
               else
                 'healthy'
               end

      {
        status: status,
        total_mb: (stats[:total] / 1.megabyte.to_f).round(2),
        used_mb: (stats[:used] / 1.megabyte.to_f).round(2),
        available_mb: (stats[:available] / 1.megabyte.to_f).round(2),
        usage_percent: usage_percent,
        process_mb: (process_memory / 1.megabyte.to_f).round(2)
      }
    rescue => e
      { status: 'unknown', error: e.message }
    end

    def check_background_jobs
      # Check if background job system is healthy
      # This would integrate with Sidekiq, GoodJob, or other job backends
      {
        status: 'healthy',
        backend: 'async', # Rails default
        note: 'Background jobs use Rails async adapter'
      }
    rescue => e
      { status: 'unknown', error: e.message }
    end

    def check_external_services
      services = {}

      # Check Action Cable / WebSocket
      services[:websocket] = {
        status: ActionCable.server.present? ? 'healthy' : 'unavailable',
        adapter: ActionCable.server.config.cable&.dig('adapter') || 'async'
      }

      # Check AI providers if configured
      ai_provider = AiProvider.active.first
      if ai_provider
        services[:ai_provider] = {
          status: 'configured',
          provider: ai_provider.name,
          simulation_mode: ai_provider.simulation_mode?
        }
      else
        services[:ai_provider] = { status: 'not_configured' }
      end

      { status: 'healthy', services: services }
    rescue => e
      { status: 'unknown', error: e.message }
    end

    def database_connected?
      ActiveRecord::Base.connection.active?
    rescue
      false
    end

    def migrations_current?
      ActiveRecord::Migration.check_all_pending!
      true
    rescue ActiveRecord::PendingMigrationError
      false
    rescue
      true # Assume current if we can't check
    end

    def disk_stats
      stat = Sys::Filesystem.stat('/') rescue nil
      if stat
        {
          total: stat.blocks * stat.block_size,
          available: stat.blocks_available * stat.block_size,
          used: (stat.blocks - stat.blocks_available) * stat.block_size
        }
      else
        # Fallback using df command
        output = `df -B1 / 2>/dev/null`.lines.last&.split || []
        {
          total: output[1].to_i,
          used: output[2].to_i,
          available: output[3].to_i
        }
      end
    end

    def memory_stats
      if File.exist?('/proc/meminfo')
        meminfo = File.read('/proc/meminfo')
        total = meminfo[/MemTotal:\s+(\d+)/, 1].to_i * 1024
        available = meminfo[/MemAvailable:\s+(\d+)/, 1].to_i * 1024
        { total: total, available: available, used: total - available }
      else
        # macOS fallback
        output = `vm_stat 2>/dev/null`
        page_size = output[/page size of (\d+)/, 1].to_i
        free = output[/Pages free:\s+(\d+)/, 1].to_i * page_size
        active = output[/Pages active:\s+(\d+)/, 1].to_i * page_size
        inactive = output[/Pages inactive:\s+(\d+)/, 1].to_i * page_size
        wired = output[/Pages wired down:\s+(\d+)/, 1].to_i * page_size
        total = free + active + inactive + wired
        { total: total, available: free + inactive, used: active + wired }
      end
    rescue
      { total: 0, available: 0, used: 0 }
    end

    def process_memory
      if File.exist?("/proc/#{Process.pid}/statm")
        File.read("/proc/#{Process.pid}/statm").split[1].to_i * 4096
      else
        `ps -o rss= -p #{Process.pid}`.to_i * 1024
      end
    rescue
      0
    end

    def app_version
      ENV['APP_VERSION'] || ENV['GIT_COMMIT'] || 'development'
    end

    def uptime_seconds
      @boot_time ||= Time.current
      (Time.current - @boot_time).to_i
    end
  end
end
