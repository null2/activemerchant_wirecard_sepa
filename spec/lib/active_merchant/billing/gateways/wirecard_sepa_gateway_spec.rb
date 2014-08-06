require 'spec_helper'
require 'rexml/document'
require 'digest/sha1'
require 'money'

describe ActiveMerchant::Billing::WirecardSepaGateway do
  before :all do 
    @gateway_options = {
      :login => ActiveMerchant::Billing::WirecardSepaGateway::TEST_LOGIN,
      :password => ActiveMerchant::Billing::WirecardSepaGateway::TEST_PASSWORD,
      :merchant_account_id => ActiveMerchant::Billing::WirecardSepaGateway::TEST_MERCHANT_ACCOUNT_ID,
      :merchant_account_name => ActiveMerchant::Billing::WirecardSepaGateway::TEST_MERCHANT_ACCOUNT_NAME,
      :test => true
    }
    @test_url = ActiveMerchant::Billing::WirecardSepaGateway::TEST_URL
    @money1 = Money.new 1000
    @money2 = Money.new 123    
  end

  describe "XML validation" do
    before :each do
      @schema  = Nokogiri::XML::Schema(File.read(PROJECT_ROOT + "/validation/payment.xsd"))

      @gateway = ActiveMerchant::Billing::WirecardSepaGateway.new @gateway_options

      @account = ActiveMerchant::Billing::SepaAccount.new
      @account.first_name = "Vorname"
      @account.last_name  = "Nachname"
      @account.iban       = "GR1601101250000000012300695"
      @account.bic        = "PBNKDEFF"

      @options = { 
        :sepa_account => @account,
        :request_id   => Digest::SHA1.hexdigest(Time.now.to_s)
      }
    end


    it "should produce valid XML for a pending debit request" do
      @options.update :mandate_id => "the-mandate-id",
        :signed_date => Time.now,
        :creditor_id => "I-Am-Creditoor"

      request = Nokogiri::XML(@gateway.build_request :debit, @money1, @options)
      @schema.validate(request).should be_empty
    end

    it "should produce valid XML for a pending credit request" do
      request = Nokogiri::XML(@gateway.build_request :credit, @money1, @options)
      @schema.validate(request).should be_empty
    end

    it "should produce valid XML for a void pending-debit request" do
      @options.update :parent_transaction_id => "1234567890"
      request = Nokogiri::XML(@gateway.build_request :void_debit, @money2, @options)

      @schema.validate(request).should be_empty
    end

    it "should produce valid XML for a void-pending-credit request" do
      @options.update :parent_transaction_id => "1234567890"
      request = Nokogiri::XML(@gateway.build_request :void_credit, @money1, @options)

      @schema.validate(request).should be_empty
    end

    it "should produce valid XML for an authorization request" do
      request = Nokogiri::XML(@gateway.build_request :authorize, @money2, @options)

      @schema.validate(request).should be_empty
    end

    it "should validate XML with ip address and user email" do
      @options.update :ip_address => "192.168.0.0", :email => "user@test.ir"

      request = Nokogiri::XML(@gateway.build_request :authorize, @money2, @options)
      @schema.validate(request).should be_empty
    end
  end

  describe "XML integration test" do
    before :each do
      @gateway = ActiveMerchant::Billing::WirecardSepaGateway.new @gateway_options

      @account = ActiveMerchant::Billing::SepaAccount.new
      @account.first_name = "Vorname"
      @account.last_name = "Nachname"
      @account.iban = "GR1601101250000000012300695"
      @account.bic = "PBNKDEFF"

      @options = { 
        :sepa_account => @account, 
        :test => true, 
        :request_id => Digest::SHA1.hexdigest(Time.now.to_s),
        :mandate_id => "The-Mandate",
        :signed_date => Date.today,
        :creditor_id => "DE98ZZZ09999999999"
      }

      @headers = { 
        'Content-Type' => 'text/xml',
        'Authorization' => @gateway.encoded_credentials 
      }

    end

    # parser test 1
    it "(parser) should detect xml that has no status-field, i.e. is no valid wirecard-reply" do
      no_reply_xml = '<payment>
                        <transaction-state>success</transaction-state>
                      </payment>'

      parsed_response = @gateway.parse(no_reply_xml)
      parsed_response[:Message].should match "No valid XML response message received. \nPropably wrong credentials supplied with HTTP header."
    end

    # parser test2
    it "(parser) should detect xml that has no transaction-state, i.e. is no valid wirecard-reply" do
      no_reply_xml = '<payment>
                        <statuses>
                          <status code="201.0000" description="The resource was successfully created." severity="information"/>
                        </statuses>
                      </payment>'

      parsed_response = @gateway.parse(no_reply_xml)
      parsed_response[:Message].should match "No valid XML response message received. \nPropably wrong credentials supplied with HTTP header."
    end


    # optional argments test
    it "should create a successful request with optional arguments" do
      @account.email               = "user@test.de"
      @account.address_city        = "Werkstadt"
      @account.address_country     = "HK"
      @account.address_postal_code = "12358"
      @account.address_state       = "state of mind"
      @account.address_street1     = "Kaputte Strasse 15"

      @options.update :request_id => rand(9999999999999999999)
      request = @gateway.build_request :debit, @money1, @options

      puts request

      response = @gateway.parse(@gateway.ssl_post(@test_url, request, @headers))

      response[:TransactionState].should match /^success$/
    end



    # debit (success)
    it "should receive the success-response for a correct debit request" do
      # send request and catch response
      @options.update :request_id => rand(9999999999999999999)
      request = @gateway.build_request :debit, @money1, @options
      response = @gateway.parse(@gateway.ssl_post(@test_url, request, @headers))

      # check response


      response[:TransactionState].should match /^success$/
      response[:Code].should match /^201.0000$/
      response[:Description].should match /^The resource was successfully created.$/
      response[:Severity].should match /^information$/
      response[:TransactionId].should_not be_nil
      response[:RequestId].should_not be_nil
    end

    # debit (failed)
    it "should receive a failure-response for a debit request with missing account holder info" do
      
      # invalidate request
      @options[:sepa_account].first_name = ""
      @options[:sepa_account].last_name = ""

      # send request and catch response
      request = @gateway.build_request :debit, @money2, @options
      response = @gateway.parse(@gateway.ssl_post(@test_url, request, @headers))

      # check response
      response[:TransactionState].should match /^failed$/
      response[:Code].should match /^400./ 
      # Note: slightly different error message than given in the spec (p. 74)
      response[:Severity].should match /^error$/
    end
    
    # authorization (success)
    it "should receive the success-response for a correct authorization request" do

      # send valid request and catch response
      request = @gateway.build_request :authorize, @money1, @options
      response = @gateway.parse(@gateway.ssl_post(@test_url, request, @headers))

      # check response
      response[:TransactionState].should match /^success$/
      response[:Code].should match /^201.0000$/
      response[:Description].should match /^The resource was successfully created.$/
      response[:Severity].should match /^information$/
    end

    # authorization (failed)
    it "should receive the failure-response for an authorization request WITH reference-id" do

      # add provider-transaction-reference-id to the request (forbidden)
      request = @gateway.build_request :authorize, @money2, @options
      request = request.insert(-12, "  <provider-transaction-reference-id>68E34C9581</provider-transaction-reference-id>\n") 
      response = @gateway.parse(@gateway.ssl_post(@test_url, request, @headers))

      # check response
      response[:TransactionState].should match /^failed$/
      response[:Code].should match /^400.1031/
      # Note: specification (p. 83) reports a different error (missing iban) - but one that does not make sense here
      #       server replies with a "syntax error, 400.1031"
      response[:Severity].should match /^error$/
    end

    # credit (success)
    it "should receive the success-response for a correct credit request" do
      
      # send valid request and catch response
      @options.update :request_id => rand(999999999999)
      request = @gateway.build_request :credit, @money1, @options
      response = @gateway.parse(@gateway.ssl_post(@test_url, request, @headers))

      # check response
      response[:TransactionState].should match /^success$/
      response[:Code].should match /^201.0000$/
      response[:Description].should match /^The resource was successfully created.$/
      response[:Severity].should match /^information$/
    end

    # credit (failed)
    it "should receive the failure-response for a credit request with missing IBAN" do

      # invalidate request
      @options[:sepa_account].iban = ""

      # send request and catch response
      request = @gateway.build_request :credit, @money2, @options
      response = @gateway.parse(@gateway.ssl_post(@test_url, request, @headers))

      # check response
      response[:TransactionState].should match /^failed$/
      response[:Code].should match /^400.1081/
      response[:Description].should match /The Bank Account IBAN information has not been provided.  Please check your input and try again./
      response[:Severity].should match /^error$/
    end

    # void-debit (success)
    it "should receive the success-response for a correct void-debit request" do
      # create a parent transaction, because parent-transaction-id will be needed
      request = @gateway.build_request :debit, @money1, @options
      unparsed_response = @gateway.ssl_post(@test_url, request, @headers)

      xml = REXML::Document.new unparsed_response
      parent_id = REXML::XPath.first(xml, "//transaction-id").text

      @options.update :parent_transaction_id => parent_id, 
        :request_id => Digest::SHA1.hexdigest(rand(99999999999999).to_s)

      # insert current parent-transaction-id
      request = @gateway.build_request :void_debit, @money1, @options
      request.gsub!(%r{<parent-transaction-id>.*</parent-transaction-id>}, 
                    "<parent-transaction-id>#{parent_id}</parent-transaction-id>")

      response = @gateway.parse(@gateway.ssl_post(@test_url, request, @headers))

      # check response
      response[:TransactionState].should match /^success$/
      response[:Code].should match /^200.0000$/
      response[:Description].should match /^The request completed successfully/
      response[:Severity].should match /^information$/
    end

    # void-debit (failed)
    it "should receive the failure-response for a void-debit request without parent-transaction-id" do
      
      # invalidate request
      @options.update :parent_transaction_id => '',
        :request_id => Digest::SHA1.hexdigest(rand(9999999999999).to_s)

      request = @gateway.build_request :void_debit, @money2, @options
      request.gsub!(%r{\n  <parent-transaction-id>.*</parent-transaction-id>}, '')
      
      response = @gateway.parse(@gateway.ssl_post(@test_url, request, @headers))
      
      # check response
      response[:TransactionState].should match /^failed$/
      response[:Code].should match /^400.1021$/
      response[:Description].should match "The Parent Transaction Id is required, and not provided.  Please check your input and try again"
      response[:Severity].should match /^error$/
    end

    # void-credit (success)
    it "should receive the success-response for a correct void-credit request" do

      # create a parent transaction, because parent-transaction-id will be needed
      request = @gateway.build_request :credit, @money2, @options
      unparsed_response = @gateway.ssl_post(@test_url, request, @headers)

      xml = REXML::Document.new unparsed_response
      parent_id = REXML::XPath.first(xml, "//transaction-id").text

      @options.update :parent_transaction_id => parent_id,
        :request_id => Digest::SHA1.hexdigest(rand(9999999999999).to_s)

      # insert current parent-transaction-id
      request = @gateway.build_request :void_credit, @money2, @options
      request.gsub!(%r{<parent-transaction-id>.+</parent-transaction-id>}, 
                    "<parent-transaction-id>#{parent_id}</parent-transaction-id>")

      response = @gateway.parse(@gateway.ssl_post(@test_url, request, @headers))

      # check response
      response[:TransactionState].should match /^success$/
      response[:Code].should match /^200.0000$/
      response[:Description].should match /^The request completed successfully/
      response[:Severity].should match /^information$/
    end

    # void-credit (failed)
    it "should receive the failure-response for a void-credit request with missing parent-transaction-id" do

      # invalidate request
      @options.update :parent_transaction_id => "",
        :request_id => Digest::SHA1.hexdigest(rand(9999999999999).to_s)
        
      request = @gateway.build_request :void_credit, @money1, @options
      request.gsub!(%r{\n  <parent-transaction-id>.*</parent-transaction-id>}, '')
      response = @gateway.parse(@gateway.ssl_post(@test_url, request, @headers))

      # check response
      response[:TransactionState].should match /^failed$/
      response[:Code].should match /^400.1021$/
      response[:Description].should match "The Parent Transaction Id is required, and not provided.  Please check your input and try again"
      response[:Severity].should match /^error$/
    end

    # Response object
    it "should return a valid Response object for a valid request" do

      response = @gateway.debit @money1, @account, :request_id => Digest::SHA1.hexdigest(rand(99999999999).to_s), 
        :mandate_id => "hoolahoop",
        :signed_date => Date.today,
        :creditor_id => "DE98ZZZ09999999999"

      response.success?.should be_true
    end
  end

  describe "exception handling" do

    before :each do
      @gateway = ActiveMerchant::Billing::WirecardSepaGateway.new @gateway_options

      @account = ActiveMerchant::Billing::SepaAccount.new
      @account.first_name = "hasf"
      @account.last_name  = "slkdjfdsk"
      @account.iban       = "GR1601101250000000012300695"
      @account.bic        = "PBNKDEFF"

      @options = { 
        :sepa_account => @account, 
        :test         => true, 
        :request_id   => Digest::SHA1.hexdigest(Time.now.to_s),
        :mandate_id   => "The-Mandate",
        :signed_date  => Date.today,
        :creditor_id  => "DE98ZZZ09999999999"
      }

      @headers = { 
        'Content-Type'  => 'text/xml',
        'Authorization' => @gateway.encoded_credentials 
      }
    end

    it "should report an invalid action specification" do
      expect { 
        @gateway.build_request(@money1, @options)
        }.to raise_error(ActiveMerchant::Billing::MalformedException, "action specification is invalid")
    end

    it "should report a missing merchant account id" do
      gateway_options = {
        :login                 => ActiveMerchant::Billing::WirecardSepaGateway::TEST_LOGIN,
        :password              => ActiveMerchant::Billing::WirecardSepaGateway::TEST_PASSWORD,
        :merchant_account_id   => nil,
        :merchant_account_name => ActiveMerchant::Billing::WirecardSepaGateway::TEST_MERCHANT_ACCOUNT_NAME,
        :test                  => true
      }

      test_url = ActiveMerchant::Billing::WirecardSepaGateway::TEST_URL
      gateway = ActiveMerchant::Billing::WirecardSepaGateway.new gateway_options
      
      expect { 
        gateway.build_request(:debit, @money1, @options)
        }.to raise_error(ActiveMerchant::Billing::MalformedException, "merchant account id must be supplied")
    end

    it "should report a missing requested amount" do
      expect { 
        @gateway.build_request(:debit, @options)
        }.to raise_error(ActiveMerchant::Billing::MalformedException, "requested amount specification is invalid")
    end

    it "should report a missing mandate id"  do
      @options.update :mandate_id => nil
      expect { 
        @gateway.build_request(:debit, @money2, @options)
        }.to raise_error(ActiveMerchant::Billing::MalformedException, "mandate id must be supplied")
    end

    it "should report a missing signed date"  do
      @options.update :signed_date => nil
      expect { 
        @gateway.build_request(:debit, @money1, @options)
        }.to raise_error(ActiveMerchant::Billing::MalformedException, "signed date must be supplied")
    end

    it "should report a missing request id" do
      @options.update :request_id => nil
      expect { 
        @gateway.build_request(:debit, @money2, @options)
        }.to raise_error(ActiveMerchant::Billing::MalformedException, "request id must be supplied")
    end

    it "should report a missing creditor id" do
      @options.update :creditor_id => nil
      expect { 
        @gateway.build_request(:debit, @money1, @options)
        }.to raise_error(ActiveMerchant::Billing::MalformedException, "creditor id must be supplied")
    end

    it "should report a missing first name" do
      @account.first_name = nil
      expect { 
        @gateway.build_request(:debit, @money2, @options)
        }.to raise_error(ActiveMerchant::Billing::MalformedException, "first name must be supplied")
    end

    it "should report a missing last name" do
      @account.last_name = nil
      expect { 
        @gateway.build_request(:debit, @money1, @options)
        }.to raise_error(ActiveMerchant::Billing::MalformedException, "last name must be supplied")
    end

    it "should report a missing iban" do
      @account.iban = nil
      expect { 
        @gateway.build_request(:debit, @money2, @options)
        }.to raise_error(ActiveMerchant::Billing::MalformedException, "iban must be supplied")
    end

    it "should report a missing bic" do
      @account.bic = nil
      expect { 
        @gateway.build_request(:debit, @money1, @options)
        }.to raise_error(ActiveMerchant::Billing::MalformedException, "bic must be supplied")
    end

    it "should report a malformed ip-address" do
      @options.update :ip_address => "abc"
      expect { 
        @gateway.build_request(:debit, @money1, @options)
        }.to raise_error(ActiveMerchant::Billing::MalformedException, "provided ip-address is invalid")
    end
  end
end







