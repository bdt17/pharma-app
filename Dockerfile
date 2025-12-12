# Use the official Ruby image as base
FROM ruby:3.2

# Install dependencies
RUN apt-get update -qq && apt-get install -y nodejs postgresql-client

# Set working directory
WORKDIR /rails

# Cache-bust layer before COPY so Render rebuilds with latest code
ENV RAILS_ENV=production BUILD_ID=a33e3a6

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy the rest of the app
COPY . .

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Start the server
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
