# frozen-string-literal: true
#
module Sequel
  module RetryIt
    def with_retries
      retries = 0
      begin
        yield
      rescue Exception => e
        if (retries += 1) <= opts[:retries].to_i
          timeout = retries * opts.fetch(:retry_delay, 5).to_i
          puts "Timeout (#{e.message.chomp}), retrying in #{timeout} second(s)..."
          sleep(timeout)
          retry
        else
          raise
        end
      end
    end

    def connect(*args)
      with_retries do
        super
      end
    end
  end

  Database.register_extension(:retry, RetryIt)
end


