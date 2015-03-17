module Cct
  class Command
    class << self
      attr_accessor :command_name
    end

    attr_reader :logger, :config, :bin_path, :env, :params

    def initialize options={}
      fail "Command name not set up" unless self.class.command_name

      @params   = params ? params.concat(options[:params] || []) : options[:params] || []
      @env      = env ? env.concat(options[:env] || []) : options[:env] || []
      @bin_path ||= options[:bin_path]
      @config   ||= options[:config] && options[:config][command_name]
      set_up_logger(options)
    end

    def command_name
      self.class.command_name
    end

    def run options={}
      status = :success
      sudo   = options[:sudo] ? 'sudo' : ''
      params.concat(options[:params] || [])

      command = "#{sudo} #{export(env)} #{bin_path}/#{command_name} #{params.join(' ')}"
      logger.info("Executing command `#{command.strip}`")

      IO.popen(command, :err=>[:child, :out]) do |lines|
        lines.each do |line|
          case line
          when /warn|cannot/i
            logger.warn(line.chomp)
          when /error/i
            logger.error(line.chomp)
            status = :error
          else
            logger.info(line.chomp)
          end
        end
      end

      unless $?.success?
        logger.error("Command `#{command} ` failed with exit status #{$?.exitstatus}")
        status = :error
      end

      options.merge(status: status)
    rescue Errno::ENOENT => e
      logger.error("Command `#{command}` not found")
    end

    private

    def export values=[]
      return "" if values.empty?

      env = values.map {|key, value| "#{key}=#{value}" }.join(" ")
      logger.info("Using environment variables #{env}")
      env
    end

    def set_up_logger options
      return if logger

      @logger = options[:logger] || Cct.logger
      logger.formatter = Logger::FORMATTER_SIMPLE
      logger.progname = command_name
    end
  end
end

require "cct/commands/mkcloud"
