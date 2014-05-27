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
end
