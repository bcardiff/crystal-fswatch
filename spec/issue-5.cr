{% if flag?(:execution_context) %}
  puts "mode: execution context"
{% elsif flag?(:preview_mt) %}
  puts "mode: multi-thread"
{% else %}
  puts "mode: single-thread"
{% end %}

require "log"
require "../src/fswatch"
require "./support/tempfile"

# Workaround
#
# lib LibGC
#   $stackbottom = GC_stackbottom : Void*
# end
#
# module GC
#   def self.current_thread_stack_bottom
#     {Pointer(Void).null, LibGC.stackbottom}
#   end
#
#   def self.set_stackbottom(stack_bottom : Void*)
#     LibGC.stackbottom = stack_bottom
#   end
# end

with_tempdir do |path|
  channel = Channel(FSWatch::Event).new

  puts "watching #{path}..."
  FSWatch.watch path do |event|
    channel.send event
  end

  sleep 1.seconds

  File.write(File.join(path, "file.txt"), "")

  puts channel.receive

  puts "done"
end
