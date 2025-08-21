# app/controllers/api/v1/issues_controller.rb
require "csv"

module Api
  module V1
    class IssuesController < ApplicationController
      def index
        issues = JiraIssue.search(params)
                          .order(updated_at: :desc)
                          .limit([params.fetch(:limit, 500).to_i, 2000].min)

        if request.format&.to_sym == :csv || params[:format] == "csv"
          send_data to_csv(issues),
                    filename: "issues.csv",
                    type: "text/csv; charset=utf-8"
        else
          render json: issues.map { |i| build_json(i) }
        end
      end

      def show
        issue = JiraIssue.find_by!(key: params[:id])
        render json: build_json(issue)
      end

      private

      # -------- Helpers --------

      # Quais chaves extras iremos expor (em ordem) — vêm do ENV JIRA_CF_MAP
      def extras_keys
        # se o initializer não existir, evita quebra
        defined?(JIRA_CF_MAP) ? JIRA_CF_MAP.keys : []
      end

      # Monta o JSON unindo os campos "core" com os extras
      def build_json(issue)
        base = {
          id:          issue.id,
          key:         issue.key,
          summary:     issue.summary,
          status:      issue.status,
          issue_type:  issue.issue_type,
          priority:    issue.priority,
          project_key: issue.project_key,
          start_date:  issue.start_date,
          end_date:    issue.end_date,
          labels:      issue.labels || []
        }

        # Add individual columns that were previously in extras
        individual_fields = {
          points: issue.points,
          transitions_count: issue.transitions_count,
          entered_requirements_at: issue.entered_requirements_at,
          entered_discovery_at: issue.entered_discovery_at,
          entered_ideation_at: issue.entered_ideation_at,
          entered_validation_at: issue.entered_validation_at,
          entered_refinement_at: issue.entered_refinement_at,
          entered_ready_for_dev_at: issue.entered_ready_for_dev_at,
          entered_ready_for_review_at: issue.entered_ready_for_review_at,
          entered_ready_for_test_at: issue.entered_ready_for_test_at,
          entered_ready_for_deploy_at: issue.entered_ready_for_deploy_at,
          entered_developing_at: issue.entered_developing_at,
          entered_reviewing_at: issue.entered_reviewing_at,
          entered_testing_at: issue.entered_testing_at,
          entered_deployed_at: issue.entered_deployed_at,
          entered_wrapup_at: issue.entered_wrapup_at,
          entered_done_at: issue.entered_done_at,
          reviewer: issue.reviewer,
          tester: issue.tester
        }

        result = base.merge(individual_fields.compact)

        # Include changelog if requested
        if params[:include_changelog] == "true"
          result[:changelog] = issue.jira_changelogs.includes(:jira_changelog_items).map do |changelog|
            {
              id: changelog.history_id,
              author: {
                account_id: changelog.author_account_id,
                display_name: changelog.author_display_name
              },
              created_at: changelog.created_at_jira,
              items: changelog.jira_changelog_items.map do |item|
                {
                  field: item.field,
                  fieldtype: item.fieldtype,
                  from: item.from_string,
                  to: item.to_string
                }
              end
            }
          end
        end

        result
      end

      # Gera CSV com colunas core + colunas extras (usando as chaves do JIRA_CF_MAP)
      def to_csv(relation)
        headers_core  = %w[key summary status issue_type priority project_key start_date end_date labels]
        headers_individual = %w[points transitions_count entered_requirements_at entered_discovery_at entered_ideation_at entered_validation_at entered_refinement_at entered_ready_for_dev_at entered_ready_for_review_at entered_ready_for_test_at entered_ready_for_deploy_at entered_developing_at entered_reviewing_at entered_testing_at entered_deployed_at entered_wrapup_at entered_done_at reviewer tester]
        headers = headers_core + headers_individual

        CSV.generate(headers: true) do |csv|
          csv << headers
          relation.find_each do |i|
            row = [
              i.key,
              i.summary,
              i.status,
              i.issue_type,
              i.priority,
              i.project_key,
              i.start_date,
              i.end_date,
              (i.labels || []).join("|")
            ]
            # adiciona as colunas individuais
            row += [
              i.points,
              i.transitions_count,
              i.entered_requirements_at,
              i.entered_discovery_at,
              i.entered_ideation_at,
              i.entered_validation_at,
              i.entered_refinement_at,
              i.entered_ready_for_dev_at,
              i.entered_ready_for_review_at,
              i.entered_ready_for_test_at,
              i.entered_ready_for_deploy_at,
              i.entered_developing_at,
              i.entered_reviewing_at,
              i.entered_testing_at,
              i.entered_deployed_at,
              i.entered_wrapup_at,
              i.entered_done_at,
              i.reviewer,
              i.tester
            ]
            csv << row
          end
        end
      end
    end
  end
end
