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

  def self.init
    check LibFSWatch.init_library, "Unable to init fswatch"
  end

  private def self.check(status, message)
    raise Error.new(message) unless status == LibFSWatch::OK
  end

  class Session
    @changes : Channel(Event)
    @on_change : Event ->

    def initialize(monitor_type : MonitorType = MonitorType::SystemDefault)
      @handle = LibFSWatch.init_session(monitor_type)
      @on_change = ->(e : Event) {}
      @changes = Channel(Event).new
      setup_handle_callback
    end

    def to_unsafe
      @handle
    end

    def finalize
      LibFSWatch.destroy_session(@handle)
    end

    # :nodoc:
    protected def setup_handle_callback
      status = LibFSWatch.set_callback(@handle, ->(events, event_num, data) {
        changes = Box(Channel(Event)).unbox(data)
        changes.send(Event.new(
          path: String.new(events.value.path)
        ))
      }, Box.box(@changes))

      check status, "Unable to set_callback"

      spawn do
        loop do
          @on_change.call(@changes.receive)
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

    private def check(status, message)
      raise Error.new(message) unless status == LibFSWatch::OK
    end
  end
end

FSWatch.init
