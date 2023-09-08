# WorkflowRunStats

:warning: in development

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add workflow_run_stats

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install workflow_run_stats

## Usage

    $ workflow_run_stats REPO WORKFLOW [DURATION] --job-duration tmp/job-duration.svg --cumulative-job-duration tmp/cumulative-job-duration.svg

Example:

    $ workflow_run_stats 'octokit/octokit.rb' 'octokit.yml' '2023-06-01..2023-09-01' --job-duration tmp/job-duration.svg --cumulative-job-duration tmp/cumulative-job-duration.svg

![cumulative-job-duration](https://github.com/mizoR/workflow_run_stats/assets/1257116/5c07332d-af5b-48c4-a1e8-df2a3a46b1c7)

![job-duration](https://github.com/mizoR/workflow_run_stats/assets/1257116/48d1b992-972f-4b58-896e-8cb159bfb07c)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mizoR/workflow_run_stats.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
