class Pry
  class NoCommandError < StandardError
    def initialize(name, owner)
      super "Command '#{name}' not found in command set #{owner}"
    end
  end

  # This class used to create sets of commands. Commands can be impoted from
  # different sets, aliased, removed, etc.
  class CommandSet
    class Command < Struct.new(:name, :description, :options, :block)
      def call(context, *args)
        context.instance_exec(*args, &block)
      end
    end

    attr_reader :commands
    attr_reader :name

    # @param [Symbol] name Name of the command set
    # @param [Array<CommandSet>] imported_sets Sets which will be imported
    #   automatically
    # @yield Optional block run to define commands
    def initialize(name, *imported_sets, &block)
      @name     = name
      @commands = {}

      import(*imported_sets)

      instance_eval(&block) if block
    end

    # Defines a new Pry command.
    # @param [String, Array] names The name of the command (or array of
    #   command name aliases).
    # @param [String] description A description of the command.
    # @param [Hash] options The optional configuration parameters.
    # @option options [Boolean] :keep_retval Whether or not to use return value
    #   of the block for return of `command` or just to return `nil`
    #   (the default).
    # @yield The action to perform. The parameters in the block
    #   determines the parameters the command will receive. All
    #   parameters passed into the block will be strings. Successive
    #   command parameters are separated by whitespace at the Pry prompt.
    # @example
    #   MyCommands Pry::CommandSet.new :mine do
    #     command "greet", "Greet somebody" do |name|
    #       puts "Good afternoon #{name.capitalize}!"
    #     end
    #   end
    #
    #   # From pry:
    #   # pry(main)> _pry_.commands = MyCommands
    #   # pry(main)> greet john
    #   # Good afternoon John!
    #   # pry(main)> help greet
    #   # Greet somebody
    def command(names, description="No description.", options={}, &block)
      Array(names).each do |name|
        commands[name] = Command.new(name, description, options, block)
      end
    end

    # Removes some commands from the set
    # @param [Arary<String>] names name of the commands to remove
    def delete(*names)
      names.each { |name| commands.delete name }
    end

    # Imports all the commands from one or more sets.
    # @param [Array<CommandSet>] sets Command sets, all of the commands of which
    #   will be imported.
    def import(*sets)
      sets.each { |set| commands.merge! set.commands }
    end

    # Imports some commands from a set
    # @param [CommandSet] set Set to import commands from
    # @param [Array<String>] names Commands to import
    def import_from(set, *names)
      names.each { |name| commands[name] = set.commands[name] }
    end

    # Aliases a command
    # @param [String] new_name new name of the command
    # @param [String] old_name old name of the command
    def alias_command(new_name, old_name)
      commands[new_name] = commands[old_name].dup
      commands[new_name].name = new_name
    end

    # Runs a command.
    # @param [Object] context Object which will be used as self during the
    #   command.
    # @param [String] name Name of the command to be run
    # @param [Array<Object>] args Arguments passed to the command
    # @raise [NoCommandError] If the command is not defined in this set
    def run_command(context, name, *args)
      if command = commands[name]
        command.call(context, *args)
      else
        raise NoCommandError.new(name, self)
      end
    end
  end
end