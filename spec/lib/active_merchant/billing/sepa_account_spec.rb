require 'spec_helper'

describe ActiveMerchant::Billing::SepaAccount do

  before :each do
  	@account = ActiveMerchant::Billing::SepaAccount.new
  	@account.first_name = "Herbert"
  	@account.last_name = "Gisela"
    @account.iban = 'GR1601101250000000012300695'
    @account.bic = 'PBNKDEFF'
  end

  it 'should recognize a valid account as valid' do
  	@account.valid?.should be_true
  end

  it 'should validate presence of iban' do
    @account.iban = nil
    @account.valid?.should be_false
  end

  it 'should validate format of iban' do
    @account.iban = "123ab"
    @account.valid?.should be_false
  end

  it 'should validate presence of bic' do
    @account.bic = nil
    @account.valid?.should be_false    
  end

  it 'should validate format of bic' do
    @account.bic = "123"
    @account.valid?.should be_false    
  end

  it 'should validate presence of customer first name' do
    @account.first_name = nil
    @account.valid?.should be_false    
  end

  it 'should validate presence of customer last name' do
  	@account.last_name = nil
  	@account.valid?.should be_false    
  end

  it 'should reject an email with invalid format' do
    @account.email = "Falschmail"
    @account.valid?.should be_false
  end

  it 'should accept an email with valid format' do
    @account.email = "User-123@test.mail"
    @account.valid?.should be_true
  end
end
