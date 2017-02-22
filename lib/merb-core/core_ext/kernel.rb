module Kernel
  # Loads the given string as a gem.
  #
  # ==== Parameters
  # name<String>:: The name of the gem to load.
  # *ver<Gem::Requirement, Gem::Version, Array, ~to_str>::
  #   Version requirements to be passed to Gem.activate.
  #
  # ==== Notes
  # If the gem cannot be found, the method will attempt to require the string
  # as a library.
  #
  # This new version tries to load the file via ROOT/gems first before moving
  # off to the system gems (so if you have a lower version of a gem in
  # ROOT/gems, it'll still get loaded).
  def dependency(name, *ver)
    try_framework = Merb.frozen?
    begin
      # If this is a piece of merb, and we're frozen, try to require
      # first, so we can pick it up from framework/, 
      # otherwise try activating the gem
      if name =~ /^merb/ && try_framework
        require name
      else
        Gem.activate(name, true, *ver)
        Merb.logger.info("loading gem '#{name}' from #{__app_file_trace__.first} ...")
      end
    rescue LoadError
      if try_framework
        try_framework = false
        retry
      else
        Merb.logger.info("loading gem '#{name}' from #{__app_file_trace__.first} ...")
        # Failed requiring as a gem, let's try loading with a normal require.
        require name
      end
    end
  end

  # Loads both gem and library dependencies that are passed in as arguments.
  #
  # ==== Parameters
  # *args<String, Hash, Array>:: The dependencies to load.
  #
  # ==== Notes
  # Each argument can be:
  # String:: Single dependency.
  # Hash::
  #   Multiple dependencies where the keys are names and the values versions.
  # Array:: Multiple string dependencies.
  #
  # ==== Examples
  # dependencies "RedCloth"                 # Loads the the RedCloth gem
  # dependencies "RedCloth", "merb_helpers" # Loads RedCloth and merb_helpers
  # dependencies "RedCloth" => "3.0"        # Loads RedCloth 3.0
  def dependencies(*args)
    args.each do |arg|
      case arg
      when String then dependency(arg)
      when Hash   then arg.each { |r,v| dependency(r, v) }
      when Array  then arg.each { |r|   dependency(r)    }
      end
    end
  end
    
  # Attempts to require and logs a message of the require whether it is
  # successful or not.
  #
  # ==== Parameters
  # library<~to_s>:: The library to attempt to require.
  def requires(library)
    # TODO: Extract messages out into a messages file. This will also be the first step towards internationalization.
    # TODO: adjust this message once logging refactor is complete.
    require(library)
    message = "loading library '#{library}' from #{__app_file_trace__.first} ..."
    Merb.logger.debug(message)
  rescue LoadError
    # TODO: adjust the two messages below to use merb's logger.error/info once logging refactor is complete.
    message = "<e> Could not find '#{library}' as either a library or gem, loaded from #{__app_file_trace__.first}.\n"
    Merb.logger.error(message)
    
    # Print a helpful message
    message =  " <i> Please be sure that if '#{library}': \n"
    message << " <i>   * is a normal ruby library (file), be sure that the path of the library it is present in the $LOAD_PATH via $LOAD_PATH.unshift(\"/path/to/#{library}\") \n"
    message << " <i>   * is included within a gem, be sure that you are specifying the gem as a dependency \n"
    Merb.logger.error(message)
    exit # Missing library/gem must be addressed.
  end
  
  # Does a basic require, and prints a message if an error occurs.
  #
  # ==== Parameters
  # library<~to_s>:: The library to attempt to include.
  # message<String>:: The error to add to the log upon failure. Defaults to nil.
  def rescue_require(library, message = nil)
    require library
  rescue LoadError, RuntimeError
    Merb.logger.error(message) if message
  end
  
  # Used in Merb.root/config/init.rb to tell Merb which ORM (Object Relational
  # Mapper) you wish to use. Currently Merb has plugins to support
  # ActiveRecord, DataMapper, and Sequel.
  #
  # ==== Parameters
  # orm<~to_s>:: The ORM to use.
  #
  # ==== Examples
  #   # This line goes in dependencies.yml
  #   use_orm :datamapper
  #
  #   # This will use the DataMapper generator for your ORM
  #   $ ruby script/generate model MyModel
  def use_orm(orm)
    raise "Don't call use_orm more than once" unless Merb.generator_scope.delete(:merb_default)
    begin
      orm_plugin = orm.to_s.match(/^merb_/) ? orm.to_s : "merb_#{orm}"
      Merb.generator_scope.unshift(orm.to_sym) unless Merb.generator_scope.include?(orm.to_sym)
      Kernel.dependency(orm_plugin)
    rescue LoadError => e
      Merb.logger.warn("The #{orm_plugin} gem was not found.  You may need to install it.")
      raise e
    end
  end
  
  # Used in Merb.root/config/init.rb to tell Merb which testing framework to
  # use. Currently Merb has plugins to support RSpec and Test::Unit.
  #
  # ==== Parameters
  # test_framework<Symbol>::
  #   The test framework to use. Currently only supports :rspec and :test_unit.
  #
  # ==== Examples
  #   # This line goes in dependencies.yml
  #   use_test :rspec
  #
  #   # This will now use the RSpec generator for tests
  #   $ ruby script/generate controller MyController
  def use_test(test_framework)
    raise "use_test only supports :rspec and :test_unit currently" unless 
      [:rspec, :test_unit].include?(test_framework.to_sym)
    Merb.generator_scope.delete(:rspec)
    Merb.generator_scope.delete(:test_unit)
    Merb.generator_scope.push(test_framework.to_sym)
    
    begin
      test_plugin = test_framework.to_s.match(/^merb_/) ? test_framework.to_s : "merb_#{test_framework}"
      Kernel.dependency(test_plugin)
    rescue LoadError => e
      Merb.logger.warn("The #{test_plugin} gem was not found.  You may need to install it.")
    end
  end
  
  # ==== Returns
  # Array[String]:: A stack trace of the applications files.
  def __app_file_trace__
    caller.select do |call| 
      call.include?(Merb.root) && !call.include?(Merb.root + "/framework")
    end.map do |call|
      file, line = call.scan(Regexp.new("#{Merb.root}/(.*):(.*)")).first
      "#{file}:#{line}"
    end
  end

  # ==== Parameters
  # i<Fixnum>:: The caller number. Defaults to 1.
  #
  # ==== Returns
  # Array[Array]:: The file, line and method of the caller.
  #
  # ==== Examples
  #   __caller_info__(1)
  #     # => ['/usr/lib/ruby/1.8/irb/workspace.rb', '52', 'irb_binding']
  def __caller_info__(i = 1)
    file, line, meth = caller[i].scan(/(.*?):(\d+):in `(.*?)'/).first
  end

  # ==== Parameters
  # file<String>:: The file to read.
  # line<Fixnum>:: The line number to look for.
  # size<Fixnum>::
  #   Number of lines to include above and below the the line to look for.
  #   Defaults to 4.
  #
  # ==== Returns
  # Array[Array]::
  #   Triplets containing the line number, the line and whether this was the
  #   searched line.
  #
  # ==== Examples
  #  __caller_lines__('/usr/lib/ruby/1.8/debug.rb', 122, 2) # =>
  #   [
  #     [ 120, "  def check_suspend",                               false ],
  #     [ 121, "    return if Thread.critical",                     false ],
  #     [ 122, "    while (Thread.critical = true; @suspend_next)", true  ],
  #     [ 123, "      DEBUGGER__.waiting.push Thread.current",      false ],
  #     [ 124, "      @suspend_next = false",                       false ]
  #   ]
  def __caller_lines__(file, line, size = 4)
    return [['Template Error!', "problem while rendering", false]] if file =~ /\(erubis\)/
    lines = File.readlines(file)
    current = line.to_i - 1

    first = current - size
    first = first < 0 ? 0 : first

    last = current + size
    last = last > lines.size ? lines.size : last

    log = lines[first..last]

    area = []

    log.each_with_index do |line, index|
      index = index + first + 1
      area << [index, line.chomp, index == current + 1]
    end

    area
  end
  
  # Takes a block, profiles the results of running the block 100 times and
  # writes out the results in a file.
  #
  # ==== Parameters
  # name<~to_s>::
  #   The file name. The result will be written out to
  #   Merb.root/"log/#{name}.html".
  # min<Fixnum>::
  #   Minimum percentage of the total time a method must take for it to be
  #   included in the result. Defaults to 1.
  #
  # ==== Returns
  # String:: The result of the profiling.
  #
  # ==== Notes
  # Requires ruby-prof (<tt>sudo gem install ruby-prof</tt>)
  #
  # ==== Examples
  #   __profile__("MyProfile", 5) do
  #     30.times { rand(10)**rand(10) }
  #     puts "Profile run"
  #   end
  #
  # Assuming that the total time taken for #puts calls was less than 5% of the
  # total time to run, #puts won't appear in the profile report.
  def __profile__(name, min=1)
    require 'ruby-prof' unless defined?(RubyProf)
    return_result = ''
    result = RubyProf.profile do
      100.times{return_result = yield}
    end
    printer = RubyProf::GraphHtmlPrinter.new(result)
    path = File.join(Merb.root, 'log', "#{name}.html")
    File.open(path, 'w') do |file|
     printer.print(file, {:min_percent => min,
                          :print_file => true})
    end
    return_result
  end  
  
  # Extracts an options hash if it is the last item in the args array. Used
  # internally in methods that take *args.
  #
  # ==== Parameters
  # args<Array>:: The arguments to extract the hash from.
  #
  # ==== Examples
  #   def render(*args,&blk)
  #     opts = extract_options_from_args!(args) || {}
  #     # [...]
  #   end
  def extract_options_from_args!(args)
    args.pop if Hash === args.last
  end
  
  # Checks that the given objects quack like the given conditions.
  #
  # ==== Parameters
  # opts<Hash>::
  #   Conditions to enforce. Each key will receive a quacks_like? call with the
  #   value (see Object#quacks_like? for details).
  #
  # ==== Raises
  # ArgumentError:: An object failed to quack like a condition.
  def enforce!(opts = {})
    opts.each do |k,v|
      raise ArgumentError, "#{k.inspect} doesn't quack like #{v.inspect}" unless k.quacks_like?(v)
    end
  end
  
  unless Kernel.respond_to?(:debugger)

    # Define debugger method so that code even works if debugger was not
    # requested. Drops a note to the logs that Debugger was not available.
    def debugger
       Merb.logger.info "\n***** Debugger requested, but was not " + 
                        "available: Start server with --debugger " +
                        "to enable *****\n"
    end
  end
end
