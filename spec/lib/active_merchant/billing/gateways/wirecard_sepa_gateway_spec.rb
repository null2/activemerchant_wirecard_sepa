require 'spec_helper'

describe ActiveMerchant::Billing::WirecardSepaGateway do
  describe "XML validation" do
    before :each do
      @schema = Nokogiri::XML::Schema(File.read(PROJECT_ROOT + "/validation/payment.xsd"))

      @gateway = ActiveMerchant::Billing::WirecardSepaGateway.new

      @account = ActiveMerchant::Billing::SepaAccount.new
      @account.first_name = "hasf"
      @account.last_name = "slkdjfdsk"
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
    end

    it "parser should detect xml that is no wirecard-reply, i.e. has no statuses-field" do
      no_reply_xml = '<payment><no-statuses>Sorry, I am not a wirecard reply!</no-statuses></payment>'

      parsed_response = @gateway.parse(no_reply_xml)
      parsed_response[:Message].should match "No valid XML response message received. \nPropably wrong credentials supplied with HTTP header."
    end

    it "should receive the success-response for correct debit request" do

      # send request
      request = @gateway.build_request :debit, 100.0, @options
      response = @gateway.commit request

      # check response
      response[:Code].should match /^201.0000$/
      response[:Description].should match /^The resource was successfully created.$/
      response[:Severity].should match /^information$/
    end

    it "should receive the adequate failure-response for a debit request with missing account holder info", :pending => true do
      @options[:sepa_account].first_name = nil
      @options[:sepa_account].last_name = nil

      request = @gateway.build_request :debit, 100.0, @options
      response = @gateway.commit request

      response.should match '<transaction-state>failed</transaction-state>'
    end
    
    it "should receive the success-response for correct credit request"
    it "should receive the failure-response for false credit request"
  end
end







