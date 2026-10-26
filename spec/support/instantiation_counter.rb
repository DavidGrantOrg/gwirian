# How many records of class_name Active Record builds while the block runs.
# Records an eager_load builds from a JOIN are reported under the query's base class,
# so they are not counted here.
module InstantiationCounter
  def records_instantiated(class_name)
    count = 0
    counter = ->(_name, _start, _finish, _id, payload) { count += payload[:record_count] if payload[:class_name] == class_name }
    ActiveSupport::Notifications.subscribed(counter, "instantiation.active_record") { yield }
    count
  end
end

RSpec.configure do |config|
  config.include InstantiationCounter
end
