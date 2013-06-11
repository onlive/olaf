# Copyright (C) 2013 OL2, Inc. All Rights Reserved.

require 'log4r'
require 'json'

module Olaf
  # JSON formatter for log4r
  class JsonFormatter < Log4r::Formatter

    def initialize(options={})
      @pid = options[:pid] || true
      @thread = options[:thread] || true
      @datetime_format = options[:time_format] || nil
    end

    def format(event)
      h = {
          :time => format_datetime(Time.now),
          :level => Log4r::LNAMES[event.level],
          :logger => event.fullname
        }.merge( Log4r::MDC.get_context )
         .merge( format_data(event.data) )
         .merge( optional_data )
      h.to_json + "\n"
    end

    def optional_data
      ret = {}
      ret[:pid] = Process.pid.to_s if @pid
      ret[:thread] = (Thread.current[:name] or Thread.current.to_s) if @thread
      ndc = Log4r::NDC.get
      ret[:NDC] = ndc if ndc.length > 0
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

    def format_datetime(time)
      if @datetime_format.nil?
        time.strftime("%Y-%m-%dT%H:%M:%S.") << "%06d " % time.usec
      else
        time.strftime(@datetime_format)
      end
    end
  end
end
