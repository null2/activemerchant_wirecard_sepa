require 'spec_helper'
require 'rexml/document'

describe ActiveMerchant::Billing::WirecardSepaGateway do
  describe "XML validation" do
    before :each do
      @schema = Nokogiri::XML::Schema(File.read(PROJECT_ROOT + "/validation/payment.xsd"))

      @gateway = ActiveMerchant::Billing::WirecardSepaGateway.new

      @account = ActiveMerchant::Billing::SepaAccount.new
      @account.first_name = "Vorname"
      @account.last_name = "Nachname"
      @account.iban = "GR1601101250000000012300695"
      @account.bic = "PBNKDEFF"

      @options = { :sepa_account => @account }
    end

    it "should produce valid XML for a pending debit request" do
      request = Nokogiri::XML(@gateway.build_request :debit, 100.0, @options)
      @schema.validate(request).should be_empty
    end

    it "should produce valid XML for a pending credit request" do
      request = Nokogiri::XML(@gateway.build_request :credit, 100.0, @options)
      @schema.validate(request).should be_empty
    end

    it "should produce valid XML for a void pending-debit request" do
      request = Nokogiri::XML(@gateway.build_request :void_debit, 100.0, @options)

      @schema.validate(request).each do |error|
        puts error.message
      end  

      @schema.validate(request).should be_empty
    end

    it "should produce valid XML for a void-pending-credit request" do
      request = Nokogiri::XML(@gateway.build_request :void_credit, 100.0, @options)

      @schema.validate(request).each do |error|
        puts error.message
      end

      @schema.validate(request).should be_empty
    end

    it "should produce valid XML for an authorization request" do
      request = Nokogiri::XML(@gateway.build_request :authorize, 100.0, @options)

      @schema.validate(request).should be_empty
    end
  end

  describe "XML integration test" do
    before :each do
      @gateway = ActiveMerchant::Billing::WirecardSepaGateway.new

      @account = ActiveMerchant::Billing::SepaAccount.new
      @account.first_name = "hasf"
      @account.last_name = "slkdjfdsk"
      @account.iban = "GR1601101250000000012300695"
      @account.bic = "PBNKDEFF"

      @options = { :sepa_account => @account }

      @headers = { 'Content-Type' => 'text/xml',
                    'Authorization' => @gateway.encoded_credentials }
      @TEST_URL = 'https://api-test.wirecard.com/engine/rest/paymentmethods/'

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

    # debit (success)
    it "should receive the success-response for a correct debit request" do

      # send request and catch response
      request = @gateway.build_request :debit, 100.0, @options
      response = @gateway.parse(@gateway.ssl_post(@TEST_URL, request, @headers))

      # check response
      response[:TransactionState].should match /^success$/
      response[:Code].should match /^201.0000$/
      response[:Description].should match /^The resource was successfully created.$/
      response[:Severity].should match /^information$/
    end

    # debit (failed)
    it "should receive a failure-response for a debit request with missing account holder info" do
      
      # invalidate request
      @options[:sepa_account].first_name = nil
      @options[:sepa_account].last_name = nil

      # send request and catch response
      request = @gateway.build_request :debit, 100.0, @options
      response = @gateway.parse(@gateway.ssl_post(@TEST_URL, request, @headers))

      # check response
      response[:TransactionState].should match /^failed$/
      response[:Code].should match /^400./ 
      # Note: slightly different error message than given in the spec (p. 74)
      response[:Severity].should match /^error$/
    end
    
    # authorization (success)
    it "should receive the success-response for a correct authorization request" do

      # send valid request and catch response
      request = @gateway.build_request :authorize, 100.0, @options
      response = @gateway.parse(@gateway.ssl_post(@TEST_URL, request, @headers))

      # check response
      response[:TransactionState].should match /^success$/
      response[:Code].should match /^201.0000$/
      response[:Description].should match /^The resource was successfully created.$/
      response[:Severity].should match /^information$/
    end

    # authorization (failed)
    it "should receive the failure-response for an authorization request WITH reference-id" do

      # add provider-transaction-reference-id to the request (forbidden)
      request = @gateway.build_request :authorize, 100.0, @options
      request = request.insert(-12, "  <provider-transaction-reference-id>68E34C9581</provider-transaction-reference-id>\n") 
      response = @gateway.parse(@gateway.ssl_post(@TEST_URL, request, @headers))

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
      request = @gateway.build_request :credit, 100.0, @options
      response = @gateway.parse(@gateway.ssl_post(@TEST_URL, request, @headers))

      # check response
      response[:TransactionState].should match /^success$/
      response[:Code].should match /^201.0000$/
      response[:Description].should match /^The resource was successfully created.$/
      response[:Severity].should match /^information$/
    end

    # credit (failed)
    it "should receive the failure-response for a credit request with missing IBAN" do

      # invalidate request
      @options[:sepa_account].iban = nil

      # send request and catch response
      request = @gateway.build_request :credit, 100.0, @options
      response = @gateway.parse(@gateway.ssl_post(@TEST_URL, request, @headers))


      # check response
      response[:TransactionState].should match /^failed$/
      response[:Code].should match /^400.1081/
      response[:Description].should match /The Bank Account IBAN information has not been provided.  Please check your input and try again./
      response[:Severity].should match /^error$/
    end

    # void-debit (success)
    it "should receive the success-response for a correct void-debit request" do

      # create a parent transaction, because parent-transaction-id will be needed
      request = @gateway.build_request :debit, 101.0, @options
      unparsed_response = @gateway.ssl_post(@TEST_URL, request, @headers)

      xml = REXML::Document.new unparsed_response
      parent_id = REXML::XPath.first(xml, "//transaction-id").text

      # insert current parent-transaction-id
      request = @gateway.build_request :void_debit, 101.0, @options
      request.gsub!(%r{<parent-transaction-id>.+</parent-transaction-id>}, 
                    "<parent-transaction-id>#{parent_id}</parent-transaction-id>")

      response = @gateway.parse(@gateway.ssl_post(@TEST_URL, request, @headers))
      
      # check response
      response[:TransactionState].should match /^success$/
      response[:Code].should match /^200.0000$/
      response[:Description].should match /^The request completed successfully/
      response[:Severity].should match /^information$/
    end

    # void-debit (failed)
    it "should receive the failure-response for a void-debit request without parent-transaction-id" do
      
      # invalidate request
      request = @gateway.build_request :void_debit, 100.0, @options
      request.gsub!(%r{\n  <parent-transaction-id>.+</parent-transaction-id>}, '')

      response = @gateway.parse(@gateway.ssl_post(@TEST_URL, request, @headers))

      # check response
      response[:TransactionState].should match /^failed$/
      response[:Code].should match /^400.1021$/
      response[:Description].should match "The Parent Transaction Id is required, and not provided.  Please check your input and try again"
      response[:Severity].should match /^error$/
    end

    # void-credit (success)
    it "should receive the success-response for a correct void-credit request" do

      # create a parent transaction, because parent-transaction-id will be needed
      request = @gateway.build_request :credit, 101.0, @options
      unparsed_response = @gateway.ssl_post(@TEST_URL, request, @headers)

      xml = REXML::Document.new unparsed_response
      parent_id = REXML::XPath.first(xml, "//transaction-id").text

      # insert current parent-transaction-id
      request = @gateway.build_request :void_credit, 101.0, @options
      request.gsub!(%r{<parent-transaction-id>.+</parent-transaction-id>}, 
                    "<parent-transaction-id>#{parent_id}</parent-transaction-id>")

      response = @gateway.parse(@gateway.ssl_post(@TEST_URL, request, @headers))

      # check response
      response[:TransactionState].should match /^success$/
      response[:Code].should match /^200.0000$/
      response[:Description].should match /^The request completed successfully/
      response[:Severity].should match /^information$/
    end

    # void-credit (failed)
    it "should receive the failure-response for a void-credit request with missing parent-transaction-id" do

      # invalidate request
      request = @gateway.build_request :void_credit, 100.0, @options
      request.gsub!(%r{\n  <parent-transaction-id>.+</parent-transaction-id>}, '')
      response = @gateway.parse(@gateway.ssl_post(@TEST_URL, request, @headers))

      # check response
      response[:TransactionState].should match /^failed$/
      response[:Code].should match /^400.1021$/
      response[:Description].should match "The Parent Transaction Id is required, and not provided.  Please check your input and try again"
      response[:Severity].should match /^error$/
    end
  end
end







