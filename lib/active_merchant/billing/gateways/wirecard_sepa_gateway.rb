module ActiveMerchant
  module Billing
    class MalformedException < StandardError
    end

    class WirecardSepaGateway < Gateway
      require 'digest/sha1'

      def initialize(options = {})
        # verify that username and password are supplied
        requires!(options, :login, :password)
        requires!(options, :merchant_account_id)
        @options = options
        super
      end

      # Test server location
      TEST_URL = 'https://api-test.wirecard.com/engine/rest/paymentmethods/'
     
      # Live server location
      LIVE_URL = 'https://c3.wirecard.com/secure/ssl-gateway'

      TEST_MERCHANT_ACCOUNT_ID = "4c901196-eff7-411e-82a3-5ef6b6860d64"
      TEST_MERCHANT_ACCOUNT_NAME = "WD SEPA Test"
      TEST_LOGIN = "70000-APITEST-AP"
      TEST_PASSWORD = "qD2wzQ_hrc!8"

      #########
      #  API  #
      #########

      # define following methods for each transaction type
      # all methods are passed 3 arguments:
      #   + money (decimal)
      #   + account object
      #   + options hash

      [:debit, :credit, :void_debit, :void_credit, :authorize].each do |type|
        define_method type, lambda { |money, account, options|
          requires!(options, :request_id)
          prepare_options_hash(options)
          @options[:sepa_account] = account
          request = build_request type, money, @options
          commit request
        }
      end

      ###########
      # helpers #
      ###########

      # Generates the complete xml-message that gets sent to the gateway
      # Symbol, Integer, {} -> XML-String
      def build_request(action, money, options = {})
        raise ActiveMerchant::Billing::MalformedException, "action specification is invalid" unless action.class == :a.class
        raise ActiveMerchant::Billing::MalformedException, "requested amount specification is invalid" unless money.class == 1.class or money.class == 1.0.class
        
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct! :xml, :encoding => "UTF-8", :standalone => "yes"

        xml.tag! :payment, :xmlns => "http://www.elastic-payments.com/schema/payment" do
          raise ActiveMerchant::Billing::MalformedException, "merchant account id must be supplied" unless @options[:merchant_account_id]
          raise ActiveMerchant::Billing::MalformedException, "request id must be supplied" unless options[:request_id]

          xml.tag! :'merchant-account-id', @options[:merchant_account_id]
          xml.tag! :'request-id', options[:request_id]

          add_transaction_data(xml, action, money, options)
        end

        xml.target!
      end

      # append information to the xml using function calls
      def apply_properties xml, props={}
        props.inject(xml) do |memo, item|
          self.send("add_%s" % item.first, memo, item.last)  
          memo
        end
      end

      # adds transaction information to the XML-objec  
      # Builder::XmlMarkup, Symbol, Money, {} -> Builder::XmlMarkup
      #
      # ASSUMES: options contains information about creditor-id and signed-date,
      #          parent-transaction-id
      def add_transaction_data(xml, action, money, options={})
        # add_requested_amount xml, money, options[:currency]

        case action
        when :debit
          apply_properties xml, :transaction_type => 'pending-debit',
            :requested_amount => money,
            :account_holder => options[:sepa_account],
            :payment_method => "sepadirectdebit", 
            :bank_account => options[:sepa_account],
            :mandate => options,
            :creditor_id => options[:creditor_id]

        when :credit
          apply_properties xml, :transaction_type => 'pending-credit',
            :requested_amount => money,
            :account_holder => options[:sepa_account],
            :payment_method => "sepacredit",
            :bank_account => options[:sepa_account]

        when :void_debit
          apply_properties xml, :transaction_type => 'void-debit',
            :requested_amount => money,
            :parent_transaction_id  => options[:parent_transaction_id],
            :payment_method => "sepadirectdebit"
        
        when :void_credit
          apply_properties xml, :transaction_type => 'void-credit',
            :requested_amount => money,
            :parent_transaction_id  => options[:parent_transaction_id],
            :payment_method => 'sepacredit'

        when :authorize
           apply_properties xml, :transaction_type => 'authorization',
             :requested_amount => money,
             :account_holder => options[:sepa_account],
             :payment_method => 'sepadirectdebit',
             :bank_account => options[:sepa_account]
        end
      end

      # helper methods for XML-generation
      def add_parent_transaction_id xml, id
        raise ActiveMerchant::Billing::MalformedException, "parent transaction id must be supplied" unless id
        xml.tag! :'parent-transaction-id', id
      end

      def add_creditor_id xml, id
        raise ActiveMerchant::Billing::MalformedException, "creditor id must be supplied" unless id
        xml.tag! :'creditor-id', id
      end

      def add_requested_amount xml, money
        raise ActiveMerchant::Billing::MalformedException "requested amount must be supplied" unless money
        xml.tag! :'requested-amount', { :currency => "EUR" }, money
      end

      def add_transaction_type xml, type
        raise ActiveMerchant::Billing::MalformedException, "transaction type must be supplied" unless type
        xml.tag! :'transaction-type', type
      end

      def add_payment_method xml, method
        xml.tag! :'payment-methods' do
          raise ActiveMerchant::Billing::MalformedException, "payment method must be supplied" unless method
          xml.tag! :'payment-method', :name => method
        end
      end

      def add_mandate xml, options
        raise ActiveMerchant::Billing::MalformedException, "mandate id must be supplied" unless options[:mandate_id]
        raise ActiveMerchant::Billing::MalformedException, "signed date must be supplied" unless options[:signed_date]

        xml.tag! :mandate do
          xml.tag! :'mandate-id', options[:mandate_id]
          xml.tag! :'signed-date', options[:signed_date]
        end
      end

      def add_account_holder xml, account
        raise ActiveMerchant::Billing::MalformedException, "first name must be supplied" unless account.first_name
        raise ActiveMerchant::Billing::MalformedException, "last name must be supplied" unless account.last_name

        xml.tag! :'account-holder' do
          xml.tag! :'first-name', account.first_name
          xml.tag! :'last-name', account.last_name
        end
      end

      def add_bank_account xml, account
        raise ActiveMerchant::Billing::MalformedException, "iban must be supplied" unless account.iban
        raise ActiveMerchant::Billing::MalformedException, "bic must be supplied" unless account.bic

        xml.tag! :'bank-account' do
          xml.tag! :iban, account.iban
          xml.tag! :bic, account.bic
        end
      end

      # Read XML message from the gateway if successful and extract required return values
      # String -> Hash of (Symbol => String)
      def parse(xml)
        response = {}

        xml = REXML::Document.new xml 

        # every Wirecard-Response, success or failure, must have a status and transaction-state
        status = REXML::XPath.first(xml, "//status")
        transaction_id = REXML::XPath.first(xml, "//transaction-id")
        request_id = REXML::XPath.first(xml, "//request-id")
        transaction_state = REXML::XPath.first(xml, "//transaction-state")
        
        if status and transaction_state and transaction_state.text

          # either extract response values...
          response[:TransactionState] = transaction_state.text
          response[:Code] = status.attributes["code"]
          response[:Description] = status.attributes["description"]
          response[:Severity] = status.attributes["severity"]
          response[:GuWID] = transaction_id.text if transaction_id
          response[:RequestId] = request_id.text if request_id

        else
          # ...or add general failure message
          response[:Message] = "No valid XML response message received. \nPropably wrong credentials supplied with HTTP header."
        end

        response
      end

      # Should run against the test servers or not?
      def test?
        @options[:test] || super
      end

      def encoded_credentials
        credentials = [@options[:login], @options[:password]].join(':')
        "Basic " << Base64.encode64(credentials).strip
      end

      # Contact WireCard, make the XML request 
      def commit(request)
        headers = { 'Content-Type' => 'text/xml',
                    'Authorization' => encoded_credentials }

        response = parse(ssl_post(test? ? TEST_URL : LIVE_URL, request, headers))
        
        # parse the reply into a Response object
        success = response[:TransactionState] == 'success'
        message = response[:Description]
        authorization = (success && @options[:action] == :authorization) ? response[:GuWID] : nil

        Response.new(success, message, response,
          :test => test?,
          :authorization => authorization
        )
      
      end

      def prepare_options_hash(options)
        @options.update(options)
        #setup_address_hash!(options)
      end

    end
  end
end