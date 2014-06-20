require 'spec_helper'

describe ActiveMerchant::Billing::ReconciliationFile do
  describe "when created" do
    before :all do
      @filename = "EngineAPTransactions_111.22.333.444_20130101_11a1a111-11a1-1a11-a111-111a11aaa11a.csv" 

      @csv = CSV.generate :col_sep => ';', :quote_char => '"' do |doc| 
        # HEADERS
        doc << ["MERCHANT ACCOUNT NAME", "MERCHANT ACCOUNT ID",
                "REQUEST ID", "PAYMENT METHOD",
                "TRANSACTION ID", "TRANS. CREATION TIMESTAMP",
                "TRANSACTION TYPE", "TRANSACTION STATUS", "TRANSACTION STATUS CODE", 
                "TRANSACTION REASON DESCRIPTION", "TRANSACTION AMOUNT", "TRANSACTION CURRENCY",
                "SETTLEMENT AMOUNT", "SUM SETTLEMENT AMOUNT", "SETTLEMENT CURRENCY", 
                "EXCHANGE RATE", "EXCHANGE RATE SOURCE", "USAGE",
                "REF. TRANSACTION ID 1", "REF. TRANSACTION ID 2", "REF. TRANSACTION ID 3", "REF. TRANSACTION ID 4" ]

        # Row 1
        doc << ["smart tickets gmbh", "smart-4$$-tickets", "0000-0000-0003", "SEPA Direkt Debit",
                "0000-0000-0002", "15.07.2014 00:00", "debit", "success", "201.0000", "All good",
                "103.20", "EUR", "NULL", "NULL", "NULL", "NULL", "NULL", "Yadda yadda yadda", 
                "0000-0000-0001", "NULL", "NULL", "NULL" ]
        # Row 2
        doc << ["smart tickets gmbh", "smart-4$$-tickets", "0000-0000-0004", "SEPA Direkt Debit",
                "0000-0000-0004", "15.07.2014 04:00", "credit", "success", "201.0000", "All good",
                "203.20", "EUR", "NULL", "NULL", "NULL", "NULL", "NULL", "Yadda yadda yadda", 
                "0000-0000-0005", "NULL", "NULL", "NULL" ]
      end

      @recon = ActiveMerchant::Billing::ReconciliationFile.new @filename, @csv
    end

    it "should set the filename as attributes" do
      gw, ip, date, id = File::basename(@filename, '.csv').split('_')

      @recon.filename.should == @filename
      @recon.processing_gateway.should == gw
      @recon.processing_date.should == Date.parse(date)
      @recon.internal_ip == ip 
      @recon.merchant_account_id == "11a1a111-11a1-1a11-a111-111a11aaa11a"
    end
 
    it "should parse the body into an array of hashes" do
      @recon.transactions.should be_a Array
      @recon.transactions.first.should be_a Hash
    end

    it "should parse the csv headers into lower-case, underscore-separated symbols" do
      @recon.transactions.first[:merchant_account_name].should == "smart tickets gmbh"
    end

    it "should parse NULL values as nil values" do
      @recon.transactions.first[:exchange_rate].should be_nil
    end

    it "should have no header row" do
      @recon.transactions.size.should be 2
    end
  end

end
