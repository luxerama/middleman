require "middleman-core/watcher"

# CSSPIE HTC File
::Rack::Mime::MIME_TYPES['.htc'] = 'text/x-component'

# Let's serve all HTML as UTF-8
::Rack::Mime::MIME_TYPES['.html'] = 'text/html; charset=utf-8'
::Rack::Mime::MIME_TYPES['.htm'] = 'text/html; charset=utf-8'

module Middleman
  
  class Rack
    
    class << self
      # Prototype app. Used in config.ru
      #
      # @private
      # @return [Rack::Builder]
      def prototype(*args, &block)
        @prototype ||= new(*args, &block)
      end

      # Call prototype, use in config.ru
      #
      # @private
      def call(env)
        prototype.call(env)
      end
    end
    
    attr_reader :server, :singleton, :app
    
    def initialize(options={}, &block)
      @options = options
      @config_block = block
      
      reload_instance!
      
      # Register watcher responder
      if options[:watcher]
        @watcher = ::Middleman::Watcher.new
        @watcher.on_change(&method(:on_change))
        @watcher.on_delete(&method(:on_delete))
        @watcher.on_reload(&method(:reload_instance!))
        @watcher.start
      end
    end
    
    delegate :call, :to => :app
    delegate :logger, :to => :singleton
    
    def on_change(path)
      @singleton.files.did_change(path)
    end
    
    def on_delete(path)
      @singleton.files.did_delete(path)
    end
    
    # TODO: Cleanup old instances?
    def reload_instance!
      @server = ::Middleman::Application.server
      @singleton = @server.singleton(&@config_block)
      @app = to_rack_app(@server, @singleton)
    end
    
  protected

    # Return built Rack app
    #
    # @private
    # @return [Rack::Builder]
    def to_rack_app(server, singleton)
      rack_app = ::Rack::Builder.new

      (server.middleware || []).each do |m|
        rack_app.use(m[0], *m[1], &m[2])
      end

      rack_app.map("/") { run singleton }

      (server.mappings || []).each do |m|
        rack_app.map(m[0], &m[1])
      end

      rack_app
    end
  end
end