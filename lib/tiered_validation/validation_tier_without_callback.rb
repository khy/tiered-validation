module TieredValidation
  class ValidationTierWithoutCallbacks < ValidationTier
    def run_validations(action, instance)
      append_associated_validations(action)
      instance.method(:run_validations).call validation_symbol_for_action(action)
    end
    
    protected
      def define_validation_chains
        DEFAULT_VALIDATIONS.each do |default_validation|
          # def self.validate_for_admin(*methods, &block)
          #   methods << block if block_given?
          #   write_inheritable_set(:validate_for_admin, methods)
          # end
          @klass.class_eval  <<-BLOCK, __FILE__, __LINE__ + 1
            def self.#{validation_name(default_validation)}(*methods, &block)
              methods << block if block_given?
              write_inheritable_set(:#{validation_name(default_validation)}, methods)
            end
          BLOCK
        end
      end
      
      def validation_chain(action)
        @klass.read_inheritable_attribute validation_symbol_for_action(action)
      end

      def append_associated_validations(action)
        append_default_validations(action)
        append_included_tier_validations(action)
      end

      def append_default_validations(action)
        validation_chain = @klass.read_inheritable_attribute DEFAULT_ACTION_VALIDATION_MAP[action]
        append_validation_chain(action, validation_chain)
      end

      def append_included_tier_validations(action)
        @included_tiers.each do |tier_name|
          validation_chain = @klass::VALIDATION_TIERS[tier_name].validation_chain(action)
          append_validation_chain(action, validation_chain)
        end
      end
      
      def append_validation_chain(action, validation_chain)
        if validation_chain
          @klass.__send__ validation_symbol_for_action(action), *validation_chain
        end
      end
      
      def validation_symbol_for_action(action)
        validation_name(DEFAULT_ACTION_VALIDATION_MAP[action]).to_sym
      end
  end
end