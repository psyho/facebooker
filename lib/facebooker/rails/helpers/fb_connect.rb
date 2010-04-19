module Facebooker
  module Rails
    module Helpers
      module FbConnect
        def fb_connect_javascript_tag(options = {})
          # accept both Rails and Facebook locale formatting, i.e. "en-US" and "en_US".
          lang = "/#{options[:lang].to_s.gsub('-', '_')}" if options[:lang]
          # dont use the javascript_include_tag helper since it adds a .js at the end
          if request.ssl?
            "<script src=\"https://ssl.connect.facebook.com/js/api_lib/v0.4/FeatureLoader.js.php#{lang}\" type=\"text/javascript\"></script>"
          else
            "<script src=\"http://static.ak.connect.facebook.com/js/api_lib/v0.4/FeatureLoader.js.php#{lang}\" type=\"text/javascript\"></script>"
          end
        end

        #
        # For information on the :app_settings argument see http://wiki.developers.facebook.com/index.php/JS_API_M_FB.Facebook.Init_2
        # While it would be nice to treat :app_settings as a hash, some of the arguments do different things if they are a string vs a javascript function
        # and Rails' Hash#to_json always quotes strings so there is no way to indicate when the value should be a javascript function.
        # For this reason :app_settings needs to be a string that is valid JSON (including the {}'s).
        #
        def init_fb_connect(*required_features, &proc)
          init_fb_connect_with_options({},*required_features, &proc)
        end
        
        def init_fb_connect_with_options(options = {},*required_features, &proc)
          additions = ""
          if block_given?
            additions = capture(&proc)
          end

          # Yes, app_settings is set to a string of an empty JSON element. That's intentional.
          options = options.merge({:app_settings => '{}'})

          if required_features.last.is_a?(Hash)
            options.merge!(required_features.pop.symbolize_keys)
          end

          if request.ssl?
            init_string = "FB.init('#{Facebooker.api_key}','/xd_receiver_ssl.html', #{options[:app_settings]});"
          else
            init_string = "FB.init('#{Facebooker.api_key}','/xd_receiver.html', #{options[:app_settings]});"
          end
          unless required_features.blank?
             init_string = <<-FBML
             #{case options[:js]
               when :jquery then "jQuery(document).ready("
               when :dojo then "dojo.addOnLoad("
               when :mootools then "window.addEvent('domready',"
               else "Element.observe(window,'load',"
               end} function() {
                FB_RequireFeatures(#{required_features.to_json}, function() {
                  #{init_string}
                  #{additions}
                });
              });
              FBML
          end

          # block_is_within_action_view? is rails 2.1.x and has been
          # deprecated.  rails >= 2.2.x uses block_called_from_erb?
          block_tester = respond_to?(:block_is_within_action_view?) ?
            :block_is_within_action_view? : :block_called_from_erb?

          if block_given? && send(block_tester, proc)
            versioned_concat(javascript_tag(init_string),proc.binding)
          else
            javascript_tag init_string
          end
        end

        #
        # Render an <fb:login-button> element
        #
        # ==== Examples
        #
        #   <%= fb_login_button%>
        #   => <fb:login-button></fb:login-button>
        #
        # Specifying a javascript callback
        #
        #   <%= fb_login_button 'update_something();'%>
        #   => <fb:login-button onlogin='update_something();'></fb:login-button>
        #
        # Adding options <em>See:</em> http://wiki.developers.facebook.com/index.php/Fb:login-button
        #
        #   <%= fb_login_button 'update_something();', :size => :small, :background => :dark%>
        #   => <fb:login-button background='dark' onlogin='update_something();' size='small'></fb:login-button>
        #
        # :text option allows you to set the text value of the
        # button.  *A note!* This will only do what you expect it to do
        # if you set :v => 2 as well.
        #
        #   <%= fb_login_button 'update_somethign();',
        #        :text => 'Loginto Facebook', :v => 2 %>
        #   => <fb:login-button v='2' onlogin='update_something();'>Login to Facebook</fb:login-button>
        def fb_login_button(*args)

          callback = args.first
          options = args[1] || {}
          options.merge!(:onlogin=>callback) if callback

          text = options.delete(:text)

          content_tag("fb:login-button",text, options)
        end
      end
    end
  end
end
