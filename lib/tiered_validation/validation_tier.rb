module TieredValidation
  class ValidationTier
    DEFAULT_ACTION_CALLBACK_MAP = {
      :save => :validate,
      :update => :validate_on_update,
      :create => :validate_on_create
    }.freeze
    
    DEFAULT_VALIDATION_CALLBACKS = DEFAULT_ACTION_CALLBACK_MAP.values.freeze
    
    def initialize(name, klass, includes = [], exclusive = true)
      @name = name
      @klass = klass
      @included_tiers = includes.is_a?(Array) ? includes : [includes].compact
      @exclusive = exclusive
      @klass.define_callbacks *DEFAULT_VALIDATION_CALLBACKS.map{|default_callback| callback_name(default_callback)}
    end

    def callback_chain(action)
      callback_chain = base_callback_chain(action).clone

      @included_tiers.each do |tier|
        callback_chain += @klass::VALIDATION_TIERS[tier].callback_chain(action) 
      end
      
      callback_chain.uniq
    end

    def run_callbacks(action, instance)
      callback_chain(action).run(instance)
    end

    def setup_alias_methods
      DEFAULT_VALIDATION_CALLBACKS.each do |default_callback|
        if @exclusive
          @klass.class_eval <<-BLOCK, __FILE__, __LINE__ + 1                                
            def self.#{callback_with_tier(default_callback)}(*methods, &block)              # def self.validate_with_tier(*methods, &block)         
              #{callback_name(default_callback)} *methods, &block                           #   validate_for_admin *methods, &block
            end                                                                             # end
          BLOCK
        else
          @klass.class_eval <<-BLOCK, __FILE__, __LINE__ + 1
            def self.#{callback_with_tier(default_callback)}(*methods, &block)              # def self.validate_with_tier(*methods, &block)    
              #{callback_name(default_callback)} *methods, &block                           #   validate_for_admin *methods, &block
              #{callback_without_tier(default_callback)} *methods, &block                   #   validate_without_tier *methods, &block
            end                                                                             # end
          BLOCK
        end

        @klass.class_eval <<-BLOCK, __FILE__, __LINE__ + 1
          class << self                                                                     # class << self
            alias_method :#{callback_without_tier(default_callback)}, :#{default_callback}  #   alias_method :validate_without_tier, :validate
            alias_method :#{default_callback}, :#{callback_with_tier(default_callback)}     #   alias_method :validate, :validate_with_tier
          end                                                                               # end
        BLOCK
      end
    end
    
    def teardown_alias_methods
      DEFAULT_VALIDATION_CALLBACKS.each do |default_callback|
        @klass.class_eval  <<-BLOCK, __FILE__, __LINE__ + 1
          class << self                                                                     # class << self
            alias_method :#{default_callback}, :#{callback_without_tier(default_callback)}  #   alias_method :validate, :validate_without_tier
                                                                                            #  
            remove_method :#{callback_with_tier(default_callback)}                          #   remove_method :validate_with_tier
            remove_method :#{callback_without_tier(default_callback)}                       #   remove_method :validate_without_tier
          end                                                                               # end
        BLOCK
      end
    end
    
    def add_convenience_methods
      @klass.class_eval <<-BLOCK, __FILE__, __LINE__ + 1
        def self.create_with_#{@name}_validation!(attributes = nil, &block)                 # def self.create_with_admin_validation!(attributes = nil, &block)
          create_with_tier_validation!(:#{@name}, attributes, &block)                       #   create_with_tier_validation!(:admin, attributes, &block)
        end                                                                                 # end
        
        def save_with_#{@name}_validation                                                   # def save_with_admin_validation
          save_with_tier_validation(:#{@name})                                              #   save_with_tier_validation(:admin)
        end                                                                                 # end
        
        def save_with_#{@name}_validation!                                                  # def save_with_admin_validation
          save_with_tier_validation!(:#{@name})                                             #   save_with_tier_validation!(:admin)
        end                                                                                 # end

        def valid_for_#{@name}?                                                             # def valid_for_admin?
          valid_for_tier?(:#{@name})                                                        #   valid_for_tier?(:admin)
        end                                                                                 # end
        
        def invalid_for_#{@name}?                                                           # def invalid_for_admin?
          !valid_for_tier?(:#{@name})                                                       #   !valid_for_tier?(:admin)
        end                                                                                 # end
      BLOCK
    end
    
    protected
      def base_callback_chain(action)
        @base_callback_chains ||= {}
        @base_callback_chains[action] ||= @klass.__send__ callback_chain_name(DEFAULT_ACTION_CALLBACK_MAP[action])
      end

      def callback_name(default_callback)
        "#{default_callback}_for_#{@name}"
      end
      
      def callback_chain_name(default_callback)
        "#{callback_name(default_callback)}_callback_chain"
      end
      
      def callback_with_tier(default_callback)
        "#{default_callback}_with_tier"
      end
      
      def callback_without_tier(default_callback)
        "#{default_callback}_without_tier"
      end
  end
end