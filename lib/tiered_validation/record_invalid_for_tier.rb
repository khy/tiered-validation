module ActiveRecord
  class RecordInvalidForTier < ActiveRecordError
    attr_reader :record
    def initialize(tier, record)
      @record = record
      super("Validation for #{tier} failed: #{@record.errors.full_messages.join(", ")}")
    end
  end
end