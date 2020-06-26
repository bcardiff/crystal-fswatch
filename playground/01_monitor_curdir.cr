require "../src/fswatch"

session = FSWatch::Session.new
session.add_path __DIR__
session.set_callback do |event|
  pp! event
end

spawn do
  puts "Starting monitor"
  session.start_monitor
end

sleep 10

puts "Stopping monitor"
session.stop_monitor
