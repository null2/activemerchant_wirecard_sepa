ActiveMerchant Wirecard Sepa Payment Processing
-----

Implements the Wirecard SEPA Payments REST API as separate 
Gateway. Currently supports all but the recurring transaction types.
Extensively tested via RSpec.

## Installation

Add this line to your application's Gemfile:

    gem 'activemerchant_wirecard_sepa'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install activemerchant_wirecard_sepa

## Usage

To use this extension, roughly follow this pattern:

```ruby
require 'digest/sha1'

gateway_options = {
  :login => "yourlogin",
  :password => "yourpassword",
  :merchant_account_id => "yourid",
  :merchant_account_name => "account name (optional)"
}

# instantiate a new Gateway with options
gw = ActiveMerchant::Billing::WirecardSepaGateway.new gateway_options

# create an Account data structure to hold our data
account = ActiveMerchant::Billing::SepaAccount.new :iban => "DEA342....",
  :bic => "BIC2343..",
  :first_name => "Karl-Heinz",
  :last_name => "Mustermann"

# buy something via SEPA direct debit
response = gw.debit 100.0, account, :mandate_id => "a special id",
  :request_id => Digest::SHA1.hexdigest(Time.now.to_i), # must be different for each and every request
  :signed_date => Date.today

if response.success?
  # ...handle result
end
```

Implemented methods are:

* debit
* credit
* void-credit
* void-debit
* authorize

## TODO:

* recurring debit transactions
* recurring credit transactions

## Contributing

1. Fork it ( https://github.com/[my-github-username]/activemerchant_wirecard_sepa/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
