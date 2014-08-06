module ActiveMerchant
  module Billing
    class SepaAccount
    	include Validateable

      attr_accessor :first_name, :last_name, :email
      attr_accessor :address_city, :address_country, :address_postal_code, :address_state
      attr_accessor :address_street1, :address_street2
    	attr_accessor :iban, :bic

      def initialize options={}
        self.first_name = options[:first_name].strip     if options[:first_name]
        self.last_name  = options[:last_name].strip      if options[:last_name]
        self.iban       = options[:iban].gsub(/\s+/, "") if options[:iban]
        self.bic        = options[:bic].gsub(/\s+/, "")  if options[:bic]

        # optional fields
        self.email               = options[:email].strip               if options[:email]
        self.address_city        = options[:address_city].strip        if options[:address_city]
        self.address_country     = options[:address_country].strip     if options[:address_country]
        self.address_postal_code = options[:address_postal_code].strip if options[:address_postal_code]
        self.address_state       = options[:address_state].strip       if options[:address_state]
        self.address_street1     = options[:address_street1].strip     if options[:address_street1]
        self.address_street2     = options[:address_street2].strip     if options[:address_street2]
      end

      def validate
        errors.add :first_name, I18n.t('activerecord.errors.messages.empty')   if @first_name.blank?
        errors.add :last_name,  I18n.t('activerecord.errors.messages.empty')   if @last_name.blank?

        errors.add :iban,       I18n.t('activerecord.errors.messages.empty')   if @iban.blank?
        errors.add :bic,        I18n.t('activerecord.errors.messages.empty')   if @bic.blank?

        errors.add :iban,       I18n.t('activerecord.errors.messages.invalid') if @iban !~ /[a-zA-Z]{2}[0-9]{2}[a-zA-Z0-9]{4}[0-9]{7}([a-zA-Z0-9]?){0,16}/
        errors.add :bic,        I18n.t('activerecord.errors.messages.invalid') if @bic !~ /([a-zA-Z]{4}[a-zA-Z]{2}[a-zA-Z0-9]{2}([a-zA-Z0-9]{3})?)/

        if @email
          errors.add :email,    I18n.t('activerecord.errors.messages.invalid') if @email !~ /^[_a-z0-9\!\#\$\%\&\'\*\+\/\=\?\^\`\{\|\}\~]([-\._a-z0-9\!\#\$\%\&\'\*\+\/\=\?\^\`\{\|\}\~])*@([a-z0-9](?:[-a-z0-9]*\.)+[a-z]{2,})$/i 
        end
      end

      def to_s
        @iban
      end
      
      def country 
        @iban.slice(0,2) if @iban
      end

      def has_address_info
        # returns true if at least one of the address-fields is set
        self.address_city or
        self.address_country or
        self.address_postal_code or
        self.address_state or
        self.address_street1 or
        self.address_street2
      end

      def display
        # returns a verbose string-representation of the account
        rep = "SEPA Account:"
        (rep += "\n  first name: #{@first_name}") if @first_name
        (rep += "\n  last name: #{@last_name}") if @last_name
        (rep += "\n  IBAN: #{@iban}") if @iban
        (rep += "\n  BIC: #{@bic}") if @bic
        (rep += "\n  email: #{@email}") if @email
        (rep += "\n  address.city: #{@address_city}") if @address_city
        (rep += "\n  address.country: #{@address_country}") if @address_country
        (rep += "\n  address.postal code: #{@address_postal_code}") if @address_postal_code
        (rep += "\n  address.state: #{@address_state}") if @address_state
        (rep += "\n  address.street1: #{@address_street1}") if @address_street1
        (rep += "\n  address.street2: #{@address_street2}") if @address_street2

        rep
      end
    end
  end
end
