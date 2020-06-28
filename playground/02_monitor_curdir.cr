require "../src/fswatch"

i = 5
FSWatch.watch __DIR__ do |event|
  i -= 1
  pp! event
end

while i > 0
  puts "Waiting for #{i} events"
  sleep 0.1
  Fiber.yield
end
