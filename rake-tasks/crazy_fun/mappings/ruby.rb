class RubyMappings

  def add_all(fun)
    fun.add_mapping "ruby_library", RubyLibrary.new

    fun.add_mapping "ruby_test", CheckTestArgs.new
    fun.add_mapping "ruby_test", AddTestDefaults.new
    fun.add_mapping "ruby_test", RubyTest.new
    fun.add_mapping "ruby_test", AddTestDependencies.new

    fun.add_mapping "rubydocs", RubyDocs.new
    fun.add_mapping "rubygem",  RubyGem.new
  end

  class RubyLibrary < Tasks

    def handle(fun, dir, args)
      desc "Build #{args[:name]} in build/#{dir}"
      task_name = task_name(dir, args[:name])

      t = task task_name do
        puts "Preparing: #{task_name} in #{build_dir}/#{dir}"
        copy_sources dir, args[:srcs]
        copy_resources dir, args[:resources], build_dir if args[:resources]
        remove_svn_dirs
      end

      add_dependencies t, dir, args[:deps]
      add_dependencies t, dir, args[:resources]
    end

    def copy_sources(dir, globs)
      globs.each do |glob|
        Dir[File.join(dir, glob)].each do |file|
          destination = destination_for(file)
          mkdir_p File.dirname(destination)
          cp file, destination
        end
      end
    end

    def remove_svn_dirs
      Dir["#{build_dir}/rb/**/.svn"].each { |file| rm_rf file }
    end

    def destination_for(file)
      File.join build_dir, file
    end

    def build_dir
      "build"
    end

  end

  class CheckTestArgs
    def handle(fun, dir, args)
      raise "no :srcs specified for #{dir}" unless args.has_key? :srcs
      raise "no :name specified for #{dir}" unless args.has_key? :name
    end
  end

  class AddTestDefaults
    def handle(fun, dir, args)
      args[:include] = Array(args[:include])
      args[:include] << "#{dir}/spec"

      args[:command] = args[:command] || "rspec"
      args[:require] = Array(args[:require])

      # move?
      args[:srcs] = args[:srcs].map { |str|
        Dir[File.join(dir, str)]
      }.flatten
    end
  end

  class AddTestDependencies < Tasks
    def handle(fun, dir, args)
      task = Rake::Task[task_name(dir, "#{args[:name]}-test")]

      if args.has_key?(:deps)
        add_dependencies task, dir, args[:deps]
      end
    end
  end

  class RubyTest < Tasks
    def handle(fun, dir, args)
      desc "Run ruby tests for #{args[:name]}"
      task task_name(dir, "#{args[:name]}-test") => %W[//#{dir}:bundle] do
        STDOUT.sync = true
        puts "Running: #{args[:name]} ruby tests"

        if args[:name].match /^remote-(.*)/
          ENV['WD_REMOTE_BROWSER'] = $1
          ENV['WD_SPEC_DRIVER'] = 'remote'
        else
          ENV['WD_SPEC_DRIVER'] = args[:name]
        end

        ENV['CI_REPORTS']     = "build/test_logs"

        ruby :include => args[:include],
             :require => args[:require],
             :command => args[:command],
             :args    => %w[--format CI::Reporter::RSpec --format doc --color] + (!!ENV['example'] ? ['--example', ENV['example']] : []),
             :debug   => !!ENV['log'],
             :files   => args[:srcs],
             :gemfile => "build/rb/Gemfile"
      end
    end
  end

  class RubyDocs < Tasks
    def handle(fun, dir, args)
      files = args[:files] || raise("no :files specified for rubydocs")
      output_dir = args[:output_dir] || raise("no :output_dir specified for rubydocs")
      readme = args[:readme] || raise("no :readme specified for rubydocs")

      desc 'Generate Ruby API docs'
      t = task "//#{dir}:docs" do |t|
        yard_args = %w[doc --verbose]
        yard_args += ["--output-dir", output_dir]
        yard_args += ["--readme", readme]

        ruby :command => "yard",
             :args    => yard_args,
             :files   => files,
             :gemfile => "build/rb/Gemfile"
      end

      add_dependencies t, dir, args[:deps]
    end
  end # RubyDocs

  class RubyGem
    def handle(fun, dir, args)
      raise "no :gemspec for rubygem" unless args[:gemspec]

      define_clean_task     dir, args
      define_build_task     dir, args
      define_release_task   dir, args

      define_gem_install_task dir, args
    end

    def define_build_task(dir, args)
      gemspec  = File.expand_path(args[:gemspec])
      deps     = (args[:deps] || [])
      spec_dir = File.dirname(gemspec)

      desc "Build #{args[:gemspec]}"
      task "//#{dir}:gem:build" => deps do
        require 'rubygems/builder'

        file = Dir.chdir(spec_dir) {
          spec = eval(File.read(gemspec))
          Gem::Builder.new(spec).build
        }

        mv File.join(spec_dir, file), "build/"
      end
    end

    def define_clean_task(dir, args)
      desc 'Clean rubygem artifacts'
      task "//#{dir}:gem:clean" do
        rm_rf "build/*.gem"
      end
    end

    def define_release_task(dir, args)
      desc 'Build and release the ruby gem to Gemcutter'
      task "//#{dir}:gem:release" => %W[//#{dir}:gem:clean //#{dir}:gem:build] do
        gem = Dir['build/*.gem'].first # safe as long as :clean does its job
        sh "gem", "push", gem
      end
    end

    def define_gem_install_task(dir, args)
      desc 'Install gem dependencies for the current Ruby'
      task "//#{dir}:bundle" do
        ENV['BUNDLE_GEMFILE'] = 'rb/Gemfile'
        sh "gem install bundler"
        sh "bundle", "install"
      end
    end
  end # RubyGem
end # RubyMappings

def ruby(opts)
  cmd = []

  if opts[:gemfile]
    ENV['BUNDLE_GEMFILE'] = File.expand_path(opts[:gemfile])
    cmd += ["bundle", "exec"]
  end

  cmd << "ruby"

  if opts[:debug]
    cmd << "-d"
  end

  if opts.has_key? :include
    cmd << "-I"
    cmd << Array(opts[:include]).join(File::PATH_SEPARATOR)
  end

  Array(opts[:require]).each do |f|
    cmd << "-r#{f}"
  end

  cmd << "-S" << opts[:command] if opts.has_key? :command
  cmd += Array(opts[:args]) if opts.has_key? :args
  cmd += Array(opts[:files]) if opts.has_key? :files

  puts cmd.join(' ')

  sh(*cmd)
end
