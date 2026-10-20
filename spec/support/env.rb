# An example tagged `env: { "APP_NAME" => "Playbook" }` runs with those variables set, and each is restored after it.
# A variable that was unset is deleted again, since an empty string would read as a value.
RSpec.configure do |config|
  config.around(:each, :env) do |example|
    previous = example.metadata[:env].keys.to_h { |key| [ key, ENV[key] ] }
    example.metadata[:env].each { |key, value| ENV[key] = value }
    example.run
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end
