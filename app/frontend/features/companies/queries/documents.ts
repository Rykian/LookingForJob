import { gql } from '@apollo/client'

export const COMPANIES_QUERY = gql`
  query Companies(
    $page: Int!
    $perPage: Int!
    $search: String
    $postsAsRecruiter: Boolean
    $postsAsFinalClient: Boolean
    $sortBy: String
    $sortDirection: String
  ) {
    companies(
      page: $page
      perPage: $perPage
      search: $search
      postsAsRecruiter: $postsAsRecruiter
      postsAsFinalClient: $postsAsFinalClient
      sortBy: $sortBy
      sortDirection: $sortDirection
    ) {
      totalCount
      totalPages
      nodes {
        id
        name
        website
        postsAsRecruiter
        postsAsFinalClient
        offerCount
        finalClientOfferCount
        topTechnologies(limit: 6)
      }
    }
  }
`

export const COMPANY_QUERY = gql`
  query Company($id: ID!) {
    company(id: $id) {
      id
      name
      description
      website
      postsAsRecruiter
      postsAsFinalClient
      offerCount
      finalClientOfferCount
      topTechnologies
      createdAt
      aliases {
        id
        name
      }
    }
  }
`

export const COMPANY_ALIAS_PREVIEW_QUERY = gql`
  query CompanyAliasPreview($name: String!) {
    companyAliasPreview(name: $name) {
      normalizedName
      matchedOffersCount
      owningCompany {
        id
        name
      }
    }
  }
`

export const COMPANY_NAME_SUGGESTIONS_QUERY = gql`
  query CompanyNameSuggestions($search: String!, $excludeCompanyId: ID) {
    companyNameSuggestions(search: $search, excludeCompanyId: $excludeCompanyId)
  }
`

export const SET_OFFER_FINAL_CLIENT_MUTATION = gql`
  mutation SetOfferFinalClient($offerId: ID!, $companyName: String) {
    setOfferFinalClient(input: { offerId: $offerId, companyName: $companyName }) {
      jobOffer {
        id
        postedByRecruiter
        finalCompany {
          id
          name
        }
      }
    }
  }
`

export const ADD_COMPANY_ALIAS_MUTATION = gql`
  mutation AddCompanyAlias($companyId: ID!, $name: String!) {
    addCompanyAlias(input: { companyId: $companyId, name: $name }) {
      company {
        id
        name
        offerCount
        aliases {
          id
          name
        }
      }
    }
  }
`

export const REMOVE_COMPANY_ALIAS_MUTATION = gql`
  mutation RemoveCompanyAlias($aliasId: ID!) {
    removeCompanyAlias(input: { aliasId: $aliasId }) {
      originalCompany {
        id
        name
        offerCount
        aliases {
          id
          name
        }
      }
      newCompany {
        id
        name
      }
    }
  }
`

export const RENAME_COMPANY_MUTATION = gql`
  mutation RenameCompany($companyId: ID!, $name: String!) {
    renameCompany(input: { companyId: $companyId, name: $name }) {
      company {
        id
        name
        aliases {
          id
          name
        }
      }
    }
  }
`
