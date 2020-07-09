require "../src/fswatch"

FSWatch.watch "./playground" do |event|
  pp! event
end

puts "sleeping..."
sleep 10
