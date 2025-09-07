# app/models/jira_issue.rb
class JiraIssue < ApplicationRecord
    validates :key, presence: true, uniqueness: true

    has_many :jira_changelogs, dependent: :destroy
    
    # Parent-child relationships
    belongs_to :parent, class_name: 'JiraIssue', foreign_key: 'parent_key', primary_key: 'key', optional: true
    has_many :children, class_name: 'JiraIssue', foreign_key: 'parent_key', primary_key: 'key'

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

    # Parent-child relationship methods
    def has_parent?
      parent_key.present?
    end

    def has_children?
      children.exists?
    end

    def is_subtask?
      has_parent?
    end

    def is_parent?
      has_children?
    end

    # Update the children count for this issue
    def update_children_count!
      new_count = children.count
      update_column(:children_count, new_count) if children_count != new_count
      new_count
    end

    # Get all ancestors (parent, grandparent, etc.)
    def ancestors
      ancestors_list = []
      current = self
      
      while current.parent.present?
        ancestors_list << current.parent
        current = current.parent
      end
      
      ancestors_list
    end

    # Get all descendants (children, grandchildren, etc.)
    def descendants
      descendants_list = []
      
      children.each do |child|
        descendants_list << child
        descendants_list.concat(child.descendants)
      end
      
      descendants_list
    end

    # Get the root parent (top-level issue)
    def root_parent
      return self unless has_parent?
      
      current = self
      while current.parent.present?
        current = current.parent
      end
      
      current
    end

    # Assignee-related methods
    def has_assignee?
      assignee.present?
    end

    def unassigned?
      assignee.blank?
    end

    # Scope for filtering by assignee
    scope :assigned_to, ->(assignee_name) { where(assignee: assignee_name) if assignee_name.present? }
    scope :unassigned, -> { where(assignee: nil) }
    scope :assigned, -> { where.not(assignee: nil) }

    # Sprint-related methods
    def has_sprint?
      sprint.present?
    end

    def unsprinted?
      sprint.blank?
    end

    # Scope for filtering by sprint
    scope :in_sprint, ->(sprint_name) { where(sprint: sprint_name) if sprint_name.present? }
    scope :unsprinted, -> { where(sprint: nil) }
    scope :sprinted, -> { where.not(sprint: nil) }

    # Projected date methods
    def has_refinement_projected_date?
      refinement_projected_date.present?
    end

    def has_deploy_projected_date?
      deploy_projected_date.present?
    end

    # Scope for filtering by projected dates
    scope :with_refinement_projected_date, -> { where.not(refinement_projected_date: nil) }
    scope :with_deploy_projected_date, -> { where.not(deploy_projected_date: nil) }
    scope :without_refinement_projected_date, -> { where(refinement_projected_date: nil) }
    scope :without_deploy_projected_date, -> { where(deploy_projected_date: nil) }

    # Scope for filtering by children count
    scope :with_children, -> { where('children_count > 0') }
    scope :without_children, -> { where(children_count: 0) }
    scope :with_children_count, ->(count) { where(children_count: count) if count.present? }
  end
  