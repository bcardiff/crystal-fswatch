require "./lib_fswatch"

module FSWatch
  VERSION = "0.1.0"

  class Error < ::Exception
  end

  record Event, path : String

  enum MonitorType
    SystemDefault
    Fsevents
    Kqueue
    Inotify
    Windows
    Poll
    Fen

    def to_unsafe
      case self
      in SystemDefault then LibFSWatch::MonitorType::SystemDefaultMonitorType
      in Fsevents      then LibFSWatch::MonitorType::FseventsMonitorType
      in Kqueue        then LibFSWatch::MonitorType::KqueueMonitorType
      in Inotify       then LibFSWatch::MonitorType::InotifyMonitorType
      in Windows       then LibFSWatch::MonitorType::WindowsMonitorType
      in Poll          then LibFSWatch::MonitorType::PollMonitorType
      in Fen           then LibFSWatch::MonitorType::FenMonitorType
      end
    end
  end

  alias EventFlag = LibFSWatch::EventFlag

  record EventTypeFilter, flag : EventFlag

  alias FilterType = LibFSWatch::FilterType

  record MonitorFilter, text : String, type : FilterType, case_sensitive : Bool, extended : Bool

  def self.init
    check LibFSWatch.init_library, "Unable to init_library"
  end

  def self.verbose
    LibFSWatch.is_verbose != 0
  end

  def self.verbose=(value : Bool)
    LibFSWatch.set_verbose(value)
    value
  end

  def self.event_flag_by_name(name : String) : EventFlag
    check LibFSWatch.get_event_flag_by_name(name, out flag), "Unable to event_flag_by_name"
    flag
  end

  def self.event_flag_name(flag : EventFlag)
    String.new(LibFSWatch.get_event_flag_name(flag))
  end

  private def self.check(status, message)
    raise Error.new(message) unless status == LibFSWatch::OK
  end

  # :nodoc:
  struct ThreadPortal(T)
    {% if flag?(:preview_mt) %}
      @channel : Channel(T)

      def initialize
        @channel = Channel(T).new
      end
    {% else %}
      @producer_reader : IO
      @producer_writer : IO
      @consumer_reader : IO
      @consumer_writer : IO
      @next_value : T

      def initialize
        @producer_reader, @producer_writer = IO.pipe(read_blocking: false, write_blocking: true)
        @consumer_reader, @consumer_writer = IO.pipe(read_blocking: false, write_blocking: true)
        @next_value = uninitialized T
      end
    {% end %}

    def send(value : T)
      {% if flag?(:preview_mt) %}
        @channel.send value
      {% else %}
        @next_value = value
        @producer_writer.write_bytes(1i32)
        @consumer_reader.read_bytes(Int32)
      {% end %}
    end

    def receive : T
      {% if flag?(:preview_mt) %}
        @channel.receive
      {% else %}
        @producer_reader.read_bytes(Int32)
        value = @next_value
        @consumer_writer.write_bytes(1i32)
        value
      {% end %}
    end
  end

  class Session
    @on_change : Event ->

    @portal : ThreadPortal(Event)

    def initialize(monitor_type : MonitorType = MonitorType::SystemDefault)
      @handle = LibFSWatch.init_session(monitor_type)
      @on_change = ->(e : Event) {}
      @portal = ThreadPortal(Event).new
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
    protected def setup_handle_callback
      status = LibFSWatch.set_callback(@handle, ->(events, event_num, data) {
        session = Box(Session).unbox(data)
        event = Event.new(
          path: String.new(events.value.path)
        )
        session.portal.send event
      }, Box.box(self))

      check status, "Unable to set_callback"

      spawn do
        loop do
          @on_change.call(@portal.receive)
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
      Thread.new do
        check LibFSWatch.start_monitor(@handle), "Unable to start_monitor"
      end
    end

    def stop_monitor
      check LibFSWatch.stop_monitor(@handle), "Unable to stop_monitor"
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
  end

  def self.watch(path : String | Path, *,
                 latency : Float64? = nil,
                 recursive : Bool? = nil,
                 directory_only : Bool? = nil,
                 follow_symlinks : Bool? = nil,
                 allow_overflow : Bool? = nil,
                 properties : Hash(String, String)? = nil,
                 event_type_filters : Array(EventTypeFilter)? = nil,
                 filters : Array(MonitorFilter)? = nil,
                 &block : Event ->)
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
    session.on_change(&block)
    session.add_path path
    session.start_monitor
  end
end

FSWatch.init
