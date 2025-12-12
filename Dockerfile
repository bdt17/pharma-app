FROM ruby:3.2
WORKDIR /rails

RUN apt-get update -qq && apt-get install -y nodejs postgresql-client

ENV RAILS_ENV=production BUILD_ID=debug2

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

# DEBUG: show what routes.rb looks like inside the image
RUN echo "===== /rails/config/routes.rb inside container =====" && \
    sed -n '1,40p' config/routes.rb && \
    echo "===== END routes.rb ====="

RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
