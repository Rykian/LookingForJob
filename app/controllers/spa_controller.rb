class SpaController < ActionController::Base
  def index
    render html: '', layout: 'spa'
  end
end
