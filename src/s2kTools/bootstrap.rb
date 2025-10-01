#-------------------------------------------------------------------------------
#
# Bootstrap s2kTools
#
#-------------------------------------------------------------------------------

require 'fileutils'
require_relative 'toolbar'
require_relative 'make_svg'
require_relative 'custom_buildable_handler'
require_relative 'CustomGroupFixer'
require_relative 'attribute'

module Plugins::S2kTools
  # Az eszköztár inicializálása
  unless file_loaded?(__FILE__)
    create_toolbar
    file_loaded(__FILE__)
  end
end