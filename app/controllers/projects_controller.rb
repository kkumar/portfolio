require 'date'
require 'json'

class ProjectsController < ApplicationController

  before_action :get_project, only: [:show]

  def index
    @projects = Project.all




    # client / get_repos
    source_repos_owned_hash_unformatted = `curl -H 'Authorization: token ' \
      https://api.github.com/users/rhamill1/repos?per_page=100`

    # format response
    repos_owned_hash = JSON.parse(source_repos_owned_hash_unformatted)

    # get repo names
    @repos = []
    repos_owned_hash.each do |project|
      @repos.push(project["name"])
    end

    # iterate through repos
    @all_compiled_commits = []
    @repos.each do |repo|
      # build request
      repo_url = ' https://api.github.com/repos/rhamill1/' + repo + '/commits?per_page=100'
      curl_repo_commits = "curl -H 'Authorization: token '" + repo_url
      source_commits_hash_unformatted = %x{ #{curl_repo_commits} }

      commits_hash = JSON.parse(source_commits_hash_unformatted, :symbolize_names => true)

      # compile commits
      commits_hash.each do |commit|
        @all_compiled_commits.push([repo, commit[:commit][:author][:name], commit[:commit][:author][:date]])
      end
    end

    # remove non-me commits
    @compiled_commits = []
    def remove_non_author_commits(array)
      array.each do |commit|
        @compiled_commits.push(commit) if commit[1] == 'rhamill1'
      end
    end
    remove_non_author_commits(@all_compiled_commits)

    # get commits count
    grouped_commits = @compiled_commits.group_by{|e| [e[0], Date.parse(e[2]).at_beginning_of_week]}

    good_array = []
    grouped_commits.each do |key, value|
      new_value = value.length
      good_array.push([key[0], key[1], new_value])
    end

    # find min date
    sorted_for_min_date = good_array.sort_by{ |commit| commit[1] }
    min_date = sorted_for_min_date[0][1]

    # fill in 0 counts for the missing project/dates
    # get all mondays
    processing_monday = min_date
    all_mondays = []
    while processing_monday < Date.today do
      all_mondays.push(processing_monday)
      processing_monday += 7
    end

    # get all projects
    all_projects_w_dupes = []
    good_array.each do |project_monday|
      all_projects_w_dupes.push(project_monday[0])
    end
    all_projects = all_projects_w_dupes.uniq

    # create an array of arrays with a record of each project/monday and a third default value of 0
    total_array = []
    all_projects.each do |project|
      all_mondays.each do |monday|
        total_array.push([project, monday, 0])
      end
    end

    # add in records with actual values
    good_array.each do |project_monday|
      total_array.each do |zero_project_monday|
        project_monday[0] == zero_project_monday[0] && project_monday[1] == zero_project_monday[1] ? zero_project_monday[2] = project_monday[2] : nil
      end
    end

    final_array = []
    all_projects.each do |project|
      monday_count = []
      total_array.each do |project_monday|
        project == project_monday[0] ? monday_count.push(project_monday[2]) : nil
      end
        final_array.push([project, monday_count])
    end

    first_monday_o_month_array = []
    all_mondays.each do |monday|
        monday.strftime("%d").to_i <= 7 ? first_monday_o_month_array.push(monday.strftime("%b %y")) : first_monday_o_month_array.push("")
    end


    @chart = LazyHighCharts::HighChart.new('graph') do |f|

      # production
      f.xAxis(categories: first_monday_o_month_array)
      final_array.each do |project|
        f.series(name: project[0], yAxis: 0, data: project[1], marker: {enabled: false})
      end

      # # test
      # f.xAxis(categories: ["2016-12-01", "", "", "", ""])
      # f.series(name: "Project 1", yAxis: 0, data: [141, 50, 49, 33, 256], marker: {enabled: false})
      # f.series(name: "Project 2", yAxis: 0, data: [123, 121, 113, 128, 346], marker: {enabled: false})

      f.legend(align: 'right', verticalAlign: 'top', y: 75, x: -50, layout: 'vertical', enabled: false)
      f.colors(["#ecd292", "#e5a267", "#d27254", "#a5494d", "#63223c"])
      f.chart({defaultSeriesType: "area",
        backgroundColor:'transparent'
      })
      f.tooltip(backgroundColor:'#e5e5e5', headerFormat: '')

    end


  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.create(project_params)
    @project.save
    redirect_to root_path
  end

  def show
  end

  private

  def project_params
    params.require(:project).permit(:project_name,:description,:sub_title,:primary_image,:index_image,:github,:url,:tech,:completion_date, :slug)
  end

  def get_project
    @project = Project.friendly.find(params[:id])
  end

end
