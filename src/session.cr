lib LibGC
  fun allow_register_threads = GC_allow_register_threads : Void
  fun thread_is_registered = GC_thread_is_registered : Int
  fun register_my_thread = GC_register_my_thread(sb : StackBase*) : Int
end

class Thread
  # :doc:
  def self.ensure_registered
    register if LibGC.thread_is_registered == 0
  end

  # :doc:
  def self.register
    current_pthread = LibC.pthread_self
    address = LibC.pthread_get_stackaddr_np(current_pthread)
    LibGC.register_my_thread(address.as(LibGC::StackBase*))
  end
end

module FSWatch
  # Based on https://stackoverflow.com/a/8941979/30948
  class MVar(T)
    @put_cond : Thread::ConditionVariable
    @take_cond : Thread::ConditionVariable
    @lock : Thread::Mutex
    @value : T?

    def initialize
      @put_cond = Thread::ConditionVariable.new
      @take_cond = Thread::ConditionVariable.new
      @lock = Thread::Mutex.new
      @value = nil
    end

    def put(value : T)
      @lock.synchronize do
        while !@value.nil?
          @put_cond.wait(@lock) # if MVar is full, wait until another thread takes the value - release the mutex,  and wait on put_cond to become true
        end
        @value = value    # if here, we got the signal from another thread that took MVar - MVar is empty now. OK to fill
        @take_cond.signal # signal other threads that value is available for taking now
      end
    end

    def take : T
      @lock.synchronize do
        while @value.nil?
          @take_cond.wait(@lock) # if MVar is empty, wait until another thread puts a value - release the mutex, and wait on take_cond to become true
        end
        val = @value.not_nil! # if here, we got the signal from another thread that put a value - MVar is full now. OK to take
        @value = nil          # empty the MVar
        @put_cond.signal      # signal other threads that MVar is empty now, so they can put a value
        return val
      end
    end
  end

  class Session
    @on_change : Event ->

    @portal : ThreadPortal(Slice(Event))

    @_running : Bool

    def initialize(monitor_type : MonitorType = MonitorType::SystemDefault)
      @handle = LibFSWatch.init_session(monitor_type)
      @on_change = ->(e : Event) { }
      @portal = ThreadPortal(Slice(Event)).new
      @_running = false
      @event_data = MVar({Pointer(LibFSWatch::Cevent), LibC::UInt}).new
      @event_processed = MVar(Bool).new
      setup_handle_callback
    end

    def to_unsafe
      @handle
    end

    def finalize
      LibFSWatch.destroy_session(@handle)
    end

    # :nodoc:
    protected def portal
      @portal
    end

    # :nodoc:
    protected def _running : Bool
      @_running
    end

    # :nodoc:
    protected def setup_handle_callback
      # LibGC.allow_register_threads

      Thread.new do
        while (e = @event_data.take)
          events, event_num = e

          # fswatch is calling the callback even after the stop_monitoring is called
          @portal.send events.to_slice(event_num).map { |ev|
            Event.new(
              path: String.new(ev.path),
              event_flag: ev.flags.value
            )
          }

          @event_processed.put(true)
        end
      end

      status = LibFSWatch.set_callback(@handle, ->(events, event_num, data) {
        # Thread.ensure_registered
        session = Box(Session).unbox(data)
        if session._running
          session.@event_data.put({events, event_num})
          session.@event_processed.take # wait until the events are processed
        end
      }, Box.box(self))

      check status, "Unable to set_callback"

      spawn do
        loop do
          @portal.receive.each do |ev|
            @on_change.call(ev)
          end
        end
      end
    end

    def add_path(path : String | Path)
      check LibFSWatch.add_path(@handle, path.to_s), "Unable to add_path"
    end

    def on_change(&on_change : Event ->)
      @on_change = on_change
    end

    def start_monitor
      {% if flag?(:preview_mt) && flag?(:execution_context) %}
        Fiber::ExecutionContext::Isolated.new("crystal-fswatch.monitor") do
          check LibFSWatch.start_monitor(@handle), "Unable to start_monitor"
        end
      {% else %}
        Thread.new "crystal-fswatch.monitor" do
          check LibFSWatch.start_monitor(@handle), "Unable to start_monitor"
        end
      {% end %}
      @_running = true
    end

    def stop_monitor
      check LibFSWatch.stop_monitor(@handle), "Unable to stop_monitor"
      @_running = false
    end

    def is_running
      check LibFSWatch.is_running(@handle), "Unable to is_running"
    end

    def latency=(value : Float64)
      check LibFSWatch.set_latency(@handle, value), "Unable to set_latency"
    end

    def recursive=(value : Bool)
      check LibFSWatch.set_recursive(@handle, value), "Unable to set_recursive"
    end

    def directory_only=(value : Bool)
      check LibFSWatch.set_directory_only(@handle, value), "Unable to set_directory_only"
    end

    def follow_symlinks=(value : Bool)
      check LibFSWatch.set_follow_symlinks(@handle, value), "Unable to set_follow_symlinks"
    end

    def add_property(name : String, value : String)
      check LibFSWatch.add_property(@handle, name, value), "Unable to add_property"
    end

    def allow_overflow=(value : Bool)
      check LibFSWatch.set_allow_overflow(@handle, value), "Unable to set_allow_overflow"
    end

    def add_event_type_filter(event_type : EventTypeFilter)
      etv = LibFSWatch::EventTypeFilter.new
      etv.flag = event_type.flag
      check LibFSWatch.add_event_type_filter(@handle, etv), "Unable to add_event_type_filter"
    end

    def add_filter(monitor_filter : MonitorFilter)
      cmf = LibFSWatch::CmonitorFilter.new
      cmf.text = monitor_filter.text.to_unsafe
      cmf.type = monitor_filter.type
      cmf.case_sensitive = monitor_filter.case_sensitive
      cmf.extended = monitor_filter.extended
      check LibFSWatch.add_filter(@handle, cmf), "Unable to add_filter"
    end

    private def check(status, message)
      raise Error.new(message) unless status == LibFSWatch::OK
    end

    def self.build(*,
                   latency : Float64? = nil,
                   recursive : Bool? = nil,
                   directory_only : Bool? = nil,
                   follow_symlinks : Bool? = nil,
                   allow_overflow : Bool? = nil,
                   properties : Hash(String, String)? = nil,
                   event_type_filters : Array(EventTypeFilter)? = nil,
                   filters : Array(MonitorFilter)? = nil)
      session = FSWatch::Session.new
      session.latency = latency unless latency.nil?
      session.recursive = recursive unless recursive.nil?
      session.directory_only = directory_only unless directory_only.nil?
      session.follow_symlinks = follow_symlinks unless follow_symlinks.nil?
      session.allow_overflow = allow_overflow unless allow_overflow.nil?
      if properties
        properties.each { |k, v| session.add_property(k, v) }
      end
      if event_type_filters
        event_type_filters.each { |etv| session.add_event_type_filter(etv) }
      end
      if filters
        filters.each { |f| session.filters(etv) }
      end

      session
    end
  end
end
