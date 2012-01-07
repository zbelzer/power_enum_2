# Copyright (c) 2005 Trevor Squires
# Released under the MIT License.  See the LICENSE file for more details.

module ActiveRecord
  module Aggregations # :nodoc:
    module HasEnumerated # :nodoc:

      def self.append_features(base)
        super      
        base.extend(MacroMethods)
      end

      module MacroMethods

        def enumerated_attributes
          @enumerated_attributes ||= []
        end

        def has_enumerated?(attribute)
          return false unless attribute
          enumerated_attributes.include? attribute.to_s
        end

        # Defines an enumerated attribute with the given name on the model.  Also accepts a hash of options as an
        # optional second argument.
        #
        # === Supported options
        # [:class_name]
        #   Name of the enum class.  By default it is the camel-ized version of the has_enumerated attribute.
        # [:foreign_key]
        #   Explicitly set the foreign key column.  By default it's assumed to be your_enumerated_attribute_name_id.
        # [:on_lookup_failure]
        #   The :on_lookup_failure option in has_enumerated is there because you may want to create an error handler for
        #   situations where the argument passed to status=(arg) is invalid. By default, an invalid value will cause an
        #   ArgumentError to be raised.  Since this may not be optimal in your situation, you can specify an instance
        #   method to be called in the case of a lookup failure. The method signature is as follows:
        #     <tt>your_lookup_handler(operation, name, name_foreign_key, acts_enumerated_class_name, lookup_value)</tt>
        #   The 'operation' arg will be either :read or :write.  In the case of :read you are expected to return
        #   something or raise an exception, while in the case of a :write you don't have to return anything.  Note that
        #   there's enough information in the method signature that you can specify one method to handle all lookup
        #   failures for all has_enumerated fields if you happen to have more than one defined in your model.
        #   'NOTE': A nil is always considered to be a valid value for status=(arg) since it's assumed you're trying to
        #    null out the foreign key. The :on_lookup_failure method will be bypassed.
        # [:permit_empty_name]
        #   Setting this to 'true' disables automatic conversion of empty strings to nil.  Default is 'false'.
        # [:default]
        #   Setting this option will generate an after_initialize callback to set a default value on the attribute
        #   unless a non-nil one already exists.
        #
        # === Example
        #  class Booking < ActiveRecord::Base
        #    has_enumerated  :status,
        #                    :class_name        => 'BookingStatus',
        #                    :foreign_key       => 'status_id',
        #                    :on_lookup_failure => :optional_instance_method,
        #                    :permit_empty_name => true
        #                    :default           => :unconfirmed
        #  end
        def has_enumerated(part_id, options = {})
          options.assert_valid_keys(:class_name, :foreign_key, :on_lookup_failure, :permit_empty_name, :default)

          reflection = PowerEnum::Reflection::EnumerationReflection.new(part_id, options, self)
          self.reflections.merge! part_id => reflection

          name        = part_id.to_s
          class_name  = reflection.class_name
          foreign_key = reflection.foreign_key
          failure     = options[:on_lookup_failure]
          empty_name  = options[:permit_empty_name]

          module_eval <<-end_eval
            def #{name}
              rval = #{class_name}.lookup_id(self.#{foreign_key})
              if rval.nil? && #{!failure.nil?}
                return self.send(#{failure.inspect}, :read, #{name.inspect}, #{foreign_key.inspect}, #{class_name.inspect}, self.#{foreign_key})
              end
              return rval
            end         

            def #{name}=(arg)
              #{!empty_name ? 'arg = nil if arg.blank?' : ''}
              case arg
              when #{class_name}
                val = #{class_name}.lookup_id(arg.id)
              when String
                val = #{class_name}.lookup_name(arg)
              when Symbol
                val = #{class_name}.lookup_name(arg.id2name)
              when Fixnum
                val = #{class_name}.lookup_id(arg)
              when nil
                self.#{foreign_key} = nil
                return nil
              else     
                raise TypeError, "#{self.name}: #{name}= argument must be a #{class_name}, String, Symbol or Fixnum but got a: \#{arg.class.name}"            
              end

              if val.nil? 
                if #{failure.nil?}
                  raise ArgumentError, "#{self.name}: #{name}= can't assign a #{class_name} for a value of (\#{arg.inspect})"
                end
                self.send(#{failure.inspect}, :write, #{name.inspect}, #{foreign_key.inspect}, #{class_name.inspect}, arg)
              else
                self.#{foreign_key} = val.id
              end
            end
          end_eval

          enumerated_attributes << name

          if options.has_key?(:default)
            default = options[:default]
            set_default_method = "set_default_value_for_#{name}".to_sym

            after_initialize set_default_method

            define_method set_default_method do
              self.send("#{name}=", default) if self.send(name).nil?
            end
            private set_default_method
          end

        end #has_enumerated

      end #module MacroMethods

    end #module HasEnumerated
  end #module Aggregations
end
