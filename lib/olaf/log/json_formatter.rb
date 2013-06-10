# Copyright (C) 2013 OL2, Inc. All Rights Reserved.

require 'log4r'

module OLFramework
  # JSON formatter for log4r
  class JsonFormatter

    def initialize(options={})
      @pid = hash[:pid] or hash['pid'] or false
      @thread = hash[:thread] or hash['thread'] or false
    end

    def format(event)
      return
        { :level => LNAMES[event.level],
          :logger => event.full_name,
          :NDC => NDC.get
        }.merge( MDC.get_context )
         .merge( format_data(event.data) )
         .merge( optional_data )
    end

    def optional_data
      ret = {}
      ret[:pid] = Process.pid.to_s if @pid
      ret[:thread] = (Thread.current[:name] or Thread.current.to_s) if @thread
      ret
    end

    def format_data(data)
      return data if data.kind_of?(Hash)

      return { :message => data } if data.kind_of?(String)

      return data.to_h if data.respond_to?(:to_h)

      return data.to_hash if data.respond_to?(:to_hash)

      # Last resort
      return { :message => "#{data.class}: #{data.inspect}" }
    end

  end
end
