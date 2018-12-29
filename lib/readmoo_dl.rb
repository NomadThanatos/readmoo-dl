require 'rubygems'
require 'bundler'
Bundler.require(:default)

require 'json'

module ReadmooDL
  LOGIN_URL = 'https://member.readmoo.com/login'
  API_URL = 'https://reader.readmoo.com'
end

require_relative './readmoo_dl/API'
require_relative './readmoo_dl/downloader'
require_relative './readmoo_dl/file'

Dir[File.join(__dir__, 'readmoo_dl', 'files', '*.rb')].each(&method(:require))
