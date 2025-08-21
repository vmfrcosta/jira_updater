JIRA_CF_MAP = begin
  raw = ENV.fetch("JIRA_CF_MAP", "{}")
  JSON.parse(raw)
rescue
  {}
end
