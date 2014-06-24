module ActiveMerchant
  module Billing
    class WirecardSepaReconciliationGateway < Gateway
      require 'net/sftp'

      attr_reader :client

      def initialize(options = {})
        @host       = options[:host]
        @port       = options[:post]
        @user       = options[:user]
        @passphrase = options[:passphrase]
        @keys       = options[:keys]
      end

      # creates a sftp client session
      def connect!
        unless @client
          @client = Net::SFTP.start @host, @user,
            :port         => @port,
            :paranoid     => false,
            :auth_methods => ["publickey"],
            :passphrase   => @passphrase,
            :keys         => @keys
        end
      end

      def disconnect!
        return unless @client 
        @client.close_channel
        @client = nil
      end


      # fetch csv data from server, return a list of hashes
      def fetch
        connect! unless @client

        files = @client.dir.glob("to#{@user}/new", "EngineAPTransactions_*.csv").map do |entry|
          filepath = "to#{@user}/new/#{entry.name}"

          ActiveMerchant::Billing::ReconciliationFile.new(entry.name, @client.download!(filepath))
        end

        disconnect!

        files
      end

      # move files in list from new/ to processed/ 
      def move files
        connect! unless @client 

        if files.respond_to? :each
          files.each do |filename|
            move_file filename
          end
        else
          move_file files
        end

        disconnect!
      end

      private 

      def move_file filename
        source, target = "to#{@user}/new/#{filename}", "to#{@user}/processed/#{filename}"

        tmp = TempFile.new(filename)

        begin 
          @client.download!(source, tmp)

          tmp.close(false)

          @client.upload!(tmp.path, target)                 
          @client.remove!(source)
        ensure
          tmp.unlink 
        end
      end
    end
  end
end
