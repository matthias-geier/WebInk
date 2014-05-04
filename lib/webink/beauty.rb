module Ink

  # = Beauty class
  #
  # This class provides a set of tools for loading config and init scripts
  # as well as the route-matching. Formerly it made the dispatcher code
  # much more beautiful, hence the name.
  # Since 3.0.0 it handles the dispatching for rack and serves static files
  # from ./files/*
  #
  #
  #
  class Beauty

    # Class accessor definitions
    #
    class << self
      attr_accessor :routes, :config, :root
    end

    # Constructor
    #
    def initialize
      @params = {}
    end

    # Instance method
    #
    # Rackup call
    # Initializes the webink environment
    # Rescues all kinds of errors and responds with error codes
    # [param env:] rack environment
    # [returns:] Rack-compatible array
    def call(env)
      @params = {} #reset
      @env = env
      controller = self.init
      if controller && !@params[:file]
        Ink::Database.create(@params[:config][:app_db])
        response = controller.verify(@params[:module]).call
        Ink::Database.database.close
        response || [404, {}, self.error_mapping(404)]
      elsif File.exist?("."+@params[:file])
        [ 200, {}, File.open("."+@params[:file], File::RDONLY) ]
      else
        [ 404, {}, self.error_mapping(404) ]
      end
    rescue LoadError => bang
      render_error(404, "LoadError", bang)
    rescue NotImplementedError => bang
      render_error(500, "NotImplementedError", bang)
    rescue ArgumentError => bang
      render_error(500, "ArgumentError", bang)
    rescue RuntimeError => bang
      render_error(500, "RuntimeError", bang)
    rescue NameError => bang
      render_error(500, "NameError", bang)
    rescue Exception, Error => bang
      render_error(500, "Exception", bang)
    end

    # Instance method
    #
    # Loads the models, requires the database type, preloads the controllers.
    # [returns: Array of loaded models
    def load_dependencies
      @params[:config].keys.select{ |k| k.to_s =~ /_db$/ }.each do |db|
        require "#{@params[:config][db][:db_type]}"
        require "#{@params[:config][db][:db_type]}_adapter"
      end

      Dir.new("./controllers").select{ |c| c =~ /\.rb$/ }.each do |c|
        controller_camel = $1.camelize if c =~ /^(.*)\.rb$/
        autoload(controller_camel, "./controllers/#{c}")
      end

      model_files = Dir.new("./models").select{ |m| m =~ /\.rb$/ }
      model_files.each do |m|
        model_camel = $1.camelize if m =~ /^(.*)\.rb$/
        autoload(model_camel, "./models/#{m}")
      end
      return model_files.map do |m|
        load("./models/#{m}")
        $1.camelize.constantize if m =~ /^(.*)\.rb$/
      end
    end

    # Instance method
    #
    # Loads the controller.
    # [returns:] Controller class
    def load_env
      load "./controllers/#{@params[:controller]}.rb"
      return Ink::Controller.verify(@params[:controller]).new(@params)
    end

    # Instance method
    #
    # Generates a param hash including the config, route and get/post
    # parameters.
    # [returns:] Controller class
    def init
      req = Rack::Request.new(@env)
      @params.merge!({:header => {}, :cookie => req.cookies})
      @params[:get] = Rack::Utils.parse_query(@env["QUERY_STRING"], '&;') || {}
      @params[:post] = {}
      if req.post?
        @params[:post] = req.params
        @params[:post].reject! do |k,v|
          @params[:get][k] and @params[:get][k] == v
        end
      end
      self.load_config
      self.load_routes
      self.load_dependencies
      return @params[:file] ? nil : self.load_env #static file requests are nil
    end

    # Instance method
    #
    # Attempts to load the config file of the project or raises a LoadError.
    # Once loaded, the config is returned
    # [returns:] a valid config
    def load_config
      config = "./config"
      config = "#{config}.rb" unless File.exist?(config)
      raise LoadError.new("Config not found.") unless File.exist?(config)
      load config
      if Beauty.config.nil?
        raise LoadError.new("Config extension error on Beauty")
      end
      @params[:config] = Beauty.config
      return @params[:config]
    end

    # Instance method
    #
    # Attempts to load the routes file of the project or raises a LoadError.
    # Determines and stores the current route in the @params
    def load_routes
      routes = "./routes"
      routes = "#{routes}.rb" unless File.exist?(routes)
      raise LoadError.new("Routes not found.") unless File.exist?(routes)
      load routes
      if Beauty.routes.nil?
        raise LoadError.new("Route extension error on Beauty")
      elsif Beauty.root.nil?
        raise LoadError.new("Root extension error on Beuaty")
      end
      @params.merge!(self.routing(@env["REQUEST_PATH"])) if @env["REQUEST_PATH"]
    end

    # Instance method
    #
    # Attempts to match the params onto the routes and return the results in
    # form of a Hash.
    # Possible root route is extracted and routes matching to /files/* will
    # be stored in the match.
    # [param str:] Requested string
    # [returns:] Hash of Symbol => String
    def routing(str)
      root = Beauty.root
      root = $1 if root =~ /(.*)\/$/
      match = { :root => root }
      if str =~ /^#{root}(.*)\/?$/
        str = $1
      else
        raise LoadError.new("No matching route found")
      end
      # match file route:
      if str =~ /^(\/files\/.+)$/
        return match.merge({ :file => $1 })
      end
      Beauty.routes.each do |entry|
        k = entry[0]
        v = entry[1]
        if str =~ k
          v.each do |sys,e|
            match[sys] =
              (e =~ /^\$\d+$/ and str =~ k and eval e) ? (eval e) : e
          end
          break
        end
      end
      raise LoadError.new("No matching route found") if match.keys.length <= 1
      return match
    end

    # Instance method
    #
    # Renders error stacktraces or errors back to the
    # user
    # [param code:] Error code integer
    # [param type:] Exception type string
    # [param bang:] Exception instance
    # [returns:] Rack-compatible array
    def render_error(code, type, bang)
      if Beauty.config && Beauty.config[:production]
        [code, {}, self.error_mapping(code)]
      else
        [200, {}, [
          "<b>#{type}</b>",
          "<em><pre>#{bang}</pre></em>",
          "<pre>#{bang.backtrace.join("\n")}</pre>"
        ]]
      end
    end

    # Instance method
    #
    # Maps error code integers to error strings
    # [param code:] Error code integer
    # [returns:] Error string
    def error_mapping(code)
      {
        404 => "404 Page not found",
        500 => "500 Internal error",
      }[code]
    end

  end
end
