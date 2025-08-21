class JiraChangelogItem < ApplicationRecord
  belongs_to :jira_changelog
  
  validates :field, presence: true
end
