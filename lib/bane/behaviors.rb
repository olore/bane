module Bane

  module Behaviors

    class BasicBehavior
      def self.inherited(clazz)
        ServiceRegistry.register(clazz)
      end

      def self.simple_name
        self.name.split("::").last
      end
    end

    # This module can be used to wrap another behavior with
    # a "while(io.gets)" loop, which reads a line from the input and
    # then performs the given behavior.
    module ForEachLine
      def serve(io, options)
        while (io.gets)
          super(io, options)
        end
      end
    end

    # Closes the connection immediately after a connection is made.
    class CloseImmediately < BasicBehavior
      def serve(io, options)
        # do nothing
      end
    end

    # Accepts a connection, pauses a fixed duration, then closes the connection.
    #
    # Options:
    #   - duration: The number of seconds to wait before disconnect.  Default: 30
    class CloseAfterPause < BasicBehavior
      def serve(io, options)
        options = {:duration => 30}.merge(options)

        sleep(options[:duration])
      end
    end

    # Sends a static response.
    #
    # Options:
    #   - message: The response message to send. Default: "Hello, world!"
    class FixedResponse < BasicBehavior
      def serve(io, options)
        options = {:message => "Hello, world!"}.merge(options)

        io.write options[:message]
      end
    end

    class FixedResponseForEachLine < FixedResponse
      include ForEachLine
    end

    # Sends a newline character as the only response 
    class NewlineResponse < BasicBehavior
      def serve(io, options)
        io.write "\n"
      end
    end

    class NewlineResponseForEachLine < NewlineResponse
      include ForEachLine
    end

    # Sends a random response.
    class RandomResponse < BasicBehavior
      def serve(io, options)
        io.write random_string
      end

      private
      def random_string
        (1..rand(26)+1).map { |i| ('a'..'z').to_a[rand(26)] }.join
      end

    end

    class RandomResponseForEachLine < RandomResponse
      include ForEachLine
    end

    # Sends a fixed response character-by-character, pausing between each character.
    #
    # Options:
    #  - message: The response to send. Default: "Hello, world!"
    #  - pause_duration: The number of seconds to pause between each character. Default: 10 seconds
    class SlowResponse < BasicBehavior
      def serve(io, options)
        options = {:message => "Hello, world!", :pause_duration => 10}.merge(options)
        message = options[:message]
        pause_duration = options[:pause_duration]

        message.each_char do |char|
          io.write char
          sleep pause_duration
        end
      end
    end

    class SlowResponseForEachLine < SlowResponse
      include ForEachLine
    end

    # Accepts a connection and never sends a byte of data.  The connection is
    # left open indefinitely.
    class NeverRespond < BasicBehavior
      def serve(io, options)
        loop { sleep 1 }
      end
    end

    # Sends a large response.  Response consists of a repeated 'x' character.
    #
    # Options
    #  - length: The size in bytes of the response to send. Default: 1,000,000 bytes
    class DelugeResponse < BasicBehavior
      def serve(io, options)
        options = {:length => 1_000_000}.merge(options)
        length = options[:length]

        length.times { io.write('x') }
      end
    end

    class DelugeResponseForEachLine < DelugeResponse
      include ForEachLine
    end



    def self.create_http_class(config)
       
      block = Proc.new do

        define_method(:serve) do |io, options|
          code = config[:status_code]
          code = code[rand(code.size)] if code.is_a? Array
         
          io.gets # Read the request before responding

          if code == 200
            response_string = config[:success_response] ? config[:success_response] : code.to_s
          else
            response_string = code.to_s
          end

          response = NaiveHttpResponse.new(
                code,
                text_for_http_code(code), 
                "text/html", response_string
          )
          io.write(response.to_s)
        end

        #FIXME: this shouldn't be defined on EACH class :(
        define_method(:text_for_http_code) do |code|
          case code
            when 401 then "Unauthorized"
            when 403 then "Forbidden"
            when 404 then "Not Found"
            when 500 then "Internal Server Error"
            when 502 then "Bad Gateway"
            when 503 then "Service Unavailable"
            else "Unknown Error"
          end
        end
    
      end

      Class.new(BasicBehavior, &block)
    end

    # These attempt to mimic an HTTP server by reading a line (the request)
    # and then sending the response.  These behaviors respond to all
    # incoming request URLs on the running port. 
    HttpRefuseAllCredentials = create_http_class(:status_code => 401)
    Http403Forbidden = create_http_class(:status_code => 403)

    BAD_HTTP_CODES = [401, 403, 404, 500, 502, 503]
    HttpRandomBadResponses = create_http_class(:status_code => BAD_HTTP_CODES)

    def self.successful_html
      <<-EOF
<!DOCTYPE html>
<html>
  <head>
    <title>Bane Server</title>
  </head>
  <body>
    <h1>Success</h1>
  </body>
</html>
      EOF
    end

    # 80% of the calls return 500 Internal Server Error
    HttpMostlyBadResponses      = create_http_class(:status_code => [200, 500, 500, 500, 500],
                  :success_response => self.successful_html)

    # 20% of the calls return 500 Internal Server Error
    HttpIntermittentBadResponse = create_http_class(:status_code => [200, 200, 200, 200, 500],
                  :success_response => self.successful_html)

  end
end

