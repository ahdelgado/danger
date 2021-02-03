module Danger
  class Executor
    def initialize(system_env)
      @system_env = system_env
    end

    def run(env: nil,
            dm: nil,
            cork: nil,
            base: nil,
            head: nil,
            dangerfile_path: nil,
            danger_id: nil,
            new_comment: nil,
            fail_on_errors: nil,
            fail_if_no_pr: nil,
            remove_previous_comments: nil)
      # Create a silent Cork instance if cork is nil, as it's likely a test
      cork ||= Cork::Board.new(silent: false, verbose: false)

      # Run some validations
      validate!(cork, fail_if_no_pr: fail_if_no_pr)

      # OK, we now know that Danger can run in this environment
      env ||= EnvironmentManager.new(system_env, cork, danger_id)
      dm ||= Dangerfile.new(env, cork)

      ran_status = begin
        dm.run(
          base_branch(base),
          head_branch(head),
          dangerfile_path,
          danger_id,
          new_comment,
          remove_previous_comments
        )
      end

      # By default Danger will use the status API to fail a build,
      # allowing execution to continue, this behavior isn't always
      # optimal for everyone.
      exit(1) if fail_on_errors && ran_status
    end

    def validate!(cork, fail_if_no_pr: false)
      p "Cork: ", cork 
      # <Cork::Board:0x000055fc11987e58 @input=#<IO:<STDIN>>, @out=#<IO:<STDOUT>>, @err=#<IO:<STDERR>>, @verbose=false, @silent=false, @ansi=true, @warnings=[], @title_colors=["yellow", "green"], @title_level=0, @indentation_level=2>
      p "Fail if no PR: ", fail_if_no_pr
      # false
      p "System Environment: ", system_env
      # {"PATH"=>"/usr/local/bundle/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "HOSTNAME"=>"152dbc67b154", "RUBY_MAJOR"=>"2.7", "RUBY_VERSION"=>"2.7.0", "RUBY_DOWNLOAD_SHA256"=>"27d350a52a02b53034ca0794efe518667d558f152656c2baaf08f3d0c8b02343", "GEM_HOME"=>"/usr/local/bundle", "BUNDLE_SILENCE_ROOT_WARNING"=>"1", "BUNDLE_APP_CONFIG"=>"/usr/local/bundle", "INSTALL_PATH"=>"/app", "RUBYOPT"=>"-r/usr/local/lib/ruby/2.7.0/bundler/setup -W0", "HOME"=>"/root", "BUNDLER_ORIG_BUNDLE_BIN_PATH"=>"BUNDLER_ENVIRONMENT_PRESERVER_INTENTIONALLY_NIL", "BUNDLER_ORIG_BUNDLE_GEMFILE"=>"BUNDLER_ENVIRONMENT_PRESERVER_INTENTIONALLY_NIL", "BUNDLER_ORIG_BUNDLER_VERSION"=>"BUNDLER_ENVIRONMENT_PRESERVER_INTENTIONALLY_NIL", "BUNDLER_ORIG_GEM_HOME"=>"/usr/local/bundle", "BUNDLER_ORIG_GEM_PATH"=>"BUNDLER_ENVIRONMENT_PRESERVER_INTENTIONALLY_NIL", "BUNDLER_ORIG_MANPATH"=>"BUNDLER_ENVIRONMENT_PRESERVER_INTENTIONALLY_NIL", "BUNDLER_ORIG_PATH"=>"/usr/local/bundle/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "BUNDLER_ORIG_RB_USER_INSTALL"=>"BUNDLER_ENVIRONMENT_PRESERVER_INTENTIONALLY_NIL", "BUNDLER_ORIG_RUBYLIB"=>"BUNDLER_ENVIRONMENT_PRESERVER_INTENTIONALLY_NIL", "BUNDLER_ORIG_RUBYOPT"=>"-W0", "BUNDLE_BIN_PATH"=>"/usr/local/lib/ruby/gems/2.7.0/gems/bundler-2.1.2/libexec/bundle", "BUNDLE_GEMFILE"=>"/app/Gemfile", "BUNDLER_VERSION"=>"2.1.2", "RUBYLIB"=>"", "MANPATH"=>"/usr/local/bundle/gems/kramdown-2.3.0/man"}
#       validate_ci!
      validate_pr!(cork, fail_if_no_pr)
    end

    private

    attr_reader :system_env

    # Could we find a CI source at all?
    def validate_ci!
#       10.times { p ['EnvironmentManager.local_ci_source', EnvironmentManager.local_ci_source] }
#       unless EnvironmentManager.local_ci_source(system_env)
#         abort("Could not find the type of CI for Danger to run on.".red)
#       end
    end

    # Could we determine that the CI source is inside a PR?
    def validate_pr!(cork, fail_if_no_pr)
      unless EnvironmentManager.pr?(system_env)
        ci_name = EnvironmentManager.local_ci_source(system_env).name.split("::").last

        msg = "Not a #{ci_name} #{commit_request(ci_name)} - skipping `danger` run. "
        # circle won't run danger properly if the commit is pushed and build runs before the PR exists
        # https://danger.systems/guides/troubleshooting.html#circle-ci-doesnt-run-my-build-consistently
        # the best solution is to enable `fail_if_no_pr`, and then re-run the job once the PR is up
        if ci_name == "CircleCI"
          msg << "If you only created the PR recently, try re-running your workflow."
        end
        cork.puts msg.strip.yellow

        exit(fail_if_no_pr ? 1 : 0)
      end
    end

    def base_branch(user_specified_base_branch)
      user_specified_base_branch || EnvironmentManager.danger_base_branch
    end

    def head_branch(user_specified_head_branch)
      user_specified_head_branch || EnvironmentManager.danger_head_branch
    end

    def commit_request(ci_name)
      return "Merge Request" if ci_name == 'GitLabCI'
      return "Pull Request"
    end
  end
end
