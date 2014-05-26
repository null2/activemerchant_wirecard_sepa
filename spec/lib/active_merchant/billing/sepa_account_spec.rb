require 'spec_helper'



describe ActiveMerchant::Billing::SepaAccount do

  before :each do
  	@account = ActiveMerchant::Billing::SepaAccount.new
  	@account.first_name = Faker::Name.first_name
  	@account.last_name = Faker::Name.last_name
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
end
