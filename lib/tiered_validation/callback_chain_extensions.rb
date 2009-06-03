module TieredValidation
  module CallbackChain
    def |(other_chain)
      ActiveSupport::Callbacks::CallbackChain.new(super(other_chain))
    end
  end
end

module ActiveSupport
  module Callbacks
    class CallbackChain
      include TieredValidation::CallbackChain
    end
  end
end