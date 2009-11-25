# Deflater based on Rack:Deflater. 
# We need to override as, we would not like to repeate encoding process and, change the Content-Length header if encoding is done.
# 
require "zlib"
require "stringio"
require "time"  # for Time.httpdate

module Webroar
  
  class Deflater
    def initialize(app)
      @app = app
    end
    
    def call(env)
      status, headers, body = @app.call(env)
      
      # Skip compressing empty entity body responses and responses with
      # no-transform set.
      if ::Rack::Utils::STATUS_WITH_NO_ENTITY_BODY.include?(status) ||
        headers['Cache-Control'].to_s =~ /\bno-transform\b/
        return [status, headers, body]
      end
      
      # Skip compressing entity body responses if already compressed.    
      if headers.has_key?(Content_Encoding) 
        return [status, headers, body]
      end
      
      # Skip compressing entity body if user agent is IE6
      # refer http://schroepl.net/projekte/mod_gzip/browser.htm and 
      # http://support.microsoft.com/default.aspx?scid=kb;en-us;Q313712
      # for problem details
      # 
      if env['HTTP_USER_AGENT'] =~ /MSIE 6.0/
        return [status, headers, body]
      end
      
      request = ::Rack::Request.new(env)
      
      encoding = ::Rack::Utils.select_best_encoding(%w(gzip deflate identity),
      request.accept_encoding)
      
      # Set the Vary HTTP header.
      vary = headers["Vary"].to_s.split(",").map { |v| v.strip }
      unless vary.include?("*") || vary.include?("Accept-Encoding")
        headers["Vary"] = vary.push("Accept-Encoding").join(",")
      end
      
      case encoding
      when "gzip"
        mtime = if headers.has_key?("Last-Modified") 
          Time.httpdate(headers["Last-Modified"]) 
        else 
          Time.now
        end              
        body = self.class.gzip(body, mtime)
        # Here changing the content length
        headers[Content_Length] = Webroar::Utils.calculate_content_length(body)
        [status,
        headers.merge("Content-Encoding" => "gzip"),
        body]
      when "deflate"
        body = self.class.deflate(body)
        # Here changing content length
        headers[Content_Length] = Webroar::Utils.calculate_content_length(body)
        [status,
        headers.merge("Content-Encoding" => "deflate"),
        body]
      when "identity"
        [status, headers, body]
      when nil
        # Requested encoding not fouud, returning plain response.
        [status, headers, body]
      end
    end
    
    def self.gzip(body, mtime)
      io = StringIO.new
      gzip = Zlib::GzipWriter.new(io)
      gzip.mtime = mtime
      
      # TODO: Add streaming
      body.each { |part| gzip << part }
      
      gzip.close
      return io.string
    end
    
    DEFLATE_ARGS = [
    Zlib::DEFAULT_COMPRESSION,
    # drop the zlib header which causes both Safari and IE to choke
    -Zlib::MAX_WBITS,
    Zlib::DEF_MEM_LEVEL,
    Zlib::DEFAULT_STRATEGY
    ]
    
    # Loosely based on Mongrel's Deflate handler
    def self.deflate(body)
      deflater = Zlib::Deflate.new(*DEFLATE_ARGS)
      
      # TODO: Add streaming
      body.each { |part| deflater << part }
      
      return deflater.finish
    end
  end
  
end