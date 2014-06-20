module ActiveMerchant
  module Billing
    class ReconciliationFile 
      require 'csv'

      attr_reader :filename, 
        :merchant_account_id, 
        :processing_gateway, 
        :processing_date, 
        :internal_ip, 
        :transactions

      CSV::Converters[:null_to_nil] = lambda do |field|
        field == "NULL" ? nil : field
      end

      def initialize filename, body
        raise "Filename required" unless filename
        raise "Body required"     unless body

        gw, ip, date, id = File::basename(filename, '.csv').split('_')

        @filename            = filename
        @processing_gateway  = gw
        @internal_ip         = ip
        @processing_date     = Date.parse(date)
        @merchant_account_id = id
        @transactions        = parse body
      end

      private 
      def parse body
        csv = CSV.new body, 
          :col_sep => ';', 
          :quote_char => '"',
          :headers => true, 
          :header_converters => :symbol, 
          :converters => [:all, :null_to_nil]

        csv.to_a.map &:to_hash
      end 
    end
  end
end

