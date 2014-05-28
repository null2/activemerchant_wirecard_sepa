module ActiveMerchant
  module Billing
    class WirecardSepaGateway < Gateway
      require 'digest/sha1'

      # Test server location
      TEST_URL = 'https://api-test.wirecard.com/engine/rest/paymentmethods/'
     
      # Live server location
      LIVE_URL = 'https://c3.wirecard.com/secure/ssl-gateway'


      TEST_MERCHANT_ACCOUNT_ID = "4c901196-eff7-411e-82a3-5ef6b6860d64"
      TEST_MERCHANT_ACCOUNT_NAME = "WD SEPA Test"
      TEST_USER_NAME = "70000-APITEST-AP"
      TEST_PASSWORD = "qD2wzQ_hrc!8"

      # charge money from account
      def debit(money, account, options = {})
        prepare_options_hash(options)
        @options[:sepa_account] = account
        request = build_request :debit, money, options
        commit request
      end

      # credit money to account
      def credit(money, account, options = {})
        prepare_options_hash(options)
        @options[:sepa_account] = account        
        request = build_request :credit, money, options
        commit request
      end

      # cancel debit transaction
      def void_debit(money, account, options = {})
        prepare_options_hash(options)
        @options[:sepa_account] = account
        request = build_request :void_debit, money, options
        commit request
      end

      # cancel credit transaction
      def void_credit(money, account, options = {})
        prepare_options_hash(options)
        @options[:sepa_account] = account
        request = build_request :void_credit, money, options
        commit request
      end

      # send transaction to wirecard for further reference only
      def authorize(money, account, options = {})
        prepare_options_hash(options)
        @options[:sepa_account] = account
        request = build_request :authorize, money, options
        commit request
      end

      # Generates the complete xml-message that gets sent to the gateway
      # Symbol, Integer, {} -> XML-String
      def build_request(action, money, options = {})
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct! :xml, :encoding => "UTF-8", :standalone => "yes"

        xml.tag! :payment, :xmlns => "http://www.elastic-payments.com/schema/payment" do
          xml.tag! :'merchant-account-id', TEST_MERCHANT_ACCOUNT_ID
          xml.tag! :'request-id', Digest::SHA1.hexdigest(Time.now.to_s)

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
            :mandate => options[:sepa_account],
            :creditor_id => "ASD232XSFGNW"

        when :credit
          apply_properties xml, :transaction_type => 'pending-credit',
            :requested_amount => money,
            :account_holder => options[:sepa_account],
            :payment_method => "sepacredit",
            :bank_account => options[:sepa_account]

        when :void_debit
          apply_properties xml, :transaction_type => 'void-debit',
            :requested_amount => money,
            :parent_transaction_id  => '3f8e01bc-9203-11e2-abbd-005056a96a54',
            :payment_method => "sepadirectdebit"
        
        when :void_credit
          apply_properties xml, :transaction_type => 'void-credit',
            :requested_amount => money,
            :parent_transaction_id  => '3f8e01bc-9203-11e2-abbd-005056a96a54',
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
        xml.tag! :'parent-transaction-id', id
      end

      def add_creditor_id xml, id
        xml.tag! :'creditor-id', id
      end

      def add_parent_transaction_id xml, id
        xml.tag! :'parent-transaction-id', id
      end

      def add_requested_amount xml, money
        xml.tag! :'requested-amount', { :currency => "EUR" }, money
      end

      def add_transaction_type xml, type
        xml.tag! :'transaction-type', type
      end

      def add_payment_method xml, method
        xml.tag! :'payment-methods' do
          xml.tag! :'payment-method', :name => method
        end
      end

      def add_mandate xml, account
          xml.tag! :mandate do
            xml.tag! :'mandate-id', 12345678 #Digest::SHA1.hexdigest(account.to_s)
            xml.tag! :'signed-date', Date.new(2013,9,24)
          end
      end

      def add_account_holder xml, account
        xml.tag! :'account-holder' do
          xml.tag! :'first-name', account.first_name
          xml.tag! :'last-name', account.last_name
        end
      end

      def add_bank_account xml, account
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
        transaction_state = REXML::XPath.first(xml, "//transaction-state")
        
        if status and transaction_state and transaction_state.text

          # either extract response values...
          response[:TransactionState] = transaction_state.text
          response[:Code] = status.attributes["code"]
          response[:Description] = status.attributes["description"]
          response[:Severity] = status.attributes["severity"]

        else
          # ...or add general failure message
          response[:Message] = "No valid XML response message received. \nPropably wrong credentials supplied with HTTP header."
        end

        response
      end

      def encoded_credentials
        #credentials = [@options[:login], @options[:password]].join(':')
        credentials = [TEST_USER_NAME, TEST_PASSWORD].join(':')
        "Basic " << Base64.encode64(credentials).strip
      end

      # Contact WireCard, make the XML request 
      def commit(request)
        headers = { 'Content-Type' => 'text/xml',
                    'Authorization' => encoded_credentials }

        response = parse(ssl_post(TEST_URL, request, headers))
        
        # TODO ?: parse the reply into a Response object
        success = response[:TransactionState] == 'success'
        
        response
        
      end
    end
  end
end




