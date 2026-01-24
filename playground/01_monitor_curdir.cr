require "../src/fswatch"

FSWatch.watch __DIR__ do |event|
  puts "got event for #{event.inspect}"
end

puts "watching (non recursively) #{__DIR__} for 10 seconds..."

sleep 10.seconds

puts "end"
