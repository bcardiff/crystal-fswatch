module FSWatch
  # :nodoc:
  struct ThreadPortal(T)
    @producer_reader : IO::FileDescriptor
    @producer_writer : IO::FileDescriptor
    @consumer_reader : IO::FileDescriptor
    @consumer_writer : IO::FileDescriptor
    @next_value : T

    def initialize
      @producer_reader, @producer_writer = IO.pipe(read_blocking: false, write_blocking: true)
      @consumer_reader, @consumer_writer = IO.pipe(read_blocking: true, write_blocking: false)
      @next_value = uninitialized T
    end

    def send(value : T)
      @next_value = value
      value = 1i32
      LibC.write(@producer_writer.fd, pointerof(value), sizeof(Int32))
      LibC.read(@consumer_reader.fd, pointerof(value), sizeof(Int32))
    end

    def receive : T
      @producer_reader.read_bytes(Int32)
      value = @next_value
      @consumer_writer.write_bytes(1i32)
      value
    end
  end
end
