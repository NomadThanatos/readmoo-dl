require 'rubygems'
require 'bundler'
Bundler.require(:default)

module ReadmooDL
  LOGIN_URL = 'https://member.readmoo.com/login'
  API_URL = 'https://reader.readmoo.com'
end

require_relative './readmoo_dl/API'
