require 'socket'

module CoreExtensions
  module TCPSocketExt
    def self.prepended(base)
      base.prepend Initializer
    end

    module Initializer
      CONNECTION_TIMEOUT = 5

      def initialize(host, serv, *rest)
        conns = []
        @threads = []

        mutex = Mutex.new
        errors = Queue.new
        cond_var = ConditionVariable.new

        Thread.report_on_exception = false if defined? Thread.report_on_exception = ()

        Addrinfo.foreach(host, serv, nil, :STREAM) do |addr|
          @threads << Thread.new(addr) do
            begin
              conn = super(addr.ip_address, serv, *rest)

              mutex.synchronize do
                unless conn.closed? || conn.nil?
                  conns << conn
                  cond_var.signal
                end
              end
            rescue Exception => e
              mutex.synchronize do
                errors << e
              end
            end
          end
        end

        mutex.synchronize do
          timeout_time = CONNECTION_TIMEOUT + Time.now.to_f
          while conns.empty? && (remaining_time = timeout_time - Time.now.to_f) > 0
            cond_var.wait(mutex, remaining_time)
          end

          raise errors.pop if conns.empty?
        end

        @threads.each(&:join)
        conns.shift
      end

    end
  end
end

TCPSocket.prepend CoreExtensions::TCPSocketExt
