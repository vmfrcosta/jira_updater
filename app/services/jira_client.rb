# app/services/jira_client.rb
require "net/http"
require "uri"
require "json"

class JiraClient
  def initialize(
    base_url: ENV.fetch("JIRA_BASE_URL"),
    email:    ENV.fetch("JIRA_EMAIL"),
    api_token: ENV.fetch("JIRA_API_TOKEN")
  )
    @base_url  = base_url
    @email     = email
    @api_token = api_token
  end

  # -------------------------
  # Lista padrão de campos a buscar em TODAS as chamadas
  # (inclui os campos start/end do seu .env e os custom fields do JIRA_CF_MAP)
  # -------------------------
  def default_fields
    base = %w[
      summary
      status
      issuetype
      priority
      project
      labels
      created
      duedate
    ]

    # inclui campos de data (start/end) se definidos
    start_f = ENV["JIRA_TARGET_START_FIELD"]
    end_f   = ENV["JIRA_TARGET_END_FIELD"]
    base << start_f if start_f.present?
    base << end_f   if end_f.present?

    # inclui todos os custom fields mapeados no initializer
    if defined?(JIRA_CF_MAP) && JIRA_CF_MAP.present?
      base.concat(JIRA_CF_MAP.values)
    end

    base.compact.uniq
  end

  # -------------------------
  # Busca issues por JQL
  # -------------------------
  def search(jql:, start_at: 0, max_results: 100, fields: nil)
    field_list = Array(fields || default_fields)

    uri = URI.join(@base_url, "/rest/api/3/search")
    uri.query = URI.encode_www_form(
      "jql"        => jql,
      "startAt"    => start_at,
      "maxResults" => max_results,
      "fields"     => field_list.join(","),
      "expand"     => "changelog"
    )

    req = Net::HTTP::Get.new(uri)
    req["Accept"]        = "application/json"
    req["Content-Type"]  = "application/json"
    req.basic_auth(@email, @api_token)

    res = perform(req)
    JSON.parse(res.body)
  end

  # -------------------------
  # Busca changelog de uma issue específica
  # -------------------------
  def get_changelog(issue_key, start_at: 0, max_results: 100)
    uri = URI.join(@base_url, "/rest/api/3/issue/#{issue_key}/changelog")
    uri.query = URI.encode_www_form(
      "startAt"    => start_at,
      "maxResults" => max_results
    )

    req = Net::HTTP::Get.new(uri)
    req["Accept"]        = "application/json"
    req["Content-Type"]  = "application/json"
    req.basic_auth(@email, @api_token)

    res = perform(req)
    JSON.parse(res.body)
  end

  # -------------------------
  # Atualiza campos customizados de uma issue
  # -------------------------
  def update_issue(issue_key, fields)
    uri = URI.join(@base_url, "/rest/api/3/issue/#{issue_key}")

    payload = {
      "fields" => fields
    }

    req = Net::HTTP::Put.new(uri)
    req["Accept"]        = "application/json"
    req["Content-Type"]  = "application/json"
    req.basic_auth(@email, @api_token)
    req.body = payload.to_json

    res = perform(req)
    res.code == "204" # Jira returns 204 No Content on successful update
  end

  private

  def perform(req)
    http = Net::HTTP.new(req.uri.host, req.uri.port)
    http.use_ssl = (req.uri.scheme == "https")
    res = http.request(req)

    unless res.is_a?(Net::HTTPSuccess)
      raise "JiraClient HTTP #{res.code}: #{res.body}"
    end

    res
  end
end
