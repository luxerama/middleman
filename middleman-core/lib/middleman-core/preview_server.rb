require "webrick"
require "middleman-core/rack"

module Middleman
  
  WINDOWS = !!(RUBY_PLATFORM =~ /(mingw|bccwin|wince|mswin32)/i) unless const_defined?(:WINDOWS)

  module PreviewServer
    
    DEFAULT_PORT = 4567
    
    class << self
      attr_reader :rack_app
      delegate :logger, :to => :rack_app
      
      # Start an instance of Middleman::Application
      # @return [void]
      def start(options={})
        options[:watcher] = !options[:"disable-watcher"]
        
        @rack_app = ::Middleman::Rack.new(options) do
          if options[:environment]
            set :environment, options[:environment].to_sym
          end
          
          logger(options[:debug] ? 0 : 1, options[:instrumenting] || false)
        end

        port = options[:port] || DEFAULT_PORT
    
        logger.info "== The Middleman is standing watch on port #{port}"

        @webrick ||= begin
          w = setup_webrick(
            options[:host]  || "0.0.0.0",
            port,
            options[:debug] || false
          )
          w.mount "/", ::Rack::Handler::WEBrick, @rack_app
          w
        end
        
        @initialized ||= false
        unless @initialized
          @initialized = true
          
          register_signal_handlers unless ::Middleman::WINDOWS
          
          # Save the last-used options so it may be re-used when
          # reloading later on.
          ::Middleman::Profiling.report("server_start")

          @webrick.start
        end
      end

      # Detach the current Middleman::Application instance
      # @return [void]
      def stop
        logger.info "== The Middleman is shutting down"
      end

      # Stop the current instance, exit Webrick
      # @return [void]
      def shutdown
        stop
        @webrick.shutdown
      end
      
    private
      
      # Trap the interupt signal and shut down smoothly
      # @return [void]
      def register_signal_handlers
        trap("INT")  { shutdown }
        trap("TERM") { shutdown }
        trap("QUIT") { shutdown }
      end
      
      # Initialize webrick 
      # @return [void]
      def setup_webrick(host, port, is_logging)
        @host = host
        @port = port
        
        http_opts = {
          :BindAddress => @host,
          :Port        => @port,
          :AccessLog   => []
        }
        
        if is_logging
          http_opts[:Logger] = FilteredWebrickLog.new
        else
          http_opts[:Logger] = ::WEBrick::Log.new(nil, 0)
        end
      
        ::WEBrick::HTTPServer.new(http_opts)
      end
    end

    class FilteredWebrickLog < ::WEBrick::Log
      def log(level, data)
        unless data =~ %r{Could not determine content-length of response body.}
          super(level, data)
        end
      end
    end
  end
end
