# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.
module OLFramework
  module ServiceHelpers
    #
    # This checks values against OLFramework::Service param types.
    # A param type is normally specified as a hash of property names
    # to types (param types, Ruby types or models).
    #
    # Normally, type would be specified as something like:
    #
    # { :name => String, :num => [Fixnum],
    #   :id => OLFramework::Required[Fixnum] }
    #
    def check_type_against_value(param_type, value, options = {:ignore_unknown_fields => true})
      if value == nil &&
          !(param_type.is_a?(Required) || param_type == Required)
        # Nil is a valid instance of any non-required param
        return value
      end

      if param_type == Required
        param_type_error "Value is required, but nil given!" if value == nil

        # If it's Required but no type specified, any non-nil value is fine.
        return value
      end

      # if this is one of our domain objects, make it perform its own type checking
      if param_type.respond_to?(:check_hash_against_domain_object)
        return check_domain_object_type_against_value(param_type, value, options)
      end

      # this type checking code will attempt to type-check strings & hashes vs. classes. However,
      # it is definitely preferred that you use a DomainObject to get complete checking.
      case param_type
        when Class

        if !value.is_a?(param_type) && param_type.respond_to?(:type_check_against_ol_value)
          return param_type.type_check_against_ol_value(value)
        end

        # if this thing is actually Hash, then just do Hash vs. class checking
        # TODO: remove this whole block; rely on DomainObject type checking
        if param_type != Hash
          if value.is_a?(Hash)
            check_class_against_hash(param_type, value)
          return value
          # if we're getting a string and we're checking against something that is not a string,
          # parse this into a hash.
          elsif value.is_a?(String) && param_type != String
            begin
              json_value = JSON.parse(value)
            rescue => e
              # swallow exceptions if we failed to parse
            end
            if json_value
              check_class_against_hash(param_type, json_value)
              return value
            end
          end
        end

      unless value.is_a?(param_type)
        param_type_error "Value #{value.inspect} is not of " +
                             "type #{param_type.name}!"
      end

      when Required
        param_type_error "Value nil doesn't match " +
          "Required[#{param_type.klass.inspect}]!" if value.nil?
        check_type_against_value(param_type.klass, value)

      when Array
        # We may eventually add a feature where an Array of scalar
        # values means a list of allowed fields.  For now, we assume
        # it means a literal Array in the value.
        test_value = value
        if test_value.is_a?(String)
          # if value is a string, this test is going to fail. But maybe it's a JSON
          # version of an array, so let's give that a try.
          begin
            test_value = JSON.parse(test_value)
          rescue => e
            # if we got any exeptions, then restore test_value
            test_value = value
          end
        end

        unless test_value.is_a? Array
          param_type_error "Value #{test_value.inspect} isn't an Array!"
        end

        if param_type.size > 1
          param_type_error "Malformed param_type #{param_type.inspect}!"
        end

        test_value.each { |v| check_type_against_value param_type[0], v }

      when Hash
        unless value.is_a? Hash
          param_type_error "Value #{value.inspect} can't have properties " +
            "#{param_type.inspect}!"
        end

        bad_fields = value.keys - param_type.keys
        unless bad_fields.empty?
          param_type_error "Value #{value.inspect} has disallowed fields " +
            "#{bad_fields.inspect} not in type #{param_type.inspect}!"
        end

        param_type.keys.each do |key|
          # This works fine even if value[key] is nil
          check_type_against_value param_type[key], value[key]
        end
      end

      value
    end

    def check_domain_object_type_against_value(param_type, value, options)
      if value.is_a?(Hash)
        return param_type.check_hash_against_domain_object(value, options)
      elsif value.is_a?(String)
        begin
          hash = JSON.parse(value)
        rescue => e
          param_type_error "Value #{value.inspect} cannot be converted to a hash for checking against #{param_type}."
        end
        return param_type.check_hash_against_domain_object(hash, options)
      else
        if value.is_a?(param_type)
          return value
        else
          param_type_error "Value #{value} is a #{value.class}, which cannot be converted to #{param_type}."
        end
      end
    end

    # TODO: this should be obsoleted by the DomainObject type checking. So maybe we should remove this at some point.
    def check_class_against_hash(klass, hash)
      # Nil matches all klasses
      return hash if hash.nil?

      param_type_error("Value #{hash.inspect} is not a hash, so cannot match #{klass}.") unless hash.is_a?(Hash)

      class_methods = klass.instance_methods
      # convert symbols to strings since I don't think we trust this hash? We could leak if we try
      # to convert everything in the hash to symbols
      class_methods = class_methods.map { |method| method.to_s }
      body_hash = hash.dup
      if body_hash.kind_of?(Array)
        body_hash = body_hash[0]
      end
      bad_fields = []
      body_hash.keys.each() do | key, value |
        if !class_methods.include?(key.to_s)
          bad_fields << key
        end
      end
      unless bad_fields.empty?
        param_type_error "Value #{hash.inspect} has disallowed fields #{bad_fields.inspect} that are not in type #{klass}."
      end

      return hash
    end

    def param_type_error(message)
      raise OLFramework::ParamTypeError.new :message => message
    end
  end
end
