require_dependency 'inline_oneboxer'

class InlineOneboxController < ApplicationController
  before_filter :ensure_logged_in

  def show
    oneboxes = InlineOneboxer.new(params[:urls]).process
    render json: { "inline-oneboxes" => oneboxes }
  end
end
