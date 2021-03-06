require 'pathname'
require 'middleman-core/file_renderer'
require 'middleman-core/template_renderer'
require 'middleman-core/contracts'

module Middleman
  # The TemplateContext Class
  #
  # A clean context, separate from Application, in which templates can be executed.
  # All helper methods and values available in a template, but be accessible here.
  # Also implements two helpers: wrap_layout & render (used by padrino's partial method).
  # A new context is created for each render of a path, but that context is shared through
  # the request, passed from template, to layouts and partials.
  class TemplateContext
    extend Forwardable
    include Contracts

    # Allow templates to directly access the current app instance.
    # @return [Middleman::Application]
    attr_reader :app

    # Required for Padrino's rendering
    attr_accessor :current_engine

    # Shorthand references to global values on the app instance.
    def_delegators :@app, :config, :logger, :sitemap, :server?, :build?, :environment?, :data, :extensions, :root

    # Initialize a context with the current app and predefined locals and options hashes.
    #
    # @param [Middleman::Application] app
    # @param [Hash] locs
    # @param [Hash] opts
    def initialize(app, locs={}.freeze, opts={}.freeze)
      @app = app
      @locs = locs
      @opts = opts
    end

    # Return the current buffer to the caller and clear the value internally.
    # Used when moving between templates when rendering layouts or partials.
    #
    # @api private
    # @return [String] The old buffer.
    def save_buffer
      @_out_buf, buf_was = '', @_out_buf
      buf_was
    end

    # Restore a previously saved buffer.
    #
    # @api private
    # @param [String] buf_was
    # @return [void]
    def restore_buffer(buf_was)
      @_out_buf = buf_was
    end

    # Allow layouts to be wrapped in the contents of other layouts.
    #
    # @param [String, Symbol] layout_name
    # @return [void]
    def wrap_layout(layout_name, &block)
      # Save current buffer for later
      buf_was = save_buffer

      # Find a layout for this file
      layout_file = ::Middleman::TemplateRenderer.locate_layout(@app, layout_name, current_engine)

      # Get the layout engine
      extension = File.extname(layout_file[:relative_path])
      engine = extension[1..-1].to_sym

      # Store last engine for later (could be inside nested renders)
      self.current_engine, engine_was = engine, current_engine

      # By default, no content is captured
      content = ''

      # Attempt to capture HTML from block
      begin
        content = capture_html(&block) if block_given?
      ensure
        # Reset stored buffer, regardless of success
        restore_buffer(buf_was)
      end
      # Render the layout, with the contents of the block inside.
      concat_safe_content render_file(layout_file, @locs, @opts) { content }
    ensure
      # Reset engine back to template's value, regardless of success
      self.current_engine = engine_was
    end

    # Sinatra/Padrino compatible render method signature referenced by some view
    # helpers. Especially partials.
    #
    # @param [String, Symbol] name The partial to render.
    # @param [Hash] options
    # @return [String]
    Contract Any, Or[Symbol, String], Hash => String
    def render(_, name, options={}, &block)
      name = name.to_s

      partial_file = locate_partial(name)

      return '' unless partial_file
      raise ::Middleman::TemplateRenderer::TemplateNotFound, "Could not locate partial: #{name}" unless partial_file

      source_path = sitemap.file_to_path(partial_file)
      r = sitemap.find_resource_by_path(source_path)

      if (r && !r.template?) || (Tilt[partial_file[:full_path]].nil? && partial_file[:full_path].exist?)
        File.read(partial_file[:full_path])
      else
        opts = options.dup
        locs = opts.delete(:locals)

        render_file(partial_file, locs.freeze, opts.freeze, &block)
      end
    end

    # Locate a partial relative to the current path or the source dir, given a partial's path.
    #
    # @api private
    # @param [String] partial_path
    # @return [String]
    Contract String => Maybe[IsA['Middleman::SourceFile']]
    def locate_partial(partial_path)
      return unless resource = sitemap.find_resource_by_destination_path(current_path)

      # Look for partials relative to the current path
      current_dir = resource.source_file[:relative_path].dirname
      non_root = partial_path.to_s.sub(/^\//, '')
      relative_dir = current_dir + Pathname(non_root)

      non_root_no_underscore = non_root.sub(/^_/, '').sub(/\/_/, '/')
      relative_dir_no_underscore = current_dir + Pathname(non_root_no_underscore)

      partial_file = nil

      [
        [relative_dir.to_s, { preferred_engine: resource.source_file[:relative_path].extname[1..-1].to_sym }],
        [non_root],
        [non_root, { try_static: true }],
        [relative_dir_no_underscore.to_s, { try_static: true }],
        [non_root_no_underscore, { try_static: true }]
      ].each do |args|
        partial_file = ::Middleman::TemplateRenderer.resolve_template(@app, *args)
        break if partial_file
      end

      partial_file || nil
    end

    protected

    # Render a path with locs, opts and contents block.
    #
    # @api private
    # @param [Middleman::SourceFile] file The file.
    # @param [Hash] locs Template locals.
    # @param [Hash] opts Template options.
    # @param [Proc] block A block will be evaluated to return internal contents.
    # @return [String] The resulting content string.
    Contract IsA['Middleman::SourceFile'], Hash, Hash, Proc => String
    def render_file(file, locs, opts, &block)
      file_renderer = ::Middleman::FileRenderer.new(@app, file[:relative_path].to_s)
      file_renderer.render(locs, opts, self, &block)
    end

    def current_path
      @locs[:current_path]
    end

    # Get the resource object for the current path
    # @return [Middleman::Sitemap::Resource]
    def current_resource
      return nil unless current_path
      sitemap.find_resource_by_destination_path(current_path)
    end
    alias_method :current_page, :current_resource
  end
end
