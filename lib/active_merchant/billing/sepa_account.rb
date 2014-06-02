module ActiveMerchant
  module Billing
    class SepaAccount
    	include Validateable

      attr_accessor :first_name, :last_name
    	attr_accessor :iban, :bic

      def initialize options={}
        self.first_name = options[:first_name]
        self.last_name = options[:last_name]
        self.iban = options[:iban]
        self.bic = options[:bic]
      end

    	def validate
        errors.add :first_name, 'activerecord.errors.messages.empty'      if @first_name.blank?
        errors.add :last_name,  'activerecord.errors.messages.empty'      if @last_name.blank?

        errors.add :iban, 'activerecord.errors.messages.empty'      if @iban.blank?
        errors.add :bic,  'activerecord.errors.messages.empty'      if @bic.blank?

        errors.add :iban, 'activerecord.errors.messages.invalid'    if @iban !~ /[a-zA-Z]{2}[0-9]{2}[a-zA-Z0-9]{4}[0-9]{7}([a-zA-Z0-9]?){0,16}/
        errors.add :bic, 'activerecord.errors.messages.invalid'    if @bic !~ /([a-zA-Z]{4}[a-zA-Z]{2}[a-zA-Z0-9]{2}([a-zA-Z0-9]{3})?)/
      end

      def to_s
        @iban
      end
    end
  end
end
