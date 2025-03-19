#-------------------------------------------------------------------------------
#
# Dechev Daniel Ivanov
# datas2k[at]gmail[dot]com
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'extensions.rb'

module Plugins
  module S2kTools
    ### CONSTANTS ### ------------------------------------------------------------
    PLUGIN_NAME     = 's2kTools'.freeze
    PLUGIN_VERSION  = '1.1.2'.freeze

    # Resource paths
    file = __FILE__.dup
    file.force_encoding("UTF-8") if file.respond_to?(:force_encoding)
    PATH_ROOT     = File.dirname(file).freeze
    PATH          = File.join(PATH_ROOT, 's2kTools').freeze
    

    ### EXTENSION ### ------------------------------------------------------------
    unless file_loaded?(__FILE__)
      loader = File.join(PATH, 'bootstrap')  # ✅ Load bootstrap.rb
      @ex = SketchupExtension.new(PLUGIN_NAME, loader)
      @ex.description = 'A collection of tools for enhancing SketchUp workflows.'
      @ex.version     = PLUGIN_VERSION
      @ex.copyright   = 'Dechev Daniel Ivanov © 2024'
      @ex.creator     = 'Dechev Daniel Ivanov (datas2k@gmail.com)'

      # Register the extension
      Sketchup.register_extension(@ex, true)
      file_loaded(__FILE__)
    end
  end
end
