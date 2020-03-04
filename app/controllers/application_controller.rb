class ApplicationController < ActionController::Base
	def hello
		render json: "{ 'hello': 'world' }"
	end
end
