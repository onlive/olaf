# Copyright (C) 2013-2014 OL2, Inc.  See LICENSE.txt for details.

module OLFramework
  module ServiceSwagger
    # snake_case and camel_case implementations stolen from extlib 0.9.15
    def camel_case(s)
      s = s.to_s
      return s if s !~ /_/ && s =~ /[A-Z]+.*/
      s.split('_').map{|e| e.capitalize}.join
    end

    def snake_case(s)
      s = s.to_s
      return s.downcase if s.match(/\A[A-Z]+\z/)
      s.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
        gsub(/([a-z])([A-Z])/, '\1_\2').
        downcase
    end

    def swagger_hash(rsc_prefix)
      by_path = {}
      models = {}

      @request_types.each do |request_type|
        path, options, properties, action = request_type
        verb = options[:via]
        route_name = properties[:route_name]

        by_path[path] ||= []
        by_path[path] << request_type
      end

      path_list = swagger_paths(by_path, rsc_prefix)

      {
        "apiVersion" => "0.1",
        "swaggerVersion" => "1.1",
        "resourcePath" => "/#{rsc_prefix}",
        "apis" => path_list,
        "models" => swagger_models(@models),
      }
    end

    def swagger_paths(by_path, rsc_prefix)
      by_path.keys.sort.map do |path|
        routes = by_path[path]

        # In swagger, substitute "{var}" for ":var"
        path_parts = path.split("/").map do |s|
          s[0] == ":" ? "{#{camel_case s[1..-1]}}" : s
        end
        swagger_path = path_parts.join("/")

        ret = {
          "path" => "/#{rsc_prefix}/#{swagger_path}".gsub(/\/+/, "/")
        }

        description = @path_descs[path] ? @path_descs[path][:desc] : nil
        ret["description"] = description if description
        ret["operations"] = swagger_operations(routes)

        ret
      end
    end

    def swagger_operations(routes)
      routes.map do |path, options, properties, action|
        verb = options[:via]
        route_name = properties[:route_name]
        return_type = properties[:return_type]

        inner_ret = {
          "httpMethod" => verb.to_s.upcase,
        }
        inner_ret["summary"] = properties[:desc] if properties[:desc]
        inner_ret["nickname"] = camel_case(route_name) if route_name
        inner_ret["responseClass"] = swagger_type_convert(return_type) if return_type
        inner_ret["parameters"] = swagger_params(properties[:param]) if properties[:param]
        inner_ret["errorResponses"] = swagger_errors(properties[:errors] || [])
        inner_ret["notes"] = properties["notes"] || ""

        inner_ret
      end
    end

    def swagger_params(param_hash)
      param_hash.map do |name, param|
        ptype = param[:type]
        desc = param[:desc]
        options = param[:options]

        ret = {
          "name" => camel_case(name)
        }
        ret["description"] = desc if desc
        ret["paramType"] = options[:type] || "path"
        ret["required"] = !!options[:required]
        ret["allowMultiple"] = false
        ret["dataType"] = swagger_type_convert(ptype)
        ret
      end
    end

    def swagger_errors(errors)
      errors.map do |code, reason|
        {
          "code" => code,
          "reason" => reason,
        }
      end
    end

    def swagger_type_convert(olaf_type_spec)
      @models ||= {}

      return "string" if olaf_type_spec.nil?  # What is "anything"?

      return "void" if olaf_type_spec.to_s.downcase == "none"  # :none
      return "string" if olaf_type_spec == String
      return "int" if olaf_type_spec == Fixnum

      swagger_add_to_models olaf_type_spec
    end

    def swagger_add_to_models(olaf_type_spec)
      return "string" if olaf_type_spec.nil?

      type_key = olaf_type_spec.to_s
      return @models[type_key][:swagger] if @models[type_key]

      # Initialize Swagger primitives
      @swagger_types ||= {
        "string" => {
          :swagger_type => "string",
          :swagger_class => "object",
        },
        "void" => {
          :swagger_type => "void",
          :swagger_class => "object",
        },
        "int" => {
          :swagger_type => "int",
          :swagger_class => "object",
        },
      }

      if olaf_type_spec.is_a?(Hash)
        raise "Not yet implemented, but should be!"
      end

      if olaf_type_spec.is_a?(Array)
        singular_name = swagger_type_convert olaf_type_spec[0]

        # Use plural of swagger name for array-of-same
        swagger_name = singular_name + "s"
        raise "Swagger name conflict!" if @swagger_types[swagger_name]

        @models[type_key] = { :type => olaf_type_spec, :swagger => swagger_name,
                              :swagger_class => "list", :singular => singular_name }
        @swagger_types[swagger_name] = @models[type_key]

        return swagger_name
      end

      # TODO: const_get for stringified class names

      if olaf_type_spec.is_a?(Class) &&
          olaf_type_spec.ancestors.include?(OLFramework::DomainObject)
        swagger_name = olaf_type_spec.name.split("::")[-1]

        @models[type_key] = { :type => olaf_type_spec, :swagger => swagger_name,
                              :swagger_class => "object" }

        properties = olaf_type_spec.types.inject({}) do |h, (type_name, type_val)|
          h[type_name] = swagger_type_convert type_val
          h
        end
        @models[type_key][:properties] = properties

        @swagger_types[swagger_name] = @models[type_key]
        return swagger_name
      end

      STDERR.puts "Undefined Swagger mapping for type #{olaf_type_spec.inspect}!"
      "string"
    end

    def swagger_models(models)
      (models || {}).inject({}) do |models_out, (type_key, model_hash)|
        ruby_type = model_hash[:type]
        swagger_name = model_hash[:swagger]

        properties = model_hash[:properties] || {}

        models_out[swagger_name] = {
          "id" => swagger_name,
        }

        STDERR.puts "Swagger name: #{swagger_name.inspect} / #{@swagger_types[swagger_name].inspect}"
        case model_hash[:swagger_class]
        when "list"
          models_out[swagger_name]["properties"] = {
            swagger_name.downcase => {
              "type" => "List",
              "items" => { "$ref" => @swagger_types[swagger_name][:singular] },
            }
          }
        when "object"
          prop_list = properties.inject({}) do |h, (name, swagger_type)|
            h[name] = { "type" => swagger_type }
            h
          end
          models_out[swagger_name]["properties"] = prop_list
        else
          raise "Unrecognized Swagger object class: #{model_hash[:swagger_class].inspect}!"
        end

        models_out
      end
    end

  end
end
