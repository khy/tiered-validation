module TieredValidation
  class ValidationTier
    DEFAULT_ACTION_VALIDATION_MAP = {
      :save => :validate,
      :update => :validate_on_update,
      :create => :validate_on_create
    }.freeze

    DEFAULT_VALIDATIONS = DEFAULT_ACTION_VALIDATION_MAP.values.freeze
    
    def self.for(name, klass, includes = [], exclusive = true)
      if uses_callbacks?(klass)
        tier_class = ValidationTierWithCallbacks
      else
      end
      
      tier_class.new(name, klass, includes, exclusive)
    end

    def initialize(name, klass, includes = [], exclusive = true)
      @name = name
      @klass = klass
      @included_tiers = includes.is_a?(Array) ? includes : [includes].compact
      @exclusive = exclusive
      define_validation_chains
    end

    def run_callbacks
    end

    def setup_alias_methods
      DEFAULT_VALIDATIONS.each do |default_callback|
        if @exclusive
          # def self.validate_with_tier(*methods, &block)
          #   validate_for_admin *methods, &block
          # end
          @klass.class_eval <<-BLOCK, __FILE__, __LINE__ + 1                                
            def self.#{validation_with_tier_name(default_callback)}(*methods, &block)         
              #{validation_name(default_callback)} *methods, &block
            end
          BLOCK
        else
          # def self.validate_with_tier(*methods, &block)
          #   validate_for_admin *methods, &block
          #   validate_without_tier *methods, &block
          # end
          @klass.class_eval <<-BLOCK, __FILE__, __LINE__ + 1
            def self.#{validation_with_tier_name(default_callback)}(*methods, &block)   
              #{validation_name(default_callback)} *methods, &block
              #{validation_without_tier_name(default_callback)} *methods, &block
            end
          BLOCK
        end
        
        # class << self
        #   alias_method :validate_without_tier, :validate
        #   alias_method :validate, :validate_with_tier
        # end
        @klass.class_eval <<-BLOCK, __FILE__, __LINE__ + 1
          class << self                                                                     
            alias_method :#{validation_without_tier_name(default_callback)}, :#{default_callback} 
            alias_method :#{default_callback}, :#{validation_with_tier_name(default_callback)}
          end
        BLOCK
      end
    end
    
    def teardown_alias_methods
      DEFAULT_VALIDATIONS.each do |default_callback|
        # class << self
        #   alias_method :validate, :validate_without_tier
        #
        #   remove_method :validate_with_tier
        #   remove_method :validate_without_tier
        # end
        @klass.class_eval  <<-BLOCK, __FILE__, __LINE__ + 1
          class << self                                                                     
            alias_method :#{default_callback}, :#{validation_without_tier_name(default_callback)}

            remove_method :#{validation_with_tier_name(default_callback)}
            remove_method :#{validation_without_tier_name(default_callback)}
          end
        BLOCK
      end
    end
    
    def add_convenience_methods
      # def self.create_with_admin_validation!(attributes = nil, &block)
      #   create_with_tier_validation!(:admin, attributes, &block)
      # end
      #
      # def save_with_admin_validation
      #   save_with_tier_validation(:admin)
      # end
      #
      # def save_with_admin_validation
      #   save_with_tier_validation!(:admin)
      # end
      #
      # def valid_for_admin?
      #   valid_for_tier?(:admin)
      # end
      #
      # def invalid_for_admin?
      #   !valid_for_tier?(:admin)
      # end
      @klass.class_eval <<-BLOCK, __FILE__, __LINE__ + 1
        def self.create_with_#{@name}_validation!(attributes = nil, &block)
          create_with_tier_validation!(:#{@name}, attributes, &block)
        end

        def save_with_#{@name}_validation
          save_with_tier_validation(:#{@name})
        end

        def save_with_#{@name}_validation!
          save_with_tier_validation!(:#{@name})
        end

        def valid_for_#{@name}?                                                             
          valid_for_tier?(:#{@name})
        end

        def invalid_for_#{@name}?                                                           
          !valid_for_tier?(:#{@name})
        end
      BLOCK
    end
    
    protected
      def define_validation_chains
      end
      
      def validation_name(default_callback)
        "#{default_callback}_for_#{@name}"
      end
      
      def validation_with_tier_name(default_callback)
        "#{default_callback}_with_tier"
      end
      
      def validation_without_tier_name(default_callback)
        "#{default_callback}_without_tier"
      end
    
    private
      def self.uses_callbacks?(klass)
        true
      end
  end
end