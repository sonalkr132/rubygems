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
        mutex = Mutex.new
        errors = Queue.new
        cond_var = ConditionVariable.new

        Addrinfo.foreach(host, serv, nil, :STREAM) do |addr|
          Thread.new(addr) do
            begin
              conn = super(addr.ip_address, serv, *rest)
              mutex.synchronize do
                conns << conn
                cond_var.signal
              end
            rescue Exception => e
              errors << e
            end
          end
        end

        mutex.synchronize do
          timeout_time = CONNECTION_TIMEOUT + Time.now.to_f
          while conns.empty? && (remaining_time = timeout_time - Time.now.to_f) > 0
            cond_var.wait(mutex, remaining_time)
          end

          raise errors.pop if conns.empty?
          conns.shift
        end
      end
    end
  end
end

TCPSocket.prepend CoreExtensions::TCPSocketExt
