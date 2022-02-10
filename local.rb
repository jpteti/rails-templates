def install_letter_opener
  development_config_file = "config/environments/development.rb"

  second_line = "config.action_mailer.delivery_method = :letter_opener"

  gsub_file(development_config_file, "# Don't care if the mailer can't send.", "# Use LetterOpener")
  gsub_file(development_config_file, "config.action_mailer.raise_delivery_errors = false", second_line)
  inject_into_file(development_config_file, after: "#{second_line}\n") do
    <<~RUBY
      config.action_mailer.perform_deliveries = true
    RUBY
  end
end

def fix_standard_complaints_that_it_doesnt_fix
  gsub_file("config/environments/production.rb", "logger           = ActiveSupport::Logger.new(STDOUT)", "logger           = ActiveSupport::Logger.new($stdout)")
  gsub_file("config/puma.rb", 'max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }', 'max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)')
  gsub_file("config/puma.rb", 'port ENV.fetch("PORT") { 3000 }', 'port ENV.fetch("PORT", 3000)')
end

gem "active_link_to", github: "jpteti/active_link_to", branch: "add-config"
gem "audited"
gem "discard"
gem "dotenv-rails"
gem "email_validator"
gem "flutie"
gem "interactor", "~> 3.0"
# gem "kredis"
gem "logstop"
gem "lograge"
gem "pundit"
gem "rotp"
gem "safely_block"
gem "strong_migrations"
gem "view_component"

gem_group :development, :test do
  gem "standard"
  gem "factory_bot_rails"
  gem "rspec-rails", "~> 5.0.0"
end

gem_group :development do
  gem "letter_opener"
end

gem_group :test do
  gem "shoulda-matchers", "~> 5.0"
end

initializer "active_link_to.rb", <<~RUBY
  ActiveLinkTo.configure do |config|
    config.class_active = "is-active"
  end
RUBY

initializer "logstop.rb", <<~RUBY
  Logstop.guard(Rails.logger)
RUBY

gsub_file "Gemfile", '# gem "kredis"', 'gem "kredis"'
# gsub_file "config/environments/development.rb", ''

environment nil, env: "production" do
  <<~RUBY
    # TODO: Enable these and set correctly
    config.action_controller.default_url_options = {host: "www.Change.Me"}
    config.action_controller.asset_host = "www.Change.Me"

    config.force_ssl = true

    # Submit your domain to the HSTS preload list: https://hstspreload.org/
    config.ssl_options = {hsts: {subdomains: true, preload: true, expires: 1.year}}

    # Use Lograge, but add some info to it
    config.lograge.enabled = true
    config.lograge.custom_options = lambda do |event|
      options = event.payload.slice(:request_id, :user_id)
      options[:params] = event.payload[:params].except("controller", "action")
      options
    end
  RUBY
end

inject_into_file "app/controllers/application_controller.rb", after: "class ApplicationController < ActionController::Base\n" do
  <<~CODE
    def append_info_to_payload(payload)
      super
      payload[:request_id] = request.uuid
      payload[:user_id] = current_user.id if current_user
    end
  CODE
end

append_file ".gitignore" do
  <<~'GIT'
    .env
  GIT
end

install_letter_opener
fix_standard_complaints_that_it_doesnt_fix

create_file ".env"
create_file ".env.sample"

after_bundle do
  generate("rspec:install")
  generate("audited:install")
  generate("strong_migrations:install")
  run("bundle exec standardrb --fix")
end
