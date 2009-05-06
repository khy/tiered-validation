module TieredValidation
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  module ::ActiveRecord
    class RecordInvalidForTier < ActiveRecordError
      attr_reader :record
      def initialize(tier, record)
        @record = record
        super("Validation for #{tier} failed: #{@record.errors.full_messages.join(", ")}")
      end
    end
  end
  
  module ClassMethods
    def validation_tier(tier, &block)
      save_callback = "validate_for_#{tier}_on_save"
      update_callback = "validate_for_#{tier}_on_update"
      create_callback = "validate_for_#{tier}_on_create"

      define_callbacks save_callback, update_callback, create_callback
      
      class_eval <<-BLOCK, __FILE__, __LINE__ + 1
        def self.validate_on_save_with_tier(*methods, &block)
          #{save_callback} *methods, &block
          validate_on_save_without_tier *methods, &block
        end
        
        def self.validate_on_update_with_tier(*methods, &block)
          #{update_callback} *methods, &block
          validate_on_update_without_tier *methods, &block
        end
        
        def self.validate_on_create_with_tier(*methods, &block)
          #{create_callback} *methods, &block
          validate_on_create_without_tier *methods, &block
        end
        
        def self.create_with_#{tier}_validation!(attributes = nil, &block)
          if attributes.is_a?(Array)
            attributes.collect { |attr| create_with_#{tier}_validation!(attr, &block) }
          else
            object = new(attributes)
            yield(object) if block_given?
            object.save_with_#{tier}_validation!
            object
          end
        end
        
        def save_with_#{tier}_validation
          valid_for_#{tier}? ? save : false
        end
        
        def save_with_#{tier}_validation!
          if valid_for_#{tier}?
            save!
          else
            raise ActiveRecord::RecordInvalidForTier.new(:#{tier}, self)
          end
        end

        def valid_for_#{tier}?
          errors.clear

          run_callbacks(:validate)
          run_callbacks(:#{save_callback})
          validate

          if new_record?
            run_callbacks(:validate_on_create)
            run_callbacks(:#{create_callback})
            validate_on_create
          else
            run_callbacks(:validate_on_update)
            run_callbacks(:#{update_callback})
            validate_on_update
          end

          errors.empty?
        end
        
        def invalid_for_#{tier}?
          !valid_for_#{tier}?
        end
        
        class << self  
          alias_method :validate_on_save_without_tier, :validate
          alias_method :validate, :validate_on_save_with_tier
          
          alias_method :validate_on_update_without_tier, :validate_on_update
          alias_method :validate_on_update, :validate_on_update_with_tier
          
          alias_method :validate_on_create_without_tier, :validate_on_create
          alias_method :validate_on_create, :validate_on_create_with_tier
        end
      BLOCK
      
      class_eval &block
    end
  end
end
