module SupportBeeApp
  module Build
    class << self

      def build
        move_assets
        build_js
      end

      def move_assets
        SupportBeeApp::Base.apps.each do |app|
          images_path = app.root.join('assets','images')
          next unless Dir.exists?(images_path)
          Dir.new(images_path).each do |file|
            next if file == '.' or file == '..'
            file_path = images_path.join(file)
            public_path = Pathname.new(PLATFORM_ROOT).join('public','images',app.slug)
            FileUtils.mkpath(public_path)
            FileUtils.copy(file_path.to_s, public_path.to_s)
          end
        end
      end

      def build_js
        output_path = Pathname.new(PLATFORM_ROOT).join('public','javascripts','sb.apps.js').to_s

        js = StringIO.new

        init_js = 'if(typeof SB === "undefined") { SB = {};} SB.Apps = {};'
        js << init_js
        js << "\n\n"

        js << 'Handlebars.registerHelper(\'ifTicketsCountZero\', function(tickets) {
          return tickets.length === 0;
        });'

        js << "\n"

        js << 'Handlebars.registerHelper(\'ifTicketsCountOne\', function(tickets) {
          console.log(tickets);
          return tickets.length === 1;
        });'

        js << "\n"

        js << 'Handlebars.registerHelper(\'ifTicketsCountMany\', function(tickets) {
          return tickets.length > 1;
        });'

        js << "\n"

        SupportBeeApp::Base.apps.each do |app|
          app_hash = app.configuration
          app_js = "SB.Apps.#{app.slug} = #{JSON.pretty_generate(app_hash)}\n"
          app_actions = app_hash['action'].blank? ? {} : app_hash['action']
          app_actions.each_pair do |name, options|
            app_js << render_button_overlay(app, options) if name == 'button'
          end
          js << "\n"
          js << app_js
          js << "\n"
        end

        screen_hash = {}
        SupportBeeApp::Base.apps.each do |app|
          app_hash = app.configuration
          next unless app_hash['action'] and app_hash['action']['button']
          button_config = app_hash['action']['button']
          next if button_config['screens'].blank?
          button_config['screens'].each do |screen|
            if screen_hash[screen]
              screen_hash[screen] << app_hash['slug']
            else
              screen_hash[screen] = [app_hash['slug']]
            end
          end
        end
        button_map = JSON.pretty_generate(screen_hash)
        button_map = "\n\n SB.Apps.ButtonMap = #{button_map}\n"
        js << button_map

        output = File.open(output_path, 'w')
        output.write(js.string)
        output.close
      end

      private

      def render_button_overlay(app, button_config={})
        return '' unless button_config['overlay']
        button_overlay_path = app.root.join('assets','views','button','overlay.hbs').to_s
        template = File.read(button_overlay_path).gsub("'","\'").gsub("\n","\\n")
        overlay_js = "Handlebars.compile('#{template}')"
        "SB.Apps.#{app.slug}.button_overlay = #{overlay_js}"
      end
    end
  end
end
