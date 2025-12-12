Rails.application.configure do
  # Force all access to the app over SSL
  config.force_ssl = true

  # Typical production defaults (you can adjust as needed)
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  config.log_level = :info

  # Add any other existing production settings you had before,
  # but keep them inside this configure block.
end

  config.force_ssl = true
  config.cache_classes = true
  config.eager_load = true
  config.assets.compile = false
