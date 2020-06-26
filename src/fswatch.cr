require "./lib_fswatch"

module FSWatch
  VERSION = "0.1.0"

  class Error < ::Exception
  end

  record Event, path : String

  def self.init
    check LibFSWatch.init_library, "Unable to init fswatch"
  end

  private def self.check(status, message)
    raise Error.new(message) unless status == LibFSWatch::OK
  end

  class Session
    def initialize(monitor_type = LibFSWatch::MonitorType::SystemDefaultMonitorType)
      @handle = LibFSWatch.init_session(monitor_type)
    end

    def to_unsafe
      @handle
    end

    def finalize
      LibFSWatch.destroy_session(@handle)
    end

    def add_path(path : String | Path)
      check LibFSWatch.add_path(@handle, path.to_s), "Unable to add_path"
    end

    @@do_not_collect : Pointer(Void)?

    def set_callback(&callback : Event ->)
      boxed_data = Box.box(callback)
      @@do_not_collect = boxed_data

      status = LibFSWatch.set_callback(@handle, ->(events, event_num, data) {
        data_as_callback = Box(typeof(callback)).unbox(data)
        data_as_callback.call(Event.new(
          path: String.new(events.value.path)
        ))
      }, boxed_data)

      check status, "Unable to set_callback"
    end

    def start_monitor
      check LibFSWatch.start_monitor(@handle), "Unable to start_monitor"
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
