module TieredValidation
  class ValidationTierWithCallbacks < ValidationTier
    def run_validations(action, instance)
      callback_chain(action).run(instance)
    end
    
    protected
      def define_validation_chains
        validation_names = DEFAULT_VALIDATIONS.map do |default_validation|
          validation_name(default_validation)
        end
        @klass.define_callbacks *validation_names
      end
    
      def callback_chain(action)
        callback_chain = base_callback_chain(action).clone
        callback_chain |= default_callback_chain(action)

        @included_tiers.each do |tier|
          callback_chain |= @klass.validation_tiers[tier].callback_chain(action) 
        end

        callback_chain
      end

      def base_callback_chain(action)
        callback_chain_name = validation_callback_chain_name(DEFAULT_ACTION_VALIDATION_MAP[action])
        @klass.__send__ callback_chain_name
      end

      def default_callback_chain(action)
        @klass.__send__ DEFAULT_ACTION_VALIDATION_MAP[action]
      end

      def validation_callback_chain_name(default_callback)
        "#{validation_name(default_callback)}_callback_chain"
      end
  end
end