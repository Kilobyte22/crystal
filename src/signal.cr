lib LibC
  alias SigT = Int32 ->
  fun signal(sig : Int, handler : SigT) : SigT
end

ifdef darwin
  enum Signal
    HUP    =  1
    INT    =  2
    QUIT   =  3
    ILL    =  4
    TRAP   =  5
    IOT    =  6
    ABRT   =  6
    EMT    =  7
    FPE    =  8
    KILL   =  9
    BUS    = 10
    SEGV   = 11
    SYS    = 12
    PIPE   = 13
    ALRM   = 15
    TERM   = 15
    URG    = 16
    STOP   = 17
    TSTP   = 18
    CONT   = 19
    CHLD   = 20
    CLD    = 20
    TTIN   = 21
    TTOU   = 22
    IO     = 23
    XCPU   = 24
    XFSZ   = 25
    VTALRM = 26
    PROF   = 27
    WINCH  = 28
    INFO   = 29
    USR1   = 30
    USR2   = 31
  end
else
  enum Signal
    HUP    = 1
    INT    = 2
    QUIT   = 3
    ILL    = 4
    TRAP   = 5
    ABRT   = 6
    IOT    = 6
    BUS    = 7
    FPE    = 8
    KILL   = 9
    USR1   = 10
    SEGV   = 11
    USR2   = 12
    PIPE   = 13
    ALRM   = 14
    TERM   = 15
    STKFLT = 16
    CLD    = 17
    CHLD   = 17
    CONT   = 18
    STOP   = 19
    TSTP   = 20
    TTIN   = 21
    TTOU   = 22
    URG    = 23
    XCPU   = 24
    XFSZ   = 25
    VTALRM = 26
    PROF   = 27
    WINCH  = 28
    POLL   = 29
    IO     = 29
    PWR    = 30
    SYS    = 31
    UNUSED = 31
  end
end

enum Signal

  @@initialized = false

  protected def self.init
    unless @@initialized
      @@signal_queue = [] of {Fiber, Int32}
      @@handlers = {} of Int32 => Int32 ->
      @@signal_channel = Channel(Int32).new

      @@signal_fiber = Fiber.new do
        # This fiber is just so we can do stuff without breaking the scheduler
        loop do
          until @@signal_queue.not_nil!.empty?
            sig = @@signal_queue.not_nil!.pop
            Scheduler.enqueue Fiber.current
            sig[0].resume # Lets make sure the signal handler exits cleanly before any further stuff

            # If there really is another signal to be handled this function will return before the first signal has been processed.
            # However that does not matter as it will simply handle the new signal and after that it'll continue handling the old one
            @@signal_channel.not_nil!.send sig[1]
          end
          Scheduler.reschedule
        end
      end

      spawn do
        # This is the fiber the actual handlers will run in
        while signum = @@signal_channel.not_nil!.receive
          @@handlers.not_nil![signum]?.try &.call(signum)
        end
      end
    end
  end

  def trap(block : Int32 ->)
    trap &block
  end

  def trap(&block : Int32 ->)
    Signal.init
    trap_raw do |signum|
      @@signal_queue.not_nil! << {Fiber.current, signum}
      @@signal_fiber.not_nil!.resume
    end
  end

  def trap_raw(&block : Int32 ->)
    if block.closure?
      handlers = @@raw_handlers ||= {} of Int32 => Int32 ->
      handlers[value] = block
      LibC.signal value, ->(num) do
        @@raw_handlers.not_nil![num]?.try &.call(num)
      end
    else
      LibC.signal value, block
    end
  end

  def trap_raw(block : Int32 ->)
    trap &block
  end

  def reset
    trap_raw Proc(Int32, Void).new(Pointer(Void).new(0_u64), Pointer(Void).null)
  end

  def ignore
    trap_raw Proc(Int32, Void).new(Pointer(Void).new(1_u64), Pointer(Void).null)
  end
end
