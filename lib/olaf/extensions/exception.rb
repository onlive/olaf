class Exception
  def to_ol_hash
    if ["development", "test"].include? ENV['RACK_ENV']
      {
        :class => self.class,
        :message => message,
        :backtrace => backtrace
      }
    else
      {
        :class => self.class,
        :message => message
      }
    end
  end
end
