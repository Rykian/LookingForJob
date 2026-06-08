module GraphqlHelpers
  def post_graphql(query:, variables: {})
    post "/graphql", params: { query: query, variables: variables }, as: :json
    JSON.parse(response.body)
  end

  # Stub the Meilisearch chain (`MeiliSearch::Rails.client.index("JobOffer").search`)
  # so search specs stay deterministic and never hit a running Meilisearch server.
  def stub_meilisearch(hits)
    index = instance_double(Meilisearch::Index, search: { "hits" => hits })
    client = instance_double(Meilisearch::Client, index: index)
    allow(MeiliSearch::Rails).to receive(:client).and_return(client)
    index
  end
end
