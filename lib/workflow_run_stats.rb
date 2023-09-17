# frozen_string_literal: true

require_relative "workflow_run_stats/version"

require "octokit"

module WorkflowRunStats

  class Error < StandardError; end

  class WorkflowRunsFetcher
    # @param [String] access_token
    def initialize(access_token: ENV.fetch('GITHUB_TOKEN'))
      @access_token = access_token
    end

    def fetch(repo, workflow, **options)
      client = Octokit::Client.new(access_token:)

      client.auto_paginate = true

      $stdout.puts "Loading workflows..."

      workflow_runs = client
        .workflow_runs(repo, workflow, status: 'success', **options)
        .workflow_runs

      workflow_runs.map do |workflow_run|
        WorkflowRun.new(workflow_run)
      end
    end

    private

    attr_reader :access_token
  end

  class WorkflowRun
    def initialize(workflow_run)
      @workflow_run = workflow_run
    end

    def id
      @workflow_run.id
    end

    def run_started_at
      @workflow_run.run_started_at
    end

    def jobs
      @jobs || raise("Not loaded")
    end

    def load_jobs
      @jobs ||= workflow_run.rels[:jobs].get.data.jobs
    end

    def usage
      @usage || raise("Not loaded")
    end

    def load_usage
      @usage ||= Sawyer::Relation.new(workflow_run.agent,
                                      :workflow_run_usage,
                                      "#{workflow_run.url}/timing").get.data
    end

    private

    attr_reader :workflow_run
  end

  class BaseRenderer
    def render(workflow_runs)
      raise NotImplementedError
    end

    def run_gnuplot_script(dat:, x_size:, format:)
      raise NotImplementedError
    end

    # @param workflow_runs [Array<WorkflowRun>]
    # @param format [Symbol] default: :svg
    def create(workflow_runs, format: :svg, &block)
      raise ArgumentError, "Invalid format: #{format}" unless %i[png svg].include?(format)

      rendered = render(workflow_runs)

      Tempfile.create do |tempfile|
        tempfile.puts(rendered)

        tempfile.close

        run_gnuplot_script(dat: tempfile.path, x_size: workflow_runs.size, format:, &block)
      end
    end

    def run_gnuplot_script(dat:, x_size:, format:)
      width = 1280 * (x_size / 60.0).round(1)
      width = [width, 640].max

      Tempfile.create(['gnuplot', ".#{format}" ]) do |file|
        Tempfile.create do |gnuplot_script|
          gnuplot_script.puts(<<~SCRIPT)
            set term #{format} size #{width},720
            set out "#{file.path}"

            set datafile separator "\t"

            set xtics rotate by -90

            set title "#{title}"
            set xlabel "#{xlabel}"
            set ylabel "#{ylabel}"

            set style data histograms
            set style histogram rowstacked
            set style fill solid border lc rgb "black"

            set key autotitle columnheader

            plot for [col=2:*] '#{dat}' using col:xtic(1)
          SCRIPT

          gnuplot_script.close

          system(%Q[echo load '"#{gnuplot_script.path}"' | gnuplot -], exception: true)
        end

        yield(file.path)
      end
    end
  end

  class JobDurationRenderer < BaseRenderer
    attr_reader :title, :xlabel, :ylabel

    def initialize(repo:, workflow:)
      @title = "Workflow Run Duration Trend (#{repo} - #{workflow})"
      @xlabel = "Date time"
      @ylabel = "Workflow run duration [min]"
    end

    def render(workflow_runs)
      workflow_runs = workflow_runs.sort_by(&:run_started_at)

      workflow_runs.each.with_index(1) do |workflow_run, i|
        $stdout.puts "Loading an usage of the workflow run: #{workflow_run.id} (#{i}/#{workflow_runs.size})" if ENV.fetch('DEBUG', false)

        workflow_run.load_usage

        sleep 0.3
      end

      rows = []

      rows << ['Date time', 'Workflow run duration'].join("\t")

      workflow_runs.each do |workflow_run|
        values = ["#{workflow_run.run_started_at.iso8601} (#{workflow_run.id})", workflow_run.usage.run_duration_ms / 1000.0 / 60]

        rows << values.join("\t")
      end

      rows.join("\n")
    end
  end

  class CumulativeJobDurationRenderer < BaseRenderer
    attr_reader :title, :xlabel, :ylabel

    def initialize(repo:, workflow:)
      @title = "Cumulative Job Duration Trend (#{repo} - #{workflow})"
      @xlabel = "Date time"
      @ylabel = "Jobs duration time [min]"
    end

    def render(workflow_runs)
      workflow_runs = workflow_runs.sort_by(&:run_started_at)

      workflow_runs.each.with_index(1) do |workflow_run, i|
        $stdout.puts "Loading jobs of the workflow run: #{workflow_run.id} (#{i}/#{workflow_runs.size})" if ENV.fetch('DEBUG', false)

        workflow_run.load_jobs

        sleep 0.3
      end

      job_names = Set.new

      workflow_runs.each do |workflow_run|
        workflow_run.jobs.each {|job| job_names.add(job.name) }
      end

      rows = []

      rows << (['Date time'] + job_names.to_a).join("\t")

      workflow_runs.each do |workflow_run|
        values = ["#{workflow_run.run_started_at.iso8601} (#{workflow_run.id})"]

        job_names.each do |job_name|
          job = workflow_run.jobs.detect {|job| job.name == job_name }

          value = (job ? (job.completed_at - job.started_at) / 60.0 : 0.0)

          values << value
        end

        rows << values.join("\t")
      end

      rows.join("\n")
    end
  end
end
