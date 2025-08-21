class JiraChangelog < ApplicationRecord
  belongs_to :jira_issue
  has_many :jira_changelog_items, dependent: :destroy
  
  validates :history_id, presence: true
end
