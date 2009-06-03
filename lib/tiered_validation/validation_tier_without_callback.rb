require 'tiered_validation/validation_tier'

module TieredValidation
  class ValidationTierWithoutCallbacks < ValidationTier
    def run_validations(action, instance)
      add_included_tiers(action)
      instance.method(:run_validations).call validation_name_for_action(action)
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
        @klass.read_inheritable_attribute validation_name_for_action(action)
      end

      def add_included_tiers(action)
        @included_tiers.each do |tier_name|
          if validation_chain = @klass::VALIDATION_TIERS[tier_name].validation_chain(action)
            @klass.__send__ validation_name_for_action(action), *validation_chain
          end
        end
      end
      
      def validation_name_for_action(action)
        validation_name(DEFAULT_ACTION_VALIDATION_MAP[action]).to_sym
      end
  end
end