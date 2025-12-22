source "https://rubygems.org"

gem "rails", "~> 8.1.1"
gem "sqlite3", "~> 2.0"
gem "puma", ">= 5.0"
gem "propshaft"
gem "devise"
gem "twilio-ruby"
gem "bootsnap", require: false
gem "chartkick"
gem "groupdate"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ]
end

group :test do
  gem "capybara"
end
gem "letter_opener", group: :development
gem 'pg', group: :production
gem "redis", group: :production
gem 'stripe', '~> 18.1'
