require 'tiered_validation/validation_tier'

module TieredValidation
  class ValidationTierWithCallbacks < ValidationTier
    def run_validations(action, instance)
      callback_chain(action).run(instance)
    end
    
    protected
      def define_validation_chains
        validation_names = ValidationTier::DEFAULT_VALIDATIONS.map do |default_validation|
          validation_name(default_validation)
        end
        @klass.define_callbacks *validation_names
      end
    
      def callback_chain(action)
        callback_chain = base_callback_chain(action).clone

        @included_tiers.each do |tier|
          callback_chain += @klass::VALIDATION_TIERS[tier].callback_chain(action) 
        end
      
        callback_chain.uniq
      end

      def base_callback_chain(action)
        @base_callback_chains ||= {}
        callback_chain_name = validation_callback_chain_name(ValidationTier::DEFAULT_ACTION_VALIDATION_MAP[action])
        @base_callback_chains[action] ||= @klass.__send__ callback_chain_name
      end

      def validation_callback_chain_name(default_callback)
        "#{validation_name(default_callback)}_callback_chain"
      end
  end
end