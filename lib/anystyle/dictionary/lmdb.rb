module AnyStyle
  require 'lmdb'

  class Dictionary
    class LMDB < Dictionary
      @defaults = {
        path: File.expand_path('../data', __FILE__),
        mapsize:  1 << 22,
        writemap: true,
        mapasync: true
      }

      attr_reader :env

      def initialize(options = {})
        super(self.class.defaults.merge(options))
      end

      def open
        unless open?
          @env = ::LMDB.new(path, lmdb_options)
          @db = @env.database create: true
        end

        self
      ensure
        populate! if empty?
      end

      def close
        env.close if open?
      end

      def open?
        !db.nil?
      end

      def empty?
        open? and db.size == 0
      end

      def truncate
        close
        %w{ data.mdb lock.mdb }.each do |mdb|
          mdb = File.join(path, mdb)
          File.unlink(mdb) if File.exists?(mdb)
        end
      end

      def get(key)
        db[key.to_s].to_i
      end

      def put(key, value)
        db[key.to_s] = value.to_i.to_s
      end

      def path
        options[:path]
      end

      def lmdb_options
        options.reject { |k| [:path, :source].include?(k) }
      end
    end
  end
end
