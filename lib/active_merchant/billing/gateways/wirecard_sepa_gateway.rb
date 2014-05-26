module ActiveMerchant
  module Billing
    class WirecardSepaGateway < Gateway
      require 'digest/sha1'

      # Test server location
      TEST_URL = 'https://c3-test.wirecard.com/secure/ssl-gateway'
     
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

      # cancel transaction
      def void
        prepare_options_hash(options)
        @options[:sepa_account] = account
        request = build_request :void, money, options
        commit request
      end

      # send transaction to wirecard for further reference only
      def authorize
        prepare_options_hash(options)
        @options[:sepa_account] = account
        request = build_request :authorize, money, options
        commit request
      end

      # Generates the complete xml-message that gets sent to the gateway
      # ... -> XML-String
      def build_request(action, money, options = {})
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!

        xml.tag! :payment, :xmlns => "http://www.elastic-payments.com/schema/payment" do
          xml.tag! :'merchant-account-id', TEST_MERCHANT_ACCOUNT_ID
          xml.tag! :'request-id', Digest::SHA1.hexdigest(Time.now.to_s)

          add_transaction_data(xml, action, money, options)
        end

        xml.target!
      end

      # adds transaction information to the XML-objec  
      # Builder::XmlMarkup, Symbol, Money, {} -> Builder::XmlMarkup
      #
      # ASSUMES: options contains information about creditor-id and signed-date
      def add_transaction_data(xml, action, money, options={})
        case action
        when :debit
          add_transaction_type xml, 'pending-debit'
          add_requested_amount xml, money, options[:currency]
        
          add_account_details xml, options[:sepa_account]

          add_payment_method xml, "sepadirectdebit"
          add_mandate xml, options[:sepa_account]

          xml.tag! :'creditor-id', "ASD232XSFGNW"
        when :credit
          add_transaction_type xml, 'pending-credit'
          add_requested_amount xml, money, options[:currency]
   
          add_account_details xml, options[:sepa_account]
   
          add_payment_method xml, "sepacredit"
          add_mandate xml, options[:sepa_account]
          
        when :void
          ;
        when :authorize
          ;
        end
      end

      def add_requested_amount xml, money, currency
        xml.tag! :'requested-amount', { :currency => currency }, money
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
            xml.tag! :'mandate-id', Digest::SHA1.hexdigest(account.to_s)
            xml.tag! :'signed-date', Date.today
          end
      end

      def add_account_details xml, account
        xml.tag! :'account-holder' do
          xml.tag! :'first-name', account.first_name
          xml.tag! :'last-name', account.last_name
        end

        xml.tag! :'bank-account' do
          xml.tag! :iban, options[:sepa_account].iban
          xml.tag! :bic, options[:sepa_account].bic
        end
      end

      def parse_response

      end

      def encoded_credentials
        #credentials = [@options[:login], @options[:password]].join(':')
        credentials = [TEST_USER_NAME, TEST_PASSWORD].join(':')
        "Basic " << Base64.encode64(credentials).strip
      end

      def commit(request)
        headers = { 'Content-Type' => 'text/xml',
                    'Authorization' => encoded_credentials }

        response = parse(ssl_post(TEST_URL, request, headers))
        # Pending Status also means Acknowledged (as stated in their specification)
        
        puts response.inspect
        response   
      end
    end
  end
end