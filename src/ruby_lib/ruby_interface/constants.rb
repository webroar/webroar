# WebROaR - Ruby Application Server - http://webroar.in/
# Copyright (C) 2009  Goonj LLC
#
# This file is part of WebROaR.
#
# WebROaR is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# WebROaR is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with WebROaR.  If not, see <http://www.gnu.org/licenses/>.

module Webroar
  LIB_DIR = File.join(File.dirname(__FILE__), '..').freeze
  ADAPTER_DIR = File.join(LIB_DIR, "rack", "adapter").freeze
  ADAPTER_FILES = Dir.glob(File.join(ADAPTER_DIR, "**", "*.rb"))
  
  DEBUG = 1
  INFO = 2
  WARN = 3
  SEVERE = 4
  FATAL = 5
  
  SERVER_NAME = 'SERVER_NAME'.freeze 
  WEBROAR = 'WebROaR'.freeze
  SCRIPT_NAME = 'SCRIPT_NAME'.freeze
  EMPTY_STRING = ''.freeze
  QUERY_STRING = 'QUERY_STRING'.freeze
  SERVER_SOFTWARE = 'SERVER_SOFTWARE'.freeze
  SERVER_PROTOCOL = 'SERVER_PROTOCOL'.freeze
  RACK_VERSION = 'rack.version'.freeze
  RACK_ERRORS = 'rack.errors'.freeze
  RACK_URL_SCHEME = 'rack.url_scheme'.freeze 
  
  RACK_MULTIPROCESS = 'rack.multiprocess'.freeze
  RACK_RUN_ONCE = 'rack.run_once'.freeze
  RACK_INPUT = 'rack.input'.freeze
  
  CONTENT_TYPE = 'CONTENT_TYPE'.freeze
  CONTENT_LENGTH = 'CONTENT_LENGTH'.freeze
  REQUEST_PATH = 'REQUEST_PATH'.freeze
  PATH_INFO = 'PATH_INFO'.freeze
  HTTP = 'http'.freeze
  HTTP_CONTENT_TYPE = 'HTTP_CONTENT_TYPE'.freeze  
  HTTP_CONTENT_LENGTH = 'HTTP_CONTENT_LENGTH'.freeze  
  HTTP_VERSION = 'HTTP_VERSION'.freeze
  HTTP_1_0 = 'HTTP/1.0'.freeze
  HTTP_1_1 = 'HTTP/1.1'.freeze
  HTTP_CONNECTION = 'HTTP_CONNECTION'.freeze
  HTTP_HOST = 'HTTP_HOST'.freeze
  KEEP_ALIVE_REGEXP = /\bkeep-alive\b/i.freeze
  CLOSE_REGEXP      = /\bclose\b/i.freeze
  
  SLASH = '/'.freeze
  INDEX = 'index'.freeze  
  KEEP_ALIVE = 'Keep-Alive'.freeze
  CLOSE = 'close'.freeze
  CONNECTION = 'Connection'.freeze
  Server = 'Server'.freeze
  ZERO = '0'.freeze
  InternalServerError = "Internal Server Error\n".freeze
  
  TEXT_HTML = 'text/html'.freeze
  TEXT_PLAIN = 'text/plain'.freeze
  TYPE = 'type'.freeze
  SEMICOLON_CHARSET = "; charset=".freeze
  CHARSET = 'charset'.freeze
  Content_Type = 'Content-Type'.freeze
  Content_Length = 'Content-Length'.freeze
  Content_Language = 'Content-Language'.freeze
  Content_Encoding = 'Content-Encoding'.freeze
  Transfer_Encoding = 'Transfer-Encoding'.freeze
  Language = 'language'.freeze
  EXPIRES = 'Expires'.freeze
  Expires = 'expires'.freeze
  Status = 'Status'.freeze
  Cookie = 'cookie'.freeze
  Set_Cookie = 'Set-Cookie'.freeze
  LF = "\n".freeze
  
  HTTP_STATUS_CODES = {
    100  => 'Continue',
    101  => 'Switching Protocols',
    200  => 'OK',
    201  => 'Created',
    202  => 'Accepted',
    203  => 'Non-Authoritative Information',
    204  => 'No Content',
    205  => 'Reset Content',
    206  => 'Partial Content',
    300  => 'Multiple Choices',
    301  => 'Moved Permanently',
    302  => 'Moved Temporarily',
    303  => 'See Other',
    304  => 'Not Modified',
    305  => 'Use Proxy',
    400  => 'Bad Request',
    401  => 'Unauthorized',
    402  => 'Payment Required',
    403  => 'Forbidden',
    404  => 'Not Found',
    405  => 'Method Not Allowed',
    406  => 'Not Acceptable',
    407  => 'Proxy Authentication Required',
    408  => 'Request Time-out',
    409  => 'Conflict',
    410  => 'Gone',
    411  => 'Length Required',
    412  => 'Precondition Failed',
    413  => 'Request Entity Too Large',
    414  => 'Request-URI Too Large',
    415  => 'Unsupported Media Type',
    500  => 'Internal Server Error',
    501  => 'Not Implemented',
    502  => 'Bad Gateway',
    503  => 'Service Unavailable',
    504  => 'Gateway Time-out',
    505  => 'HTTP Version not supported'
  }.freeze
end
