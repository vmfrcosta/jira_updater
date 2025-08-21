# app/models/jira_issue.rb
class JiraIssue < ApplicationRecord
    validates :key, presence: true, uniqueness: true

    has_many :jira_changelogs, dependent: :destroy

    scope :with_status,  ->(s) { where(status: s) if s.present? }
    scope :with_type,    ->(t) { where(issue_type: t) if t.present? }
    scope :updated_since,->(d) { where("updated_at >= ?", d) if d.present? }
  
    # Para Postgres, duas opções de filtro por label:
    # 1) Se labels for ARRAY nativo (recomendado) => where("labels @> ARRAY[?]::varchar[]", [l])
    # 2) Se labels for TEXT serializado => ILIKE no texto
    scope :with_label, ->(l) {
      next if l.blank?
      arel = if connection.adapter_name =~ /PostgreSQL/i && columns_hash["labels"]&.sql_type&.include?("[]")
        where("labels @> ARRAY[?]::varchar[]", [l])
      else
        where("COALESCE(labels::text, '') ILIKE ?", "%#{l}%")
      end
      arel
    }
  
    def self.search(params = {})
      rel = all
      rel = rel.with_status(params[:status])
      rel = rel.with_type(params[:type])
      rel = rel.with_label(params[:label])
      rel = rel.where(project_key: params[:project]) if params[:project].present?
      rel = rel.where("start_date >= ?", params[:from]) if params[:from].present?
      rel = rel.where("end_date   <= ?", params[:to])   if params[:to].present?
      rel
    end

    # Returns all changelog items for this issue
    def changelog_items
      JiraChangelogItem.joins(:jira_changelog)
                       .where(jira_changelogs: { jira_issue_id: id })
                       .order('jira_changelogs.created_at_jira ASC, jira_changelog_items.created_at ASC')
    end

    # Returns all changelog items without ordering (for distinct operations)
    def changelog_items_unordered
      JiraChangelogItem.joins(:jira_changelog)
                       .where(jira_changelogs: { jira_issue_id: id })
    end

    # Returns changelog items filtered by field type
    def changelog_items_by_field(field_name)
      changelog_items.where(field: field_name)
    end

    # Returns only status change changelog items
    def status_changes
      changelog_items_by_field('status')
    end

    # Returns changelog items within a date range
    def changelog_items_in_range(start_date, end_date)
      changelog_items.joins(:jira_changelog)
                     .where(jira_changelogs: { 
                       created_at_jira: start_date.beginning_of_day..end_date.end_of_day 
                     })
    end
  end
  