# Watcher Library
require "listen"

module Middleman
  class Watcher
    
    def initialize
      @_reload_callbacks = []
      @_change_callbacks = []
      @_delete_callbacks = []
    end
    
    def on_reload(&block)
      @_reload_callbacks << block if block_given?
      @_reload_callbacks
    end
    
    def on_change(&block)
      @_change_callbacks << block if block_given?
      @_change_callbacks
    end
    
    def on_delete(&block)
      @_delete_callbacks << block if block_given?
      @_delete_callbacks
    end
    
    def start
      return if @listener
    
      @listener = Listen.to(Dir.pwd, :relative_paths => true)
    
      @listener.change do |modified, added, removed|
        added_and_modified = (modified + added)
    
        unless added_and_modified.empty?
          # See if the changed file is config.rb or lib/*.rb
          if needs_to_reload?(added_and_modified)
            reload!
            return
          end
    
          # Otherwise forward to Middleman
          added_and_modified.each do |path|
            on_change.each { |b| $stderr.puts b.inspect, path; b.call(path); }
          end
        end
    
        unless removed.empty?
          # See if the changed file is config.rb or lib/*.rb
          if needs_to_reload?(removed)
            reload!
            return
          end
    
          # Otherwise forward to Middleman
          removed.each do |path|
            on_delete.each { |b| b.call(path) }
          end
        end
      end
        
      # Don't block this thread
      @listener.start(false)
    end
    
    def stop
      if @listener
        @listener.stop
        @listener = nil
      end
    end
    
    # Whether the passed files are config.rb, lib/*.rb or helpers
    # @param [Array<String>] paths Array of paths to check
    # @return [Boolean] Whether the server needs to reload
    def needs_to_reload?(paths)
      paths.any? do |path|
        path.match(%{^config\.rb}) || path.match(%r{^lib/^[^\.](.*)\.rb$}) || path.match(%r{^helpers/^[^\.](.*)_helper\.rb$})
      end
    end
    
    def reload!
      on_reload.each { |b| b.call }
    end
  end
end